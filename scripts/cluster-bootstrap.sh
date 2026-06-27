#!/bin/bash
# scripts/cluster-bootstrap.sh
#
# One-shot, idempotent bootstrap for a freshly created AKS cluster (after
# `terraform apply` on the transient stack). Run this on the jump VM as
# clahanadmin. Safe to re-run - every step checks before acting.
#
# Consolidates everything that used to be separate, easy-to-forget manual
# steps or undocumented prerequisites:
#   - AKS credentials
#   - ArgoCD installation (was never in Terraform)
#   - Gateway API + kGateway CRDs/controller (documented in
#     clahan_deployment_guide.md Step 7, never scripted - this is why
#     ArgoCD sync failed with "HTTPRoute CRD not installed" after a rebuild)
#   - Namespace, AppProject, Application, secret push (was bootstrap-app.sh,
#     which only ever lived on a desktop machine, never committed)
#   - Full resource whitelist on the AppProject, including Job/Role/
#     RoleBinding (needed for the gateway-ip-patch-hook added to the Helm
#     chart - missing these caused a silent sync failure earlier)
#   - Forces an initial sync rather than waiting on ArgoCD's poll interval

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}>> $1${NC}"; }
success() { echo -e "${GREEN}OK $1${NC}"; }
warn()    { echo -e "${YELLOW}!! $1${NC}"; }
error()   { echo -e "${RED}XX $1${NC}"; }

# ---- Configuration - adjust per environment ----
ENVIRONMENT="${1:-prod}"
if [ "$ENVIRONMENT" == "prod" ]; then
  RESOURCE_GROUP="rg-clahan-prod"
  KEY_VAULT="kv-clahan-prod"
  NAMESPACE="clahan-production"
  APP_NAME="clahan-academy-prod"
  PROJECT_NAME="clahan-academy-prod"
  VALUES_FILE="values-prod.yaml"
else
  RESOURCE_GROUP="rg-clahan-dev"
  KEY_VAULT="kv-clahan-65bf2554"
  NAMESPACE="clahan-dev"
  APP_NAME="clahan-academy-dev"
  PROJECT_NAME="clahan-academy-dev"
  VALUES_FILE="values-dev.yaml"
fi
AKS_CLUSTER="aks-clahan-academy"
HELM_REPO_URL="https://github.com/clahan-academy/clahan-academy-helm.git"
INFRA_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info "Environment: $ENVIRONMENT | RG: $RESOURCE_GROUP | Namespace: $NAMESPACE"

# ---- Step 1: AKS credentials ----
info "Step 1: Fetching AKS credentials..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing
success "kubectl context set to $AKS_CLUSTER"

# ---- Step 2: ArgoCD ----
info "Step 2: Installing ArgoCD (skipped if already present)..."
if kubectl get namespace argocd >/dev/null 2>&1 && kubectl get deploy argocd-server -n argocd >/dev/null 2>&1; then
  warn "ArgoCD already installed, skipping"
else
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  # --server-side avoids "metadata.annotations: Too long" on the
  # applicationsets.argoproj.io CRD: client-side `kubectl apply` stores the
  # whole manifest in a last-applied-configuration annotation, which
  # overflows the 262144 byte limit on this particular CRD. Server-side
  # apply tracks field ownership instead and never hits that limit.
  kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  info "Waiting for ArgoCD pods to be ready (up to 3 min)..."
  kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd

  # argocd-server serves TLS on its main port by default. Our Gateway/AppGW
  # setup terminates TLS upstream and sends plain HTTP to backends, so
  # without this, every request through argocd-routes gets a bodiless 500
  # from Envoy (it receives TLS handshake bytes back when it expected HTTP
  # and can't parse them).
  info "Setting argocd-server to --insecure (TLS terminates upstream at AppGW, not here)..."
  kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
  kubectl rollout restart deployment argocd-server -n argocd
  kubectl rollout status deployment argocd-server -n argocd --timeout=120s
fi
success "ArgoCD ready"

# ---- Step 3: Gateway API + kGateway ----
info "Step 3: Installing Gateway API CRDs + kGateway (skipped if already present)..."
if kubectl get crd httproutes.gateway.networking.k8s.io >/dev/null 2>&1; then
  warn "Gateway API CRDs already installed, skipping"
else
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
fi

helm upgrade -i kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds \
  --create-namespace --namespace kgateway-system
helm upgrade -i kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway \
  --namespace kgateway-system

info "Waiting for kgateway controller to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/kgateway -n kgateway-system
success "Gateway API + kGateway ready"

# ---- Step 4: Namespace + AppProject + Application ----
info "Step 4: Creating namespace, AppProject, Application..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: $PROJECT_NAME
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: "Clahan Academy V2 ${ENVIRONMENT} - Online Exam Platform"
  sourceRepos:
    - $HELM_REPO_URL
  destinations:
    - namespace: $NAMESPACE
      server: https://kubernetes.default.svc
    - namespace: argocd
      server: https://kubernetes.default.svc
    - namespace: monitoring
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace
    - group: cert-manager.io
      kind: ClusterIssuer
    - group: secrets-store.csi.x-k8s.io
      kind: SecretProviderClass
    - group: rbac.authorization.k8s.io
      kind: ClusterRole
    - group: rbac.authorization.k8s.io
      kind: ClusterRoleBinding
  namespaceResourceWhitelist:
    - group: apps
      kind: Deployment
    - group: apps
      kind: DaemonSet
    - group: ""
      kind: Service
    - group: ""
      kind: ServiceAccount
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Secret
    - group: ""
      kind: PersistentVolumeClaim
    - group: networking.k8s.io
      kind: Ingress
    - group: autoscaling
      kind: HorizontalPodAutoscaler
    - group: policy
      kind: PodDisruptionBudget
    - group: networking.k8s.io
      kind: NetworkPolicy
    - group: secrets-store.csi.x-k8s.io
      kind: SecretProviderClass
    - group: gateway.networking.k8s.io
      kind: Gateway
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
    - group: gateway.networking.k8s.io
      kind: ReferenceGrant
    - group: gateway.kgateway.dev
      kind: GatewayParameters
    - group: batch
      kind: Job
    - group: rbac.authorization.k8s.io
      kind: Role
    - group: rbac.authorization.k8s.io
      kind: RoleBinding
  roles:
    - name: administrator
      description: Admin sync access
      policies:
        - p, proj:$PROJECT_NAME:administrator, applications, get, $PROJECT_NAME/*, allow
        - p, proj:$PROJECT_NAME:administrator, applications, sync, $PROJECT_NAME/*, allow
EOF

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: clahan-academy
    environment: $ENVIRONMENT
spec:
  project: $PROJECT_NAME
  source:
    repoURL: $HELM_REPO_URL
    targetRevision: main
    path: clahan-academy
    helm:
      valueFiles:
        - values.yaml
        - $VALUES_FILE
  destination:
    server: https://kubernetes.default.svc
    namespace: $NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
  # kgateway's controller strips spec.infrastructure.parametersRef from the
  # live Gateway object after resolving it (confirmed: present in
  # last-applied-configuration, absent from live spec). Argo would
  # otherwise flag this as permanent drift on every single sync cycle since
  # it gets removed again right after each apply - this isn't something to
  # "fix" in the manifest, the controller legitimately owns it post-admission.
  ignoreDifferences:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: clahan-gateway
      jsonPointers:
        - /spec/infrastructure
EOF
success "AppProject + Application applied"

# ---- Step 5: push-secrets.sh intentionally NOT run here ----
# Confirmed by inspecting auth-deployment.yaml (and the other Helm-deployed
# services): they fetch secrets directly from Key Vault at runtime via
# @azure/identity + Workload Identity (KEY_VAULT_NAME env var + the
# federated ServiceAccount) - they never read the Kubernetes Secret objects
# push-secrets.sh creates. Running it only produced confusing "[WARNING]
# Secret not found" noise for values nothing consumes, and left an extra
# plaintext-recoverable (base64-only) copy of every secret sitting in etcd
# for no benefit. push-secrets.sh itself is left in scripts/ in case the
# kubernetes/ standalone manifest path (a separate, non-GitOps deployment
# approach) is ever used instead - that path does read these via
# secretKeyRef/envFrom.

# ---- Step 6: Force initial sync ----
info "Step 6: Forcing initial ArgoCD sync..."
kubectl -n argocd annotate application "$APP_NAME" argocd.argoproj.io/refresh=hard --overwrite

info "Waiting for sync to settle (up to 3 min)..."
for i in $(seq 1 36); do
  SYNC=$(kubectl get application "$APP_NAME" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
  HEALTH=$(kubectl get application "$APP_NAME" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")
  echo "  sync=$SYNC health=$HEALTH"
  if [ "$SYNC" == "Synced" ] && [ "$HEALTH" == "Healthy" ]; then
    success "Application Synced and Healthy"
    break
  fi
  sleep 5
done

# ---- Step 7: Verify ----
info "Step 7: Verification"
echo "--- Pods ---"
kubectl get pods -n "$NAMESPACE"
echo "--- Gateway Service (want EXTERNAL-IP = 10.0.4.250) ---"
kubectl get svc clahan-gateway -n "$NAMESPACE"
echo "--- Gateway IP patch hook job ---"
kubectl get jobs -n "$NAMESPACE" 2>/dev/null | grep gateway-ip-patch || echo "  (already cleaned up by hook-delete-policy, check it ran via: kubectl get events -n $NAMESPACE | grep gateway-ip-patch)"

echo ""
success "Bootstrap complete. If EXTERNAL-IP above is not 10.0.4.250, give it another 60s for Azure CCM to reconcile, then re-check."
echo "Next: az network application-gateway show-backend-health -g $RESOURCE_GROUP --name appgw-clahan-academy"
