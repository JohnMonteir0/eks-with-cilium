locals {
  name         = "${var.project_name}-${var.environment}"
  vpc_cidr     = var.vpc_cidr
  pod_cidr     = var.pod_cidr
  azs          = var.azs
  az_index_map = { for idx, az in local.azs : az => idx }

  # discovery tag value used by Karpenter, subnets, SGs
  discovery = local.name

  # render list like: "t3.small","t3.medium" (for the Karpenter template)
  karpenter_instance_types_csv = join("\",\"", var.karpenter_instance_types)

  # To auto-build a default Hubble host when var.hubble_host is empty
  account_id          = data.aws_caller_identity.current.account_id
  hubble_host_default = "hubble-${var.environment}.${local.account_id}.realhandsonlabs.net"

  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

### Karpenter ###
locals {
  karpenter_role_name = module.karpenter.node_iam_role_name
}

locals {
  karpenter_yaml = templatefile("${path.module}/templates/karpenter.tpl.yaml", {
    role_name      = local.karpenter_role_name                   # <- from module.karpenter.*
    discovery      = local.discovery                             # e.g., platform-stg
    instance_types = "\"${local.karpenter_instance_types_csv}\"" # -> "t3.small","t3.medium"
    capacity_type  = var.karpenter_capacity_type
    cpu_limit      = var.karpenter_cpu_limit
    disk_gi        = var.karpenter_disk_gi
  })

  # Split the multi-doc YAML into individual manifests
  karpenter_docs = [
    for d in split("---", local.karpenter_yaml) : trimspace(d)
    if trimspace(d) != ""
  ]
}

### Letsencrypt ###
locals {
  # Use prod URL only when cm_acme_env == "prod"
  cm_acme_server = var.cm_acme_env == "prod" ? "https://acme-v02.api.letsencrypt.org/directory" : "https://acme-staging-v02.api.letsencrypt.org/directory"

  cm_issuer_name = "letsencrypt-${var.cm_acme_env}"

  # Render the YAML from the template
  cm_issuer_yaml = templatefile("${path.module}/templates/letsencrypt-issuer.tpl.yaml", {
    issuer_name   = local.cm_issuer_name
    acme_server   = local.cm_acme_server
    email         = var.cm_acme_email
    ingress_class = var.cm_ingress_class
  })
}