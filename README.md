# tfm-terraform-framework

> Framework Terraform AWS — 25 módulos reutilizables para la plataforma FIWARE GitOps
> TFM Máster DevOps UNIR · Jesús David Monsalve Lezama

## Módulos AWS disponibles

`acm` · `auto-scaling-group` · `db-subnet-group` · `dhcp` · `ec2` · `ecr` · `eks`
`iam` · `instance-scheduler` · `intenet-gw` · `keypair` · `kms` · `nat-gw`
`network-acl` · `rds` · `regional-nat-gw` · `route53` · `s3` · `secrets-manager`
`security-group` · `subnet` · `subnet-route-table` · `transit-gw` · `transit-gw-attach`
`transit-gw-route-table` · `vpc`

## Uso

```bash
cp variables/template.tfvars variables/<entorno>.tfvars
# Editar con valores reales (NO commitear)
terraform init
terraform plan -var-file="variables/<entorno>.tfvars"
terraform apply -var-file="variables/<entorno>.tfvars"
```

## Pipeline CI/CD

- **terraform-validate**: fmt + validate + Checkov (PR)
- **terraform-apply**: OIDC → AWS, aprobación manual vía entorno `aws-lab` (push a main)

## Repos relacionados

| Repo | Contenido |
|------|-----------|
| `tfm-fiware-docs` | Documentación académica |
| `tfm-fiware-gitops` | Configuración GitOps — fuente de verdad ArgoCD |
