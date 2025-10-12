# ALB (AWS Load Balancer Controller)
resource "aws_iam_role" "eks_load_balancer_controller" {
  name = "${local.iam_name_prefix}-lbc"
  path = local.iam_path
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
  name   = "${local.iam_name_prefix}-lbc"
  path   = local.iam_path
  policy = data.aws_iam_policy_document.lb_controller_policy.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "attach_load_balancer_policy" {
  role       = aws_iam_role.eks_load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller_policy.arn
}

# EBS CSI Controller
resource "aws_iam_role" "eks_ebs_csi_controller" {
  name = "${local.iam_name_prefix}-ebs-csi"
  path = local.iam_path
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
  role       = aws_iam_role.eks_ebs_csi_controller.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ExternalDNS
resource "aws_iam_role" "eks_external_dns" {
  name = "${local.iam_name_prefix}-external-dns"
  path = local.iam_path
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = data.aws_iam_openid_connect_provider.cluster.arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com",
          "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:external-dns"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "external_dns_policy" {
  name   = "${local.iam_name_prefix}-external-dns"
  path   = local.iam_path
  policy = data.aws_iam_policy_document.external_dns_policy.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "attach_external_dns_policy" {
  role       = aws_iam_role.eks_external_dns.name
  policy_arn = aws_iam_policy.external_dns_policy.arn
}
