resource "kubernetes_secret" "cloudflare_api_key" {
  metadata {
    name      = "cloudflare-api-key"
    namespace = "kube-system"
  }

  data = {
    apiKey = base64encode(data.aws_ssm_parameter.cloudflare_api_token.value)
  }
}