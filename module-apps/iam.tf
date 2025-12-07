# ALB (AWS Load Balancer Controller)
resource "aws_iam_role" "eks_load_balancer_controller" {
  for_each = var.addons.alb ? local.one : local.none
  name     = "${local.iam_name_prefix}-lbc"
  path     = local.iam_path
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = data.aws_iam_openid_connect_provider.cluster.arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com",
          "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "load_balancer_controller_policy" {
  for_each = var.addons.alb ? local.one : local.none
  name     = "${local.iam_name_prefix}-lbc"
  path     = local.iam_path
  policy   = data.aws_iam_policy_document.lb_controller_policy.json
  tags     = var.tags
}

resource "aws_iam_role_policy_attachment" "attach_load_balancer_policy" {
  for_each   = var.addons.alb ? local.one : local.none
  role       = aws_iam_role.eks_load_balancer_controller["this"].name
  policy_arn = aws_iam_policy.load_balancer_controller_policy["this"].arn
}

# EBS CSI Controller
resource "aws_iam_role" "eks_ebs_csi_controller" {
  for_each = var.addons.alb ? local.one : local.none
  name     = "${local.iam_name_prefix}-ebs-csi"
  path     = local.iam_path
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = data.aws_iam_openid_connect_provider.cluster.arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com",
          "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "attach_ebs_csi_policy" {
  for_each   = var.addons.alb ? local.one : local.none
  role       = aws_iam_role.eks_ebs_csi_controller["this"].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ExternalDNS


