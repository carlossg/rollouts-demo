#!/bin/bash -eu

PROJECT="${1:-}"

if [ -z "${PROJECT}" ]; then
	PROJECT=$(gcloud config get-value project)
fi

CLUSTER_NAME="autopilot-cluster-1"

starship_toggle() {
	cat <<-EOF | while read -r module; do starship toggle "$module"; done
		gcloud
		azure
		aws
		docker_context
		java
		package
		nodejs
		golang
		git_branch
		git_status
		directory
		python
		kubernetes
	EOF
}

function create_cluster() {
	# create cluster if it doesn't exist
	if ! gcloud container clusters get-credentials "${CLUSTER_NAME}" --region us-central1; then
		echo "Creating cluster"
		gcloud beta container \
			--project "${PROJECT}" \
			clusters create-auto "${CLUSTER_NAME}" \
			--region "us-central1"
	# --release-channel "regular" \
	# --network "projects/${PROJECT}/global/networks/default" \
	# --subnetwork "projects/${PROJECT}/regions/us-central1/subnetworks/default" \
	# --cluster-ipv4-cidr "/17" \
	# --binauthz-evaluation-mode=DISABLED
	else
		echo "Cluster exists"
	fi
}

function setup_permissions() {
	local project="${1:?}"

	echo "Setting up IAM permissions for Cloud Build service account..."
	echo ""

	# Get the Cloud Build service account (using project number)
	local project_number=$(gcloud projects describe "${project}" --format="value(projectNumber)")
	local cb_sa="${project_number}@cloudbuild.gserviceaccount.com"

	echo "Cloud Build service account: ${cb_sa}"
	echo ""

	# Grant necessary roles
	local roles=(
		"roles/clouddeploy.releaser"
		"roles/container.developer"
		"roles/iam.serviceAccountUser"
	)

	for role in "${roles[@]}"; do
		echo "Granting ${role}..."
		if gcloud projects add-iam-policy-binding "${project}" \
			--member="serviceAccount:${cb_sa}" \
			--role="${role}" \
			--condition=None \
			--quiet 2>&1 | grep -q "bindings:"; then
			echo "  ✓ ${role} granted"
		else
			echo "  ℹ ${role} (already exists or failed)"
		fi
	done

	echo ""
	echo "✓ Permissions setup complete"
	echo ""
}

