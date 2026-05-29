#!/bin/bash
# backend-setup.sh — Configura el backend S3+DynamoDB y ejecuta terraform init.
#
# Ejecutar desde el directorio raíz del framework clonado.
#
# CI (credenciales OIDC ya activas en el runner):
#   bash backend-setup.sh <path/to/terraform.tfvars>
#
# Manual:
#   AWS_PROFILE=personal-account-lab bash backend-setup.sh <path/to/terraform.tfvars>
#
# Variables de entorno:
#   TF_VAR_account_id   — account_id de la cuenta gestionada (CI lo inyecta desde secret).
#                         Si no está definido, se lee del tfvars o se detecta via STS.
#
# Variables leídas del tfvars:
#   region, project, environment   — obligatorias
#   devops_service_account_id      — opcional; cuenta donde vive el state (multi-cuenta).
#                                    Si es null o está ausente, se usa account_id.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

[ $# -ne 1 ] && { log_error "Uso: $0 <path/to/terraform.tfvars>"; exit 1; }

TFVARS="$1"
[ ! -f "$TFVARS" ] && { log_error "Fichero no encontrado: $TFVARS"; exit 1; }

# ─── Extraer variable del tfvars ──────────────────────────────────────────────
extract_var() {
    grep -E "^\s*$1\s*=" "$TFVARS" \
      | head -1 \
      | sed 's/.*=\s*//; s/[" ]//g; s/#.*//' \
      || true
}

REGION=$(extract_var "region")
PROJECT=$(extract_var "project")
ENVIRONMENT=$(extract_var "environment")
DEVOPS_SERVICE_ACCOUNT_ID=$(extract_var "devops_service_account_id")

[ -z "$REGION" ]      && { log_error "region no encontrado en $TFVARS";      exit 1; }
[ -z "$PROJECT" ]     && { log_error "project no encontrado en $TFVARS";     exit 1; }
[ -z "$ENVIRONMENT" ] && { log_error "environment no encontrado en $TFVARS"; exit 1; }

# ─── Resolver account_id ──────────────────────────────────────────────────────
# Prioridad: TF_VAR_account_id (CI) > tfvars > STS (detección automática)
if [ -n "${TF_VAR_account_id:-}" ]; then
    ACCOUNT_ID="$TF_VAR_account_id"
    log_info "account_id desde TF_VAR_account_id: $ACCOUNT_ID"
else
    ACCOUNT_ID=$(extract_var "account_id")
    if [ -z "$ACCOUNT_ID" ]; then
        log_warn "account_id no encontrado en tfvars ni en TF_VAR_account_id — detectando via STS"
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    fi
    log_info "account_id resuelto: $ACCOUNT_ID"
fi

# ─── Determinar cuenta del state ─────────────────────────────────────────────
# Multi-cuenta: el state bucket vive en devops_service_account_id.
# Single-cuenta: el state bucket vive en la misma cuenta gestionada.
if [ -n "$DEVOPS_SERVICE_ACCOUNT_ID" ] && [ "$DEVOPS_SERVICE_ACCOUNT_ID" != "null" ]; then
    STATE_ACCOUNT_ID="$DEVOPS_SERVICE_ACCOUNT_ID"
    log_info "Modo multi-cuenta: state en cuenta devops $STATE_ACCOUNT_ID"
else
    STATE_ACCOUNT_ID="$ACCOUNT_ID"
    log_info "Modo single-cuenta: state en cuenta $STATE_ACCOUNT_ID"
fi

BUCKET_NAME="devops-${STATE_ACCOUNT_ID}-terraform-state-bucket"
DYNAMO_TABLE="devops-${STATE_ACCOUNT_ID}-terraform-state-lock"
STATE_KEY="${ACCOUNT_ID}/terraform-aws-${PROJECT}-${ENVIRONMENT}-${REGION}.tfstate"

log_info "Bucket S3:  $BUCKET_NAME"
log_info "DynamoDB:   $DYNAMO_TABLE"
log_info "State key:  $STATE_KEY"

# ─── Crear/verificar bucket S3 ────────────────────────────────────────────────
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    log_info "Bucket ya existe."
else
    log_info "Creando bucket $BUCKET_NAME en $REGION..."
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration \
        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
    aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    log_info "Bucket creado y configurado."
fi

# ─── Crear/verificar tabla DynamoDB ───────────────────────────────────────────
TABLE_STATUS=$(aws dynamodb describe-table \
    --table-name "$DYNAMO_TABLE" \
    --region "$REGION" \
    --query "Table.TableStatus" \
    --output text 2>&1 || echo "NOT_FOUND")

if [ "$TABLE_STATUS" = "NOT_FOUND" ] || echo "$TABLE_STATUS" | grep -q "ResourceNotFoundException"; then
    log_info "Creando tabla DynamoDB $DYNAMO_TABLE..."
    aws dynamodb create-table \
        --region "$REGION" \
        --table-name "$DYNAMO_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --tags Key=ManagedBy,Value=terraform Key=Project,Value="$PROJECT"
    aws dynamodb wait table-exists --region "$REGION" --table-name "$DYNAMO_TABLE"
    log_info "Tabla DynamoDB creada."
else
    log_info "Tabla DynamoDB ya existe ($TABLE_STATUS)."
fi

# ─── terraform init -reconfigure ─────────────────────────────────────────────
# No se genera backend.tf: los valores se inyectan via -backend-config.
log_info "Ejecutando terraform init -reconfigure..."
terraform init -reconfigure \
    -backend-config="bucket=${BUCKET_NAME}" \
    -backend-config="key=${STATE_KEY}" \
    -backend-config="region=${REGION}" \
    -backend-config="dynamodb_table=${DYNAMO_TABLE}" \
    -backend-config="encrypt=true"

echo ""
echo -e "${GREEN}Backend configurado correctamente.${NC}"
echo -e "  Bucket:  s3://${BUCKET_NAME}/${STATE_KEY}"
echo -e "  Lock:    ${DYNAMO_TABLE} (${REGION})"
