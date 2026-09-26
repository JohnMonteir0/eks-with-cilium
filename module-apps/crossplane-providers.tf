locals {
  crossplane_aws_providers = {
    rds = {
      name    = "provider-aws-rds"
      package = "xpkg.crossplane.io/crossplane-contrib/provider-aws-rds:v2.0.0"
    }
    ec2 = {
      name    = "provider-aws-ec2"
      package = "xpkg.crossplane.io/crossplane-contrib/provider-aws-ec2:v2.0.0"
    }
  }
}

# Each AWS provider runs with its own IRSA role. The roles and their trust
# policies are defined in crossplane-iam.tf; these runtime configurations bind
# them to the provider service accounts.
resource "kubectl_manifest" "crossplane_provider_runtime_config" {
  for_each = var.addons.crossplane ? local.crossplane_aws_providers : {}

  yaml_body = yamlencode({
    apiVersion = "pkg.crossplane.io/v1beta1"
    kind       = "DeploymentRuntimeConfig"
    metadata = {
      name = "crossplane-aws-${each.key}"
    }
    spec = {
      serviceAccountTemplate = {
        metadata = {
          name = local.crossplane_service_accounts[each.key]
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.crossplane_provider[each.key].arn
          }
        }
      }
      deploymentTemplate = {
        spec = {
          selector = {}
          template = {
            spec = {
              containers = [{
                name = "package-runtime"
                securityContext = {
                  allowPrivilegeEscalation = false
                }
              }]
              securityContext = {
                fsGroup = 2000
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.crossplane,
    aws_iam_role_policy_attachment.crossplane_provider,
  ]
}

# Provider packages install the RDS and EC2 CRDs consumed by the Backstage
# database templates. ProviderConfig remains managed separately so application
# configuration can select the shared `aws` provider configuration.
resource "kubectl_manifest" "crossplane_aws_provider" {
  for_each = var.addons.crossplane ? local.crossplane_aws_providers : {}

  yaml_body = yamlencode({
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Provider"
    metadata = {
      name = each.value.name
    }
    spec = {
      package = each.value.package
      runtimeConfigRef = {
        name = "crossplane-aws-${each.key}"
      }
    }
  })

  depends_on = [kubectl_manifest.crossplane_provider_runtime_config]
}

# Creating a Provider object only submits the package installation to
# Crossplane. The AWS provider-family installs the ProviderConfig CRD
# asynchronously, so give it time to become discoverable before applying the
# first ProviderConfig. Re-run the gate whenever a provider package changes.
resource "time_sleep" "crossplane_aws_provider_crds" {
  count = var.addons.crossplane ? 1 : 0

  create_duration = "5m"
  triggers = {
    packages = sha256(jsonencode({
      for key, provider in local.crossplane_aws_providers : key => provider.package
    }))
  }

  depends_on = [kubectl_manifest.crossplane_aws_provider]
}

resource "kubectl_manifest" "crossplane_aws_provider_config" {
  count = var.addons.crossplane ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "aws.upbound.io/v1beta1"
    kind       = "ProviderConfig"
    metadata = {
      name = "aws"
    }
    spec = {
      credentials = {
        source = "IRSA"
      }
    }
  })

  depends_on = [time_sleep.crossplane_aws_provider_crds]
}
