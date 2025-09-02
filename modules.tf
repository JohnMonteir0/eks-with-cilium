
module "helm" {
  source                  = "./module"
  cluster_oidc_issuer_url = module.eks_bottlerocket.cluster_oidc_issuer_url
  cluster_name            = module.eks_bottlerocket.cluster_name
  vpc_id                  = module.vpc.vpc_id
  cluster_endpoint        = module.eks_bottlerocket.cluster_endpoint
  queue_name              = module.karpenter.queue_name

  depends_on = [module.eks_bottlerocket]
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = module.eks_bottlerocket.cluster_name
  addon_name    = "coredns"
  addon_version = "v1.12.2-eksbuild.4" # K8s 1.33 current
  tags          = local.tags
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = module.eks_bottlerocket.cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.8-eksbuild.2"
}

