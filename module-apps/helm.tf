#############################################
# AWS Load Balancer Controller
#############################################
resource "helm_release" "aws_load_balancer_controller" {
  for_each   = var.addons.alb ? local.one : local.none
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  atomic     = true
  wait       = true
  timeout    = 900

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
    value = aws_iam_role.eks_load_balancer_controller["this"].arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.attach_load_balancer_policy,
  ]
}

#############################################
# External DNS
#############################################
resource "helm_release" "external_dns" {
  for_each   = var.addons.external_dns ? local.one : local.none
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

#############################################
# Ingress NGINX
#############################################
resource "helm_release" "ingress_nginx" {
  for_each         = var.addons.ingress_nginx ? local.one : local.none
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.13.2"
  namespace        = "ingress-nginx"
  create_namespace = true
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

#############################################
# EBS CSI Driver
#############################################
resource "helm_release" "ebs_csi_driver" {
  for_each   = var.addons.ebs_csi ? local.one : local.none
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.30.0"
  namespace  = "kube-system"

  values = [yamlencode({
    controller = {
      serviceAccount = {
        create = false
        name   = "ebs-csi-controller-sa"
      }
    }
    enableVolumeScheduling = true
    enableVolumeResizing   = true
    enableVolumeSnapshot   = true
    storageClasses = [{
      name                 = "ebs-csi"
      annotations          = { "storageclass.kubernetes.io/is-default-class" = "true" }
      volumeBindingMode    = "WaitForFirstConsumer"
      reclaimPolicy        = "Delete"
      allowVolumeExpansion = true
      parameters           = { encrypted = "true", type = "gp3", fsType = "ext4" }
    }]
  })]

  depends_on = [
    aws_iam_role_policy_attachment.attach_ebs_csi_policy,
  ]
}

#############################################
# Cert-Manager
#############################################
resource "helm_release" "cert_manager" {
  for_each         = var.addons.cert_manager ? local.one : local.none
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.18.2"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  replace          = true
  atomic           = true
  timeout          = 900

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
    helm_release.ingress_nginx
  ]
}

#############################################
# Kube-Prometheus-Stack
#############################################
resource "helm_release" "kube_prometheus_stack" {
  for_each         = var.addons.kube_prometheus_stack ? local.one : local.none
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "77.9.1"
  namespace        = "monitoring"
  create_namespace = true
  atomic           = true
  timeout          = 900

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelector                  = {}
          serviceMonitorNamespaceSelector         = {}
          podMonitorSelector                      = {}
          podMonitorNamespaceSelector             = {}
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }
    })
  ]
}

#############################################
# Argocd
#############################################
resource "helm_release" "argocd" {
  for_each         = var.addons.argocd ? local.one : local.none
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      global = {
        domain = "argocd-${var.environment}.${data.aws_caller_identity.current.account_id}.montlabz.com"
      }
      configs = { params = { "server.insecure" = true } }
      server = {
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations = {
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
            "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
            "external-dns.alpha.kubernetes.io/hostname" = "argocd-${var.environment}.${data.aws_caller_identity.current.account_id}.montlabz.com"
            "cert-manager.io/cluster-issuer"            = "letsencrypt-staging"
          }
          tls = [{
            hosts      = ["argocd-${var.environment}.${data.aws_caller_identity.current.account_id}.montlabz.com"]
            secretName = "letsencrypt-staging"
          }]
        }
      }
    })
  ]

  depends_on = [

    helm_release.aws_load_balancer_controller,
    helm_release.ingress_nginx,
    helm_release.cert_manager
  ]
}

#############################################
# Jaeger
#############################################
resource "helm_release" "jaeger" {
  for_each         = var.addons.jaeger ? local.one : local.none
  name             = "jaeger"
  repository       = "https://jaegertracing.github.io/helm-charts"
  chart            = "jaeger"
  version          = "3.4.1"
  namespace        = "monitoring"
  create_namespace = true
  atomic           = true

  values = [
    yamlencode({
      fullnameOverride   = "jaeger"
      provisionDataStore = { cassandra = false, elasticsearch = false }
      storage            = { type = "memory" }
      allInOne = {
        enabled = true
        extraArgs = [
          "--collector.otlp.enabled=true",
          "--collector.otlp.grpc.host-port=:4317",
          "--collector.otlp.http.host-port=:4318",
        ]
        service = {
          ports = {
            http      = 16686
            otlp-grpc = 4317
            otlp-http = 4318
            grpc      = 14250
          }
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations = {
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
            "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
            "external-dns.alpha.kubernetes.io/hostname" = "jaeger-${var.environment}.${data.aws_caller_identity.current.account_id}.montlabz.com"
            "cert-manager.io/cluster-issuer"            = "letsencrypt-staging"
          }
          hosts = ["jaeger-${var.environment}.${data.aws_caller_identity.current.account_id}.montlabz.com"]
          tls = [{
            hosts      = ["jaeger-${var.environment}.${data.aws_caller_identity.current.account_id}.montlabz.com"]
            secretName = "letsencrypt-staging"
          }]
        }
      }
      query         = { enabled = false }
      collector     = { enabled = false }
      agent         = { enabled = false }
      cassandra     = { enabled = false }
      elasticsearch = { enabled = false }
      kafka         = { enabled = false }
      indexCleaner  = { enabled = false }
      esRollover    = { enabled = false }
    })
  ]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.ingress_nginx,
    helm_release.cert_manager
  ]
}

