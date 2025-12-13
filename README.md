## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.13 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.19 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.37 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.19.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws_auth"></a> [aws\_auth](#module\_aws\_auth) | git::https://github.com/JohnMonteir0/terraform-eks-module.git//modules/aws-auth | main |
| <a name="module_eks_bottlerocket"></a> [eks\_bottlerocket](#module\_eks\_bottlerocket) | git::https://github.com/JohnMonteir0/terraform-eks-module.git | main |
| <a name="module_helm"></a> [helm](#module\_helm) | ./module-apps | n/a |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | git::https://github.com/JohnMonteir0/terraform-eks-module.git//modules/karpenter | main |
| <a name="module_karpenter_disabled"></a> [karpenter\_disabled](#module\_karpenter\_disabled) | git::https://github.com/JohnMonteir0/terraform-eks-module.git//modules/karpenter | main |
| <a name="module_network"></a> [network](#module\_network) | ./module-network | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.pod_identity_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_route_table_association.pods](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.pods](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc_ipv4_cidr_block_association.pods](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv4_cidr_block_association) | resource |
| [kubectl_manifest.karpenter](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.letsencrypt](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_addon_version.pod_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addons"></a> [addons](#input\_addons) | ## Addons ### | <pre>object({<br/>    alb                   = optional(bool, false)<br/>    external_dns          = optional(bool, false)<br/>    ingress_nginx         = optional(bool, false)<br/>    ebs_csi               = optional(bool, false)<br/>    cert_manager          = optional(bool, false)<br/>    kube_prometheus_stack = optional(bool, false)<br/>    argocd                = optional(bool, false)<br/>    jaeger                = optional(bool, false)<br/>    otel_collector        = optional(bool, false)<br/>    loki                  = optional(bool, false)<br/>    tempo                 = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for the AWS provider | `string` | n/a | yes |
| <a name="input_azs"></a> [azs](#input\_azs) | AZs you want to use, e.g., ["us-east-1a","us-east-1b"] | `list(string)` | n/a | yes |
| <a name="input_bootstrap_node"></a> [bootstrap\_node](#input\_bootstrap\_node) | Fixed system node group for Cilium/CoreDNS/Karpenter controller | <pre>object({<br/>    instance_type = string<br/>    min           = number<br/>    max           = number<br/>    desired       = number<br/>  })</pre> | n/a | yes |
| <a name="input_cluster_encryption_config"></a> [cluster\_encryption\_config](#input\_cluster\_encryption\_config) | EKS encryption configuration. Use {} to disable encryption. | <pre>object({<br/>    resources        = optional(list(string))<br/>    provider_key_arn = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `string` | n/a | yes |
| <a name="input_cm_acme_email"></a> [cm\_acme\_email](#input\_cm\_acme\_email) | Email used for ACME registration | `string` | `"johnmonteiro78@yahoo.com"` | no |
| <a name="input_cm_acme_env"></a> [cm\_acme\_env](#input\_cm\_acme\_env) | Which ACME environment to use for the ClusterIssuer | `string` | `"staging"` | no |
| <a name="input_cm_ingress_class"></a> [cm\_ingress\_class](#input\_cm\_ingress\_class) | ingress class used for the HTTP01 solver | `string` | `"nginx"` | no |
| <a name="input_create_kms_key"></a> [create\_kms\_key](#input\_create\_kms\_key) | Controls if a KMS key for cluster encryption should be created | `bool` | `true` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Create NAT gateways at all? | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | n/a | `string` | n/a | yes |
| <a name="input_karpenter_capacity_type"></a> [karpenter\_capacity\_type](#input\_karpenter\_capacity\_type) | Karpenter nodeclass/nodepool inputs (per env via envvars/*) | `string` | n/a | yes |
| <a name="input_karpenter_cpu_limit"></a> [karpenter\_cpu\_limit](#input\_karpenter\_cpu\_limit) | n/a | `string` | n/a | yes |
| <a name="input_karpenter_disk_gi"></a> [karpenter\_disk\_gi](#input\_karpenter\_disk\_gi) | n/a | `number` | n/a | yes |
| <a name="input_karpenter_instance_types"></a> [karpenter\_instance\_types](#input\_karpenter\_instance\_types) | n/a | `list(string)` | n/a | yes |
| <a name="input_one_nat_gateway_per_az"></a> [one\_nat\_gateway\_per\_az](#input\_one\_nat\_gateway\_per\_az) | When not single, prefer one NAT per AZ. | `bool` | `false` | no |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | n/a | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | n/a | `string` | n/a | yes |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Use a single shared NAT gateway (cheaper) vs per-AZ (HA/costly). | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Optional common tags | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | Core CIDRs | `string` | n/a | yes |

## Outputs

No outputs.
