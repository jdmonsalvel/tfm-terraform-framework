terraform {
  backend "s3" {
    bucket  = "devops-101490102336-terraform-state-bucket"
    key     = "101490102336/terraform-aws-tfm-lab-eu-west-1.tfstate"
    region  = "eu-west-1"
    encrypt = true
    # Sin DynamoDB — lab de un único operador
  }
}
