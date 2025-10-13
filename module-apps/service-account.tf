#############################################
# Load Balancer Controller SA
#############################################
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  # Mirror the IAM role’s toggle
  for_each = var.addons.alb ? local.one : local.none

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      # Index the matching IAM role instance
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_load_balancer_controller[each.key].arn
    }
  }
}

#############################################
# EBS CSI Controller SA
#############################################
resource "kubernetes_service_account" "eks_ebs_csi_controller" {
  for_each = var.addons.ebs_csi ? local.one : local.none

  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_ebs_csi_controller[each.key].arn
    }
  }
}

#############################################
# External DNS SA
#############################################
resource "kubernetes_service_account" "external_dns" {
  for_each = var.addons.external_dns ? local.one : local.none

  metadata {
    name      = "external-dns"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_external_dns[each.key].arn
    }
  }
}
