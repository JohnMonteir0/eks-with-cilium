locals {
  oidc = split("/", var.cluster_oidc_issuer_url)[4]
}

locals {
  public_subnet_ids_csv = join(",", module.vpc.public_subnets)  # or private_subnets
  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
    "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
    "service.beta.kubernetes.io/aws-load-balancer-subnets"         = local.public_subnet_ids_csv
  }
}

