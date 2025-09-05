locals {
  oidc = split("/", var.cluster_oidc_issuer_url)[4]
}

locals {
  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
    "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
    # NOTE: do NOT set aws-load-balancer-subnets here
  }
}
