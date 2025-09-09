#!/bin/bash -eu

PROJECT="${1:?}"
CLUSTER_NAME="autopilot-cluster-1"

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

if ! kubectl get namespace argo-rollouts; then
	echo "Installing Argo Rollouts"
	kubectl create namespace argo-rollouts
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/download/v1.8.3/install.yaml
fi

kustomize build examples/analysis | kubectl apply -f -

# scale down for now
# kubectl scale rollout.argoproj.io/canary-demo --replicas=1

ingress=canary-csanchez
kubectl apply -f ingress-csanchez.yaml

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
	EOF
}

echo "Getting ingress ip"
ip=$(kubectl get ingress "${ingress}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}')
while [ -z "$ip" ]; do
	echo "Waiting for ingress to have an ip"
	sleep 10
	ip=$(kubectl get ingress "${ingress}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}')
done
echo "Ingress ip: $ip"

kubectl scale rollout.argoproj.io/canary-demo --replicas=10

kubectl argo rollouts get rollout canary-demo

kubectl argo rollouts dashboard

# kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:green"
# kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:bad-red"
# kubectl argo rollouts set image canary-demo "*=argoproj/rollouts-demo:slow-yellow"

# gcloud beta container \
# 	--project "${PROJECT}" \
# 	clusters delete "${CLUSTER_NAME}" \
# 	--region "us-central1"