#############################################
# OpenTelemetry Collector
#############################################
resource "helm_release" "otel_collector" {
  for_each         = var.addons.otel_collector ? local.one : local.none
  name             = "otel-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = "0.132.0"
  namespace        = "monitoring"
  create_namespace = false
  atomic           = true

  values = [
    yamlencode({
      mode    = "deployment"
      image   = { repository = "otel/opentelemetry-collector-contrib" }
      service = { type = "ClusterIP" }
      config = {
        receivers = {
          otlp = { protocols = { grpc = { endpoint = "0.0.0.0:4317" }, http = { endpoint = "0.0.0.0:4318" } } }
        }
        processors = { batch = {} }
        exporters = {
          "otlp/jaeger" = { endpoint = "jaeger-collector:4317", tls = { insecure = true } }
          "otlp/tempo"  = { endpoint = "tempo:4317", tls = { insecure = true } }
          prometheus    = { endpoint = "0.0.0.0:9464" }
          debug         = { verbosity = "normal" }
        }
        service = {
          pipelines = {
            traces  = { receivers = ["otlp"], processors = ["batch"], exporters = ["otlp/jaeger", "otlp/tempo", "debug"] }
            metrics = { receivers = ["otlp"], processors = ["batch"], exporters = ["prometheus", "debug"] }
            logs    = { receivers = ["otlp"], processors = ["batch"], exporters = ["debug"] }
          }
          telemetry = { logs = { level = "info" } }
        }
      }
      resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { cpu = "500m", memory = "512Mi" }
      }
    })
  ]

  depends_on = [
    helm_release.jaeger,
    helm_release.ingress_nginx,
    helm_release.cert_manager,
    helm_release.aws_load_balancer_controller,
    helm_release.kube_prometheus_stack
  ]
}

#############################################
# Loki Stack
#############################################
resource "helm_release" "loki" {
  for_each         = var.addons.loki ? local.one : local.none
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  version          = "2.10.2"
  namespace        = "monitoring"
  create_namespace = false
  atomic           = true
  timeout          = 300

  values = [yamlencode({
    grafana = { enabled = false }
    loki = {
      enabled        = true
      auth_enabled   = false
      serviceMonitor = { enabled = true }
      singleBinary   = { enabled = true }
      commonConfig   = { replication_factor = 1 }
      storage        = { type = "filesystem" }
      schemaConfig = {
        configs = [{
          from         = "2024-01-01"
          store        = "tsdb"
          object_store = "filesystem"
          schema       = "v13"
          index        = { prefix = "index_", period = "24h" }
        }]
      }
      service = { type = "ClusterIP", port = 3100 }
    }
    promtail = {
      enabled = true
      config = {
        server    = { http_listen_port = 3101, grpc_listen_port = 0 }
        positions = { filename = "/run/promtail/positions.yaml" }
        clients   = [{ url = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push" }]
        scrape_configs = [{
          job_name = "kubernetes-pods"
          pipeline_stages = [
            { cri = {} },
            { regex = { expression = ".*(?:trace[id|_id|Id]|otel.trace_id)=(?P<trace_id>[A-Za-z0-9]+).*" } },
            { labels = { trace_id = "" } }
          ]
          kubernetes_sd_configs = [{ role = "pod" }]
          relabel_configs = [
            { source_labels = ["__meta_kubernetes_pod_node_name"], target_label = "node" },
            { source_labels = ["__meta_kubernetes_namespace"], target_label = "namespace" },
            { source_labels = ["__meta_kubernetes_pod_name"], target_label = "pod" },
            { source_labels = ["__meta_kubernetes_pod_container_name"], target_label = "container" },
            { source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"], target_label = "app" },
            { source_labels = ["__meta_kubernetes_pod_label_app"], target_label = "app", regex = "(.+)", action = "replace" },
            { action = "replace", replacement = "/var/log/pods/*$1/*.log", target_label = "__path__", source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"] }
          ]
        }]
      }
      serviceMonitor = { enabled = true, labels = { release = "kube-prometheus-stack" } }
    }
  })]

  depends_on = [
    helm_release.jaeger,
    helm_release.kube_prometheus_stack
  ]
}

#############################################
# Tempo
#############################################
resource "helm_release" "tempo" {
  for_each         = var.addons.tempo ? local.one : local.none
  name             = "tempo"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "tempo"
  version          = "1.23.3"
  namespace        = "monitoring"
  create_namespace = false
  atomic           = true
  timeout          = 600

  values = [yamlencode({
    fullnameOverride = "tempo"
    tempo = {
      config = <<-EOT
        server:
          http_listen_port: 3200
        distributor:
          receivers:
            otlp:
              protocols:
                http: {}
                grpc: {}
        storage:
          trace:
            backend: local
            local:
              path: /var/tempo
      EOT
    }
    service        = { type = "ClusterIP" }
    serviceMonitor = { enabled = true }
  })]

  depends_on = [
    helm_release.otel_collector,
    helm_release.kube_prometheus_stack
  ]
}