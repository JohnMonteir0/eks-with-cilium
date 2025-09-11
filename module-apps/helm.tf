resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  wait       = true
  timeout    = 900
  atomic     = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = data.aws_region.current.name
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eks_load_balancer_controller.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.attach_load_balancer_policy
  ]
}

### External DNS ###
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  version    = "1.15.0"
  namespace  = "kube-system"

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "policy"
    value = "sync"
  }
}

### Ingress NGINX Controller ###
resource "helm_release" "ingress-nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.13.2"
  create_namespace = true
  namespace        = "ingress-nginx"
  replace          = true
  atomic           = true

  values = [
    yamlencode({
      controller = {
        service = {
          annotations = local.annotations
        }
      }
    })
  ]
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}

### EBS CSI Driver Install ###
resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.30.0"

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  set {
    name  = "enableVolumeScheduling"
    value = "true"
  }

  set {
    name  = "enableVolumeResizing"
    value = "true"
  }

  set {
    name  = "enableVolumeSnapshot"
    value = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.attach_ebs_csi_policy
  ]
}

### Argocd ###
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  create_namespace = true
  timeout          = 900
  wait             = true

  values = [
    yamlencode({
      global = {
        domain = "argocd.${data.aws_caller_identity.current.account_id}.realhandsonlabs.net"
      }

      configs = {
        params = {
          "server.insecure" = true
        }
      }

      server = {
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations = {
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
            "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
            "external-dns.alpha.kubernetes.io/hostname"      = "argocd.${data.aws_caller_identity.current.account_id}.realhandsonlabs.net"
          }
          extraTls = [
            {
              hosts = ["argocd.${data.aws_caller_identity.current.account_id}.realhandsonlabs.net"]
            }
          ]
        }
      }
    })
  ]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.ingress-nginx
  ]
}

### Karpenter ###
resource "helm_release" "karpenter" {
  namespace  = "kube-system"
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.1.6"
  atomic     = true
  timeout    = 900

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "settings.interruptionQueue"
    value = var.queue_name
  }
}


