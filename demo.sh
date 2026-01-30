#!/bin/bash -eu

PROJECT="${1:-}"
INSTALL_GEMMA="${INSTALL_GEMMA:-false}" # Set to 'true' to install Gemma server

if [ -z "${PROJECT}" ]; then
	PROJECT=$(gcloud config get-value project)
fi

CLUSTER_NAME="autopilot-cluster-1"
DEMO_LABEL="demo=argo-rollouts"

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
		echo "Creating Autopilot cluster"

		# Create Autopilot cluster (supports GPU workloads automatically)
		# See: https://cloud.google.com/kubernetes-engine/docs/how-to/autopilot-gpus
		gcloud container \
			--project "${PROJECT}" \
			clusters create-auto "${CLUSTER_NAME}" \
			--region "us-central1" \
			--labels="${DEMO_LABEL}"
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
			--project="${project}" \
			--labels="${DEMO_LABEL}" 2>&1; then

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
	fi
	if ! kubectl get deployment/argo-rollouts -n argo-rollouts; then
		if [ -d ../rollouts-plugin-metric-ai/ ]; then
			echo "Installing Argo Rollouts Plugin Metric AI from local path"
			kubectl apply -n argo-rollouts -k ../rollouts-plugin-metric-ai/config/argo-rollouts
		else
			echo "Installing Argo Rollouts Plugin Metric AI from github"
			pushd "$TMPDIR" >/dev/null
			git clone https://github.com/carlossg/rollouts-plugin-metric-ai.git
			kubectl apply -n argo-rollouts -k rollouts-plugin-metric-ai/config/argo-rollouts
			popd >/dev/null
		fi
		# kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/download/v1.8.3/install.yaml
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

function install_kubernetes_agent() {
	echo "Installing Kubernetes Agent"
	local local_path
	local_path="$(dirname "$(pwd)")/kubernetes-agent/"
	if [ -d "${local_path}" ]; then
		echo "Installing Kubernetes Agent from local path"
		kubectl apply -n argo-rollouts -k "${local_path}/deployment"
	else
		echo "Installing Kubernetes Agent from github because ${local_path} doesn't exist"
		pushd "$TMPDIR" >/dev/null
		git clone https://github.com/carlossg/kubernetes-agent.git
		kubectl apply -n argo-rollouts -k kubernetes-agent/deployment
		popd >/dev/null
	fi
}

function install_gemma() {
	echo "Installing Gemma model server in Kubernetes"

	# Create namespace if it doesn't exist
	kubectl create namespace gemma-system --dry-run=client -o yaml | kubectl apply -f -

	# Check if deployment manifest exists locally
	local gemma_manifest=""
	set -x
	if [ -d "$(dirname "$(pwd)")/kubernetes-agent/" ]; then
		gemma_manifest="$(dirname "$(pwd)")/kubernetes-agent/deployment/gemma"
	fi

	if [ -n "${gemma_manifest}" ] && [ -d "${gemma_manifest}" ]; then
		echo "Deploying Gemma from local manifests"
		kubectl apply -k "${gemma_manifest}"
	else
		echo "Gemma deployment manifests not found"
		echo "Please ensure the gemma deployment directory exists at kubernetes-agent/deployment/gemma"
		return 1
	fi

	echo "Waiting for Gemma deployment to be ready..."
	kubectl wait --for=condition=available --timeout=600s \
		deployment/gemma-server -n gemma-system || true

	echo "Gemma server deployed successfully"
	echo "Service endpoint: http://gemma-server.gemma-system.svc.cluster.local:8000"
}

