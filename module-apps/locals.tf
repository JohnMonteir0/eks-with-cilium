locals {
  # Stable, env-scoped naming/prefixing for IAM (passed from root as local.name)
  iam_name_prefix = var.name_prefix # e.g., "platform-stg"
  iam_path        = "/eks/${var.name_prefix}/"

  # For trust policy keys: "${local.oidc_host}:aud" and ":sub"
  oidc_host             = replace(var.cluster_oidc_issuer_url, "https://", "")
  public_subnet_ids_csv = var.public_subnet_ids_csv

  # NLB Service annotations
  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
    "service.beta.kubernetes.io/aws-load-balancer-subnets"         = local.public_subnet_ids_csv
    "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
  }
}

# Avoid repeating the ternary:
# module-apps/locals.tf
locals {
  one  = { this = true }
  none = {}
}
