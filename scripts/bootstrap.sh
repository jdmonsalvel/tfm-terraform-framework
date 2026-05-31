#!/bin/bash
# scripts/bootstrap.sh — Configura kubectl tras el despliegue del clúster EKS.
# Llamado por terraform_data.bootstrap en modules/aws/eks/main.tf.
#
# Args:
#   $1 — cluster_key        (e.g. "fiware-gitops")
#   $2 — bootstrap_dir      (path al directorio modules/aws/eks/bootstrap)
#   $3 — tfvars_json        (path al fichero generado bootstrap/generated/<key>.tfvars.json)
#
# Modo GitOps: ArgoCD gestiona todos los addons Helm.
# Este script solo configura el acceso kubectl al clúster.

set -euo pipefail

CLUSTER_KEY="${1:?Falta cluster_key}"
BOOTSTRAP_DIR="${2:?Falta bootstrap_dir}"
TFVARS_JSON="${3:?Falta tfvars_json}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[bootstrap:${CLUSTER_KEY}]${NC} $1"; }
warn() { echo -e "${YELLOW}[bootstrap:${CLUSTER_KEY}]${NC} $1"; }

if [ ! -f "$TFVARS_JSON" ]; then
    warn "tfvars.json no encontrado: $TFVARS_JSON"
    exit 1
fi

CLUSTER_NAME=$(python3 -c "import json; print(json.load(open('$TFVARS_JSON'))['cluster_name'])")
CLUSTER_REGION=$(python3 -c "import json; print(json.load(open('$TFVARS_JSON'))['cluster_region'])")

log "Clúster: $CLUSTER_NAME  |  Región: $CLUSTER_REGION"
log "Configurando kubectl..."

if aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$CLUSTER_REGION" 2>/dev/null; then
    log "kubectl configurado correctamente."
    kubectl get nodes --no-headers 2>/dev/null || warn "Nodos aún no disponibles — normal en los primeros segundos."
else
    warn "update-kubeconfig falló (puede que el endpoint sea privado desde este equipo)."
    warn "Ejecuta manualmente: aws eks update-kubeconfig --name $CLUSTER_NAME --region $CLUSTER_REGION"
fi

log "Modo GitOps activo — ArgoCD gestionará los addons Helm."
log "Para iniciar la sincronización, aplica el App of Apps desde el repo gitops:"
log "  bash scripts/bootstrap.sh   (repo tfm-fiware-gitops)"
