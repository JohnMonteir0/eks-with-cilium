module "network" {
  source       = "./module-network"
  cluster_name = module.eks_bottlerocket.cluster_name
  environment  = var.environment

  depends_on = [module.eks_bottlerocket]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks_bottlerocket.cluster_name
  addon_name                  = "coredns"
  addon_version               = "v1.12.3-eksbuild.1"
  tags                        = local.tags
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    tolerations = [
      { key = "node.kubernetes.io/not-ready", operator = "Exists" },
      { key = "node.cilium.io/agent-not-ready", operator = "Exists" }
    ]
  })

  depends_on = [module.network]
}
module "helm" {
  source                  = "./module-apps"
  cluster_oidc_issuer_url = module.eks_bottlerocket.cluster_oidc_issuer_url
  cluster_name            = module.eks_bottlerocket.cluster_name
  vpc_id                  = module.vpc.vpc_id
  cluster_endpoint        = module.eks_bottlerocket.cluster_endpoint
  queue_name              = module.karpenter.queue_name
  name_prefix             = local.name
  tags                    = local.tags
  public_subnet_ids_csv   = join(",", module.vpc.public_subnets)

  depends_on = [aws_eks_addon.coredns]
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
    module.helm,                      # karpenter Helm release lives here
    module.karpenter,                 # IAM role / (optional) pod identity association
    aws_eks_addon.pod_identity_agent, # if you enabled the EKS Pod Identity addon
  ]
}
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = module.eks_bottlerocket.cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = data.aws_eks_addon_version.pod_identity.version
}

