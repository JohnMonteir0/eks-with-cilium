### Cilium ###
resource "helm_release" "cilium" {
  name        = "cilium"
  description = "A Helm chart to deploy cilium"
  namespace   = "kube-system"
  chart       = "cilium"
  version     = "1.17.4"
  repository  = "https://helm.cilium.io"
  wait        = false
  replace     = true

  # API server host/port for kube-proxy replacement
  set {
    name  = "k8sServiceHost"
    value = replace(data.aws_eks_cluster.this.endpoint, "https://", "")
  }
  set {
    name  = "k8sServicePort"
    value = "443"
  }

  # EKS ENI IPAM (native routing, no tunneling)
  set {
    name  = "eni.enabled"
    value = "true"
  }
  set {
    name  = "ipam.mode"
    value = "eni"
  }
  set {
    name  = "routingMode"
    value = "native"
  }

  # Required with native routing on EKS
  set {
    name  = "endpointRoutes.enabled"
    value = "true"
  }

  # AWS-friendly masquerade
  set {
    name  = "egressMasqueradeInterfaces"
    value = "eth+"
  }

  # Replace kube-proxy
  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }
}