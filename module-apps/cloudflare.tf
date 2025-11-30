resource "kubernetes_secret" "external_dns_cloudflare" {
  metadata {
    name      = "external-dns-cloudflare"
    namespace = "kube-system"
  }

  data = {
    cloudflare_api_token = base64encode(data.aws_ssm_parameter.cloudflare_api_token.value)
  }
}

