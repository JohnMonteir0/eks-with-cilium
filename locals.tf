locals {
  name   = "cilium"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Cluster    = local.name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }
}

locals {
  node_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name}-nodes"
}

data "aws_caller_identity" "current" {}