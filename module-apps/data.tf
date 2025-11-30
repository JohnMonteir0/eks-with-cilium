data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:kubernetes.io/role/elb"
    values = ["1"]
  }

  filter {
    name   = "tag:kubernetes.io/cluster/${var.cluster_name}"
    values = ["shared"]
  }
}

data "aws_iam_openid_connect_provider" "cluster" {
  url = var.cluster_oidc_issuer_url
}

data "aws_ssm_parameter" "cloudflare_api_token" {
  name = "/external-dns/cloudflare-api-token"
}

