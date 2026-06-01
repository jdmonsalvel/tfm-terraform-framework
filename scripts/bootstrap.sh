#!/bin/bash
# scripts/bootstrap.sh — Instala addons de plataforma en el clúster EKS.
# Llamado por terraform_data.bootstrap en modules/aws/eks/main.tf.
#
# Args:
#   $1 — cluster_key        (e.g. "fiware-gitops")
#   $2 — bootstrap_dir      (path al directorio modules/aws/eks/bootstrap)
#   $3 — tfvars_json        (path al fichero generado bootstrap/generated/<key>.tfvars.json)
#
# Instala via Terraform:
#   cert-manager, external-secrets, aws-load-balancer-controller, metrics-server
# ArgoCD gestiona únicamente los workloads (FIWARE).

set -euo pipefail

CLUSTER_KEY="${1:?Falta cluster_key}"
BOOTSTRAP_DIR="${2:?Falta bootstrap_dir}"
TFVARS_JSON="${3:?Falta tfvars_json}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[bootstrap:${CLUSTER_KEY}]${NC} $1"; }
warn() { echo -e "${YELLOW}[bootstrap:${CLUSTER_KEY}]${NC} $1"; }

[ ! -f "$TFVARS_JSON" ] && { warn "tfvars.json no encontrado: $TFVARS_JSON"; exit 1; }

CLUSTER_NAME=$(python3 -c "import json; print(json.load(open('$TFVARS_JSON'))['cluster_name'])")
CLUSTER_REGION=$(python3 -c "import json; print(json.load(open('$TFVARS_JSON'))['cluster_region'])")

log "Clúster: $CLUSTER_NAME  |  Región: $CLUSTER_REGION"

# ─── Configurar kubectl ───────────────────────────────────────────────────────
if aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$CLUSTER_REGION" 2>/dev/null; then
    log "kubectl configurado."
else
    warn "update-kubeconfig falló (puede que el endpoint sea privado desde este equipo)."
fi

# ─── Terraform bootstrap — instala addons Helm de plataforma ──────────────────
log "Ejecutando bootstrap Terraform en $BOOTSTRAP_DIR..."

BACKEND_BUCKET=$(python3 -c "import json; print(json.load(open('$TFVARS_JSON'))['backend_bucket'])")
BACKEND_REGION=$(python3 -c "import json; print(json.load(open('$TFVARS_JSON')).get('backend_region','eu-west-1'))")
BACKEND_KEY="${CLUSTER_NAME}/bootstrap.tfstate"

terraform -chdir="$BOOTSTRAP_DIR" init -reconfigure \
    -backend-config="bucket=${BACKEND_BUCKET}" \
    -backend-config="key=${BACKEND_KEY}" \
    -backend-config="region=${BACKEND_REGION}" \
    -backend-config="encrypt=true" \
    -upgrade \
    -input=false 2>&1 | grep -vE "^Downloading|^Reusing|already installed|Installed"

log "Aplicando addons de plataforma..."
terraform -chdir="$BOOTSTRAP_DIR" apply \
    -var-file="$TFVARS_JSON" \
    -auto-approve \
    -input=false 2>&1

log "Bootstrap completado. Addons instalados:"
log "  cert-manager, external-secrets, aws-load-balancer-controller, metrics-server"
log ""
log "ArgoCD gestionará los workloads FIWARE."
log "Aplica el App of Apps desde el repo gitops:"
log "  kubectl apply -f gitops/app-of-apps.yaml"