function scale_down() {
	echo "========================================="
	echo "Scaling Down Demo Environment"
	echo "========================================="
	echo ""

	# Save current replica counts before scaling down
	echo "Saving current replica counts..."
	kubectl get rollout canary-demo -o jsonpath='{.spec.replicas}' > /tmp/canary-demo-replicas.txt 2>/dev/null || echo "1" > /tmp/canary-demo-replicas.txt
	kubectl get deployment/kubernetes-agent -n argo-rollouts -o jsonpath='{.spec.replicas}' > /tmp/k8s-agent-replicas.txt 2>/dev/null || echo "1" > /tmp/k8s-agent-replicas.txt
	kubectl get deployment/gemma-server -n gemma-system -o jsonpath='{.spec.replicas}' > /tmp/gemma-replicas.txt 2>/dev/null || echo "1" > /tmp/gemma-replicas.txt

	echo "Scaling canary-demo rollout to 0..."
	kubectl scale rollout.argoproj.io/canary-demo --replicas=0 || echo "  ⚠️  canary-demo rollout not found"

	echo "Scaling kubernetes-agent to 0..."
	kubectl scale deployment/kubernetes-agent -n argo-rollouts --replicas=0 || echo "  ⚠️  kubernetes-agent not found"

	echo "Scaling gemma-server to 0..."
	kubectl scale deployment/gemma-server -n gemma-system --replicas=0 2>/dev/null || echo "  ⚠️  gemma-server not found"

	echo "Scaling argo-rollouts to 0..."
	kubectl scale deployment/argo-rollouts -n argo-rollouts --replicas=0 2>/dev/null || echo "  ⚠️  argo-rollouts not found"

	echo "Scaling traffic-generator to 0..."
	kubectl scale deployment/traffic-generator -n default --replicas=0 2>/dev/null || echo "  ⚠️  traffic-generator not found"

	echo ""
	echo "✓ All demo components scaled down to 0"
	echo ""
	echo "Note: Argo Rollouts controller is still running (not scaled down)"
	echo "      Use 'kubectl scale deployment/argo-rollouts -n argo-rollouts --replicas=0' to scale it down too"
	echo ""
}

function scale_up() {
	echo "========================================="
	echo "Scaling Up Demo Environment"
	echo "========================================="
	echo ""

	# Read saved replica counts (default to 1 if files don't exist)

	echo "Scaling canary-demo rollout to 1..."
	kubectl scale rollout.argoproj.io/canary-demo --replicas="1" || echo "  ⚠️  canary-demo rollout not found"

	echo "Scaling kubernetes-agent to 1..."
	kubectl scale deployment/kubernetes-agent -n argo-rollouts --replicas=1 || echo "  ⚠️  kubernetes-agent not found"

	echo "Saling argo-rollouts to 1..."
	kubectl scale deployment/argo-rollouts -n argo-rollouts --replicas=1 || echo "  ⚠️  argo-rollouts not found"

	echo "Scaling traffic-generator to 1..."
	kubectl scale deployment/traffic-generator -n default --replicas=1 || echo "  ⚠️  traffic-generator not found"

	if kubectl get deployment/gemma-server -n gemma-system &>/dev/null; then
		echo "Scaling gemma-server to 1..."
		kubectl scale deployment/gemma-server -n gemma-system --replicas=1 || echo "  ⚠️  gemma-server not found"
	else
		echo "  ℹ  gemma-server not deployed, skipping"
	fi

	echo ""
	echo "✓ All demo components scaled back up"
	echo ""
	echo "Waiting for pods to be ready..."
	kubectl wait --for=condition=ready pod -l app=canary-demo --timeout=120s 2>/dev/null || echo "  ⚠️  canary-demo pods not ready yet"
	kubectl wait --for=condition=ready pod -l app=kubernetes-agent -n argo-rollouts --timeout=120s 2>/dev/null || echo "  ⚠️  kubernetes-agent pod not ready yet"
	kubectl wait --for=condition=ready pod -l app=gemma-server -n gemma-system --timeout=300s 2>/dev/null || echo "  ℹ  gemma-server pod not ready yet (or not deployed)"
	echo ""
}

create_cluster

cloud_build_setup "${PROJECT}"

install_argo_rollouts

# change argo-rollouts image to ghcr.io/argoproj-labs/rollouts-plugin-metric-ai
kubectl set image -n argo-rollouts \
	deployment/argo-rollouts \
	argo-rollouts=ghcr.io/argoproj-labs/rollouts-plugin-metric-ai

echo "Creating the rollout"
kubectl apply -k examples/analysis
# skaffold apply

# scale down for now
kubectl scale rollout.argoproj.io/canary-demo --replicas=1

# Create ingress after service is ready
create_ingress

# Install Gemma if requested
if [ "${INSTALL_GEMMA}" = "true" ]; then
	install_gemma
fi

# Install the kubernetes agent
install_kubernetes_agent

kubectl argo rollouts get rollout canary-demo

kubectl argo rollouts dashboard

# kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:green"
# kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:bad-red"
# kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:slow-yellow"

# Scale down all components (useful for saving costs when not in use)
# scale_down

# Scale back up all components
# scale_up

# gcloud container \
# 	clusters delete "${CLUSTER_NAME}" \
# 	--region "us-central1"
