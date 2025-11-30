resource "kubernetes_secret" "cloudflare_api_key" {
  metadata {
    name      = "cloudflare-api-key"
    namespace = "kube-system"
  }

  data = {
    cloudflare_api_token = base64encode(data.aws_ssm_parameter.cloudflare_api_token.value)
  }
}

