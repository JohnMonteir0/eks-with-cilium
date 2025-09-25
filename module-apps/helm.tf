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

  # storageClasses[0]
  set {
    name  = "storageClasses[0].name"
    value = "ebs-csi"
  }
  set {
    name  = "storageClasses[0].annotations.storageclass\\.kubernetes\\.io/is-default-class"
    value = "\"true\"" # note the extra quotes inside
  }
  set {
    name  = "storageClasses[0].volumeBindingMode"
    value = "WaitForFirstConsumer"
  }
  set {
    name  = "storageClasses[0].reclaimPolicy"
    value = "Delete"
  }
  set {
    name  = "storageClasses[0].parameters.encrypted"
    value = "\"true\""
  }
  set {
    name  = "storageClasses[0].parameters.type"
    value = "gp3"
  }

  depends_on = [
    aws_iam_role_policy_attachment.attach_ebs_csi_policy
  ]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.18.2"
  create_namespace = true
  timeout          = 900
  wait             = true
  replace          = true
  atomic           = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  set {
    name  = "webhook.timeoutSeconds"
    value = "30"
  }

  set {
    name  = "replicaCount"
    value = "2"
  }
  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.ingress-nginx
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
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
            "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
            "external-dns.alpha.kubernetes.io/hostname"      = "argocd.${data.aws_caller_identity.current.account_id}.realhandsonlabs.net"
            "cert-manager.io/cluster-issuer"                 = "letsencrypt-staging"
          }
          tls = [
            {
              hosts      = ["argocd.${data.aws_caller_identity.current.account_id}.realhandsonlabs.net"]
              secretName = "letsencrypt-staging"
            }
          ]
        }
      }
    })
  ]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.ingress-nginx,
    helm_release.cert_manager
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

resource "helm_release" "jaeger" {
  name             = "jaeger"
  namespace        = "giropops-senhas"
  repository       = "https://jaegertracing.github.io/helm-charts"
  chart            = "jaeger"
  version          = "0.73.1"
  atomic           = true
  create_namespace = true

  values = [
    yamlencode({
      fullnameOverride = "jaeger"

      storage = {
        type = "memory"
      }

      # Run all-in-one (collector + query + agent in one pod)
      allInOne = {
        enabled = true
      }

      # Collector (accepts traces from OTEL)
      collector = {
        enabled = true
        service = {
          grpc = {
            port = 14250
          }
        }
      }

      # Query UI (no ingress, only ClusterIP service)
      query = {
        enabled = true
        service = {
          type = "ClusterIP"
          ports = {
            http = 16686
          }
        }
      }

      # Disable agent
      agent = {
        enabled = false
      }
    })
  ]
}






