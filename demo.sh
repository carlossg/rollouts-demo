#!/bin/bash -eu

PROJECT="${1:-}"
INSTALL_GEMMA="${INSTALL_GEMMA:-false}" # Set to 'true' to install Gemma server
AGENT_TYPE="${AGENT_TYPE:-antigravity}" # Set to 'antigravity' or 'kdubois' to select the Kubernetes Agent implementation

if [ -z "${PROJECT}" ]; then
	PROJECT=$(gcloud config get-value project)
fi

CLUSTER_NAME="autopilot-cluster-1"
DEMO_LABEL="demo=argo-rollouts"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/demo-functions.sh"

create_cluster

cloud_build_setup "${PROJECT}"

install_argo_rollouts

echo "Creating the rollout"
kubectl apply -k examples/analysis
# skaffold apply

# Kevin's quarkus-rollouts-demo - depends on the kdubois Kubernetes Agent
if [ "${AGENT_TYPE}" = "kdubois" ]; then
	echo "Creating the quarkus-rollouts-demo rollout"
	kubectl apply -k "${script_dir}/k8s-kevin-quarkus-demo"
fi

# scale down for now
kubectl scale rollout.argoproj.io/canary-demo --replicas=1

# Create ingress after service is ready
create_ingress

# quarkus-demo's ingress was already applied above with its rollout
if [ "${AGENT_TYPE}" = "kdubois" ]; then
	wait_for_ingress_ip quarkus-demo quarkus-demo
fi

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
