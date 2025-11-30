resource "kubernetes_secret" "cloudflare_api_key" {
  metadata {
    name      = "cloudflare-api-key"
    namespace = "kube-system"
  }

  data = {
    apiKey = data.aws_ssm_parameter.cloudflare_api_token.value
  }
}

