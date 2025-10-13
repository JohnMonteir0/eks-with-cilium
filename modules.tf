module "network" {
  source           = "./module-network"
  cluster_name     = module.eks_bottlerocket.cluster_name
  environment      = var.environment
  cluster_endpoint = module.eks_bottlerocket.cluster_endpoint
  queue_name       = module.karpenter.queue_name

  depends_on = [module.eks_bottlerocket]
}

module "helm" {
  source                  = "./module-apps"
  environment             = var.environment
  cluster_oidc_issuer_url = module.eks_bottlerocket.cluster_oidc_issuer_url
  cluster_name            = module.eks_bottlerocket.cluster_name
  vpc_id                  = module.vpc.vpc_id
  name_prefix             = local.name
  tags                    = local.tags
  public_subnet_ids_csv   = join(",", module.vpc.public_subnets)

  addons = var.addons

  depends_on = [
    module.network,
    kubectl_manifest.karpenter
  ]
}

resource "kubectl_manifest" "letsencrypt" {
  yaml_body = local.cm_issuer_yaml

  depends_on = [module.helm]
}

resource "kubectl_manifest" "karpenter" {
  for_each  = { for i, d in local.karpenter_docs : i => d }
  yaml_body = each.value

  # Ensure CRDs/webhooks exist + IAM/identity ready before applying NodeClass/NodePool
  depends_on = [
    module.network,                   # karpenter Helm release lives here
    module.karpenter,                 # IAM role / (optional) pod identity association
    aws_eks_addon.pod_identity_agent, # if you enabled the EKS Pod Identity addon
  ]
}
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = module.eks_bottlerocket.cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = data.aws_eks_addon_version.pod_identity.version
}

