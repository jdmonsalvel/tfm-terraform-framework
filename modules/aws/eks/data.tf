data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lookup dinámico de usuarios IAM por nombre para EKS access entries.
# Falla en plan si el usuario no existe — comportamiento intencionado.
locals {
  all_admin_usernames = toset(distinct(flatten([
    for k, v in var.eks : try(v.auth.admins.usernames, [])
  ])))
}

data "aws_iam_user" "admin_by_name" {
  for_each  = local.all_admin_usernames
  user_name = each.key
}