function cloud_build_setup() {
	local project="${1:?}"
	local repo="rollouts-demo"
	local owner="carlossg"
	local trigger_region="us-central1"
	local deploy_region="us-central1"
	local trigger_name="${repo}"

	echo "========================================="
	echo "Cloud Build & Cloud Deploy Setup"
	echo "========================================="
	echo ""
	echo "Project: ${project}"
	echo "Repository: ${owner}/${repo}"
	echo "Region: ${trigger_region}"
	echo ""

	# Setup permissions first
	setup_permissions "${project}"

	# Check if trigger already exists
	echo "Checking for existing Cloud Build trigger..."
	local trigger_id=""

	# Try to find trigger by name in us-central1
	if trigger_id=$(gcloud builds triggers describe "${trigger_name}" \
		--project="${project}" \
		--region="${trigger_region}" \
		--format="value(id)" 2>/dev/null); then

		echo "✓ Found trigger '${trigger_name}' (ID: ${trigger_id})"
		echo "  Updating to use cloudbuild.yaml..."

		gcloud builds triggers update github "${trigger_id}" \
			--project="${project}" \
			--region="${trigger_region}" \
			--build-config="cloudbuild.yaml"

		echo "✓ Trigger updated successfully"
	else
		echo "⚠️  Trigger '${trigger_name}' not found"
		echo "  Attempting to create new trigger..."
		echo ""

		# Try to create trigger using existing connection
		local connection="github1"
		local repo_resource="projects/${project}/locations/${trigger_region}/connections/${connection}/repositories/${owner}-${repo}"

		echo "Using Cloud Build connection: ${connection}"
		echo "Repository resource: ${repo_resource}"
		echo ""

		# Create trigger using connection
		if gcloud builds triggers create github \
			--name="${trigger_name}" \
			--repository="${repo_resource}" \
			--branch-pattern="^main$" \
			--build-config="cloudbuild.yaml" \
			--region="${trigger_region}" \
			--project="${project}" 2>&1; then

			echo "✓ Trigger created successfully!"
			trigger_id=$(gcloud builds triggers describe "${trigger_name}" \
				--project="${project}" \
				--region="${trigger_region}" \
				--format="value(id)" 2>/dev/null)
		else
			echo ""
			echo "❌ Failed to create trigger automatically"
			echo ""
			echo "This likely means the repository needs to be linked to the connection."
			echo ""
			echo "📝 Manual Setup Required:"
			echo ""
			echo "1. Visit Cloud Build Triggers page:"
			echo "   https://console.cloud.google.com/cloud-build/triggers;region=${trigger_region}?project=${project}"
			echo ""
			echo "2. Click 'CREATE TRIGGER'"
			echo ""
			echo "3. Configure the trigger:"
			echo "   - Name: ${trigger_name}"
			echo "   - Region: ${trigger_region}"
			echo "   - Event: Push to a branch"
			echo "   - Source: 2nd gen (if available)"
			echo "   - Repository: ${owner}/${repo} (you may need to link it first)"
			echo "   - Branch: ^main\$ (regex)"
			echo "   - Configuration: Cloud Build configuration file"
			echo "   - Location: cloudbuild.yaml"
			echo ""
			echo "4. Click 'CREATE'"
			echo ""
		fi
	fi
	echo ""

	# Apply Cloud Deploy pipeline
	echo "Setting up Cloud Deploy pipeline..."
	if gcloud deploy delivery-pipelines describe rollouts-demo-pipeline \
		--project="${project}" \
		--region="${deploy_region}" &>/dev/null; then
		echo "✓ Cloud Deploy pipeline already exists"
	else
		echo "Creating Cloud Deploy pipeline..."
		gcloud deploy apply \
			--project="${project}" \
			--file=clouddeploy.yaml \
			--region="${deploy_region}"
		echo "✓ Cloud Deploy pipeline created"
	fi
	echo ""

	# Summary
	echo "========================================="
	echo "Setup Status"
	echo "========================================="
	echo ""
	if [ -n "${trigger_id}" ]; then
		echo "✅ Cloud Build Trigger: CONFIGURED"
		echo "   Name: ${trigger_name}"
		echo "   Region: ${trigger_region}"
		echo "   Config: cloudbuild.yaml"
	else
		echo "⏳ Cloud Build Trigger: NEEDS MANUAL SETUP"
		echo "   (See instructions above)"
	fi
	echo ""
	echo "✅ Cloud Deploy Pipeline: CONFIGURED"
	echo "   Name: rollouts-demo-pipeline"
	echo "   Region: ${deploy_region}"
	echo "   Target: production (GKE)"
	echo ""
	echo "✅ Image Registry: READY"
	echo "   us-central1-docker.pkg.dev/${project}/github/rollouts-demo"
	echo ""

	if [ -n "${trigger_id}" ]; then
		echo "🚀 Next Steps:"
		echo "  1. Push a commit to trigger the pipeline:"
		echo "     git add . && git commit -m 'feat: setup complete' && git push"
		echo ""
		echo "  2. Monitor builds:"
		echo "     gcloud builds list --project=${project} --region=${trigger_region}"
		echo ""
		echo "  3. Monitor releases:"
		echo "     gcloud deploy releases list --delivery-pipeline=rollouts-demo-pipeline --region=${deploy_region}"
		echo ""
		echo "  4. Watch rollout:"
		echo "     kubectl argo rollouts get rollout canary-demo --watch"
	fi
	echo ""
}

function install_argo_rollouts() {
	if ! kubectl get namespace argo-rollouts; then
		echo "Installing Argo Rollouts"
		kubectl create namespace argo-rollouts
		if [ -d ../../carlossg/argo-rollouts/rollouts-plugin-metric-ai/ ]; then
			echo "Installing Argo Rollouts Plugin Metric AI from local path"
			kubectl apply -n argo-rollouts -k ../../carlossg/argo-rollouts/rollouts-plugin-metric-ai/config/argo-rollouts
		else
			echo "Installing Argo Rollouts Plugin Metric AI from github"
			pushd "$TMPDIR" >/dev/null
			git clone https://github.com/carlossg/rollouts-plugin-metric-ai.git
			kubectl apply -n argo-rollouts -k rollouts-plugin-metric-ai/config/argo-rollouts
			popd >/dev/null
		fi
		kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/download/v1.8.3/install.yaml
	fi
}

function create_ingress() {
	local ingress=canary-csanchez

	echo "Creating ingress"
	kubectl apply -f ingress-csanchez.yaml

	echo "Getting ingress ip"
	local ip=$(kubectl get ingress "${ingress}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}')
	while [ -z "$ip" ]; do
		echo "Waiting for ingress to have an ip"
		sleep 10
		ip=$(kubectl get ingress "${ingress}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}')
	done
	echo "Ingress ip: $ip"
}

create_cluster

cloud_build_setup "${PROJECT}"

install_argo_rollouts

# change argo-rollouts image to ghcr.io/carlossg/rollouts-plugin-metric-ai
kubectl set image -n argo-rollouts \
	deployment/argo-rollouts \
	argo-rollouts=ghcr.io/carlossg/rollouts-plugin-metric-ai

echo "Creating the rollout"
kubectl apply -k examples/analysis
# skaffold apply

# scale down for now
kubectl scale rollout.argoproj.io/canary-demo --replicas=1

# Create ingress after service is ready
create_ingress

kubectl argo rollouts get rollout canary-demo

kubectl argo rollouts dashboard

# kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:green"
# kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:bad-red"
# kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:slow-yellow"

# gcloud beta container \
# 	--project "${PROJECT}" \
# 	clusters delete "${CLUSTER_NAME}" \
# 	--region "us-central1"
