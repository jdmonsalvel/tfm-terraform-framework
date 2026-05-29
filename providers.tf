provider "aws" {
  region = var.region

  dynamic "assume_role" {
    for_each = var.cicd_role_name != null ? [1] : []
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/${var.cicd_role_name}"
      session_name = "deployment_session_${var.environment}_${var.project}_${var.accountable}"
    }
  }
}
