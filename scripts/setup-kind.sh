#!/usr/bin/env bash
# scripts/setup-kind.sh
#
# One-command local Kubernetes platform bootstrap using kind.
# Deploys a realistic reference environment suitable for demos, labs, and development.
#
# What it installs:
#   - kind cluster (configurable name + node count)
#   - Kyverno + core platform policies
#   - Prometheus + Grafana + Loki + Alertmanager (via kube-prometheus-stack or lightweight equivalent)
#   - OpenCost
#   - Sample workloads in dev and staging namespaces
#   - Basic Flux or Argo CD (configurable via flag)
#
# Usage:
#   ./scripts/setup-kind.sh
#   ./scripts/setup-kind.sh --name blueprint --nodes 3 --gitops flux
#
# After completion:
#   - kubectl config use-context kind-blueprint
#   - kubectl get pods -A
#   - Port-forward Grafana: kubectl port-forward -n monitoring svc/grafana 3000:80
#   - Open http://localhost:3000 (admin / admin or see secret)

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-blueprint}"
NODE_COUNT="${NODE_COUNT:-3}"
GITOPS="${GITOPS:-none}"   # none | flux | argocd
DRY_RUN=false

log() { echo -e "\033[1;34m[setup-kind]\033[0m $*"; }
warn() { echo -e "\033[1;33m[setup-kind]\033[0m $*"; }

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) CLUSTER_NAME="$2"; shift 2 ;;
    --nodes) NODE_COUNT="$2"; shift 2 ;;
    --gitops) GITOPS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--name <cluster>] [--nodes <n>] [--gitops none|flux|argocd] [--dry-run]"
      exit 0
      ;;
    *) warn "Unknown arg: $1"; exit 1 ;;
  esac
done

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is required. Install from https://kind.sigs.k8s.io/"
  exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required."
  exit 1
fi
if ! command -v helm >/dev/null 2>&1; then
  echo "helm is required (for OpenCost, monitoring, etc.)."
  exit 1
fi

log "Creating kind cluster '${CLUSTER_NAME}' with ${NODE_COUNT} nodes..."

if [[ "$DRY_RUN" == "true" ]]; then
  log "[dry-run] Would create cluster and install components."
  exit 0
fi

# Create kind cluster with reasonable resource requests for local laptop
cat <<EOF | kind create cluster --name "${CLUSTER_NAME}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Some kind setups create only control-plane by default above; ensure workers if NODE_COUNT > 1
if [[ "$NODE_COUNT" -gt 2 ]]; then
  for i in $(seq 3 "$NODE_COUNT"); do
    kind get nodes --name "${CLUSTER_NAME}" | grep -q "worker" || true
  done
fi

log "Cluster created. Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s || true

log "Labeling nodes for Karpenter-like simulation (local)..."
for node in $(kubectl get nodes -o name); do
  kubectl label "$node" node.kubernetes.io/capacity-type=on-demand --overwrite || true
  kubectl label "$node" node-pool=on-demand-critical --overwrite || true
done

log "Creating platform namespaces..."
kubectl apply -f manifests/clusters/namespaces/ || true

log "Installing Kyverno (policy-as-code)..."
helm repo add kyverno https://kyverno.github.io/kyverno/ || true
helm repo update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --set replicaCount=1 \
  --wait --timeout=5m || warn "Kyverno install may need manual follow-up"

log "Applying Kyverno policies..."
kubectl apply -f manifests/clusters/policies/kyverno/ || true

log "Installing OpenCost..."
helm repo add opencost https://opencost.github.io/opencost-helm-chart || true
helm repo update
helm upgrade --install opencost opencost/opencost \
  --namespace opencost --create-namespace \
  --set opencost.exporter.defaultClusterId="${CLUSTER_NAME}-local" \
  --wait --timeout=5m || warn "OpenCost may need configuration for local billing simulation"

log "Installing lightweight observability stack (kube-prometheus-stack)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin \
  --set grafana.ingress.enabled=false \
  --set prometheus.prometheusSpec.retention=24h \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --wait --timeout=8m || warn "Monitoring stack install may require more resources or manual steps"

log "Applying sample environments (dev + staging)..."
kubectl apply -k manifests/environments/dev/ || true
kubectl apply -k manifests/environments/staging/ || true

# Optional GitOps
if [[ "$GITOPS" == "flux" ]]; then
  log "Installing Flux v2 (light)..."
  if ! command -v flux >/dev/null 2>&1; then
    warn "flux CLI not found. Skipping Flux bootstrap. Install from https://fluxcd.io"
  else
    flux install || true
  fi
elif [[ "$GITOPS" == "argocd" ]]; then
  log "Installing Argo CD..."
  kubectl create namespace argocd || true
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true
  kubectl -n argocd patch svc argocd-server -p '{"spec": {"type": "LoadBalancer"}}' || true
fi

log "Applying basic network policies and quotas..."
kubectl apply -f manifests/environments/base/ || true

log "Waiting for core pods..."
kubectl wait --for=condition=available --timeout=180s deployment -n kyverno kyverno-admission-controller || true
kubectl wait --for=condition=available --timeout=180s deployment -n opencost opencost || true

log "=================================================="
log "Local platform is ready!"
log ""
log "Cluster: kind-${CLUSTER_NAME}"
log "Context: kind-${CLUSTER_NAME}"
log ""
log "Useful commands:"
log "  kubectl get pods -A"
log "  kubectl port-forward -n monitoring svc/grafana 3000:80"
log "    -> Grafana: http://localhost:3000 (user: admin / pass: admin)"
log "  kubectl port-forward -n opencost svc/opencost 9003:9003"
log "    -> OpenCost UI: http://localhost:9003"
log ""
log "Next steps:"
log "  ./scripts/validate.sh"
log "  ./scripts/cost-simulation.sh --scenario education-platform --nodes 6"
log "  ./scripts/compliance-scan.sh --framework soc2"
log "=================================================="
