# Application add-ons

The root `module "helm"` passes `var.addons` to this module. Each add-on uses
an optional boolean flag and the shared `local.one` / `local.none` pattern.

## Crossplane

Crossplane is installed from the [official stable Helm repository](https://docs.crossplane.io/v2.4/get-started/install/),
with chart version `2.4.0` pinned in `helm.tf`. The release creates the
`crossplane-system` namespace, waits for readiness, and uses an atomic install
with a 900-second timeout.

`addons.crossplane` defaults to `false`. It is enabled in `envvars/dev.tfvars`
and `envvars/prod.tfvars`, and disabled in staging. To enable it elsewhere, add
`crossplane = true` to that environment's existing `addons` object.

From the repository root, with AWS credentials for the intended environment:

```sh
terraform init -backend-config=backend/dev.tfbackend
terraform plan -var-file=envvars/dev.tfvars -out=dev.tfplan
# Review the full plan before applying it.
terraform apply dev.tfplan
kubectl get pods -n crossplane-system
```

Use the matching backend, variable file, and Kubernetes context for each environment.
This installs the Crossplane core controllers and CRDs and provisions the AWS
provider IAM roles described below. Provider packages, runtime configurations,
ProviderConfigs, and database resources are not installed by this module yet.

### Installation dependencies

The root `module "helm"` already depends on `module.network` and the Karpenter
NodePool/NodeClass manifests. Crossplane therefore installs after EKS, Cilium,
CoreDNS, and Karpenter setup. Its namespace, service account, RBAC, and CRDs are
managed by its Helm chart. With the current chart defaults, it does not require
ALB, ingress, external DNS, cert-manager, EBS CSI, or the monitoring stack.

The AWS provider IAM roles depend on the cluster OIDC provider; their policy
attachments reference the roles and policies directly. Crossplane core does not
use these roles, so IAM creation can run alongside its Helm installation. Future
AWS Provider/runtime manifests must wait for Crossplane CRDs and IAM attachments;
ProviderConfigs and managed resources must also wait for the provider CRDs.

### AWS permissions for RDS and Aurora

`crossplane-iam.tf` creates two IRSA roles when `addons.crossplane = true`:

| Provider | IAM role (dev) | Trusted service account in `crossplane-system` |
|----------|----------------|------------------------------------------------|
| RDS | `platform-dev-crossplane-rds` | `crossplane-provider-aws-rds` |
| EC2 (database security groups) | `platform-dev-crossplane-ec2` | `crossplane-provider-aws-ec2` |

Each role trusts only its exact service account through this EKS cluster's OIDC
provider, with the `sts.amazonaws.com` audience. The Crossplane core service
account does not receive these permissions. No static AWS credentials are needed.

The RDS role allows create, read, update, delete, and tagging operations for DB
instances, Aurora clusters and their instances, DB subnet groups, parameter and
option groups, and snapshots. AWS resource identifiers must begin with
`<name_prefix>-crossplane-`, for example `platform-dev-crossplane-orders`.
This includes subnet group names, custom parameter/option group names, and final
snapshot identifiers. Default AWS parameter/option groups can be referenced.
Discovery is allowed across the configured region; writes are scoped to the
current account, region, and naming prefix. The role can create only the standard
RDS service-linked role if it does not exist yet.

The EC2 role can discover existing networks and manage database security groups.
New groups must use the supplied `vpc_id` and include this tag at creation:

```yaml
spec:
  forProvider:
    tags:
      crossplane-owner: platform-dev
```

Use the environment's `name_prefix` as the tag value. Rule changes and deletion
require both this ownership tag and the cluster VPC. Tag updates cannot change
or remove the ownership tag. Use security-group inline rules or the classic
SecurityGroupRule resource; tagging standalone security-group-rule resources
is not included in this policy.

Neither role can create/delete VPCs or subnets. A DB subnet group references
existing subnet IDs; it does not create subnets. The RDS policy limits subnet
group names, but does not enforce their member subnet IDs or database public
access settings. Supply the approved private subnet IDs in future compositions.

This is a baseline database-management policy. Customer-managed KMS keys,
Secrets Manager-managed master passwords, enhanced-monitoring role passing,
snapshot restores, read-replica creation, global databases, and RDS Proxy require
additional permissions for the selected resources/features. Database login
permissions are separate from these infrastructure-management permissions.

For encrypted storage, the RDS role can create KMS grants only on behalf of RDS
in the configured account and region. This supports the account's AWS-managed
`alias/aws/rds` key and a customer-managed key whose key policy permits the
same grant operation.

After applying Terraform, retrieve the exact role ARNs (including their IAM path):

```sh
terraform output -json crossplane_aws_permissions
```

When installing each AWS provider later, connect it with a
`DeploymentRuntimeConfig`. For example, substitute the RDS role ARN from the
output into this manifest:

```yaml
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: crossplane-aws-rds
spec:
  serviceAccountTemplate:
    metadata:
      name: crossplane-provider-aws-rds
      annotations:
        eks.amazonaws.com/role-arn: <rds-role-arn-from-terraform-output>
```

Set the RDS Provider's `spec.runtimeConfigRef.name` to `crossplane-aws-rds`.
For EC2, use its own runtime config, service-account name, and role ARN from the
output. Configure the AWS ProviderConfig's `spec.credentials.source` as `IRSA`;
its API version/kind depends on the provider version and resource scope chosen
when installing the packages. IAM roles alone do not install or authenticate
provider pods until this wiring is applied.

References: [provider IRSA configuration](https://github.com/crossplane-contrib/provider-upjet-aws/blob/main/AUTHENTICATION.md),
[RDS authorization](https://docs.aws.amazon.com/service-authorization/latest/reference/list_rds.html),
[security-group policy examples](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-policy-examples.html).

Offline permission checks live in `tests/crossplane-iam.tftest.hcl`. With the
module initialized using the repository's provider versions, run
`terraform -chdir=module-apps test`. These mocked plan checks verify policy
boundaries and the disabled flag; they do not replace live AWS authorization
or provider reconciliation testing.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.external_dns_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.load_balancer_controller_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.eks_ebs_csi_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_external_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.attach_ebs_csi_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.attach_external_dns_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.attach_load_balancer_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.crossplane](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.ebs_csi_driver](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.external_dns](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.ingress-nginx](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.karpenter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_service_account.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_service_account.eks_ebs_csi_controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_service_account.external_dns](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.external_dns_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lb_controller_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnets.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | n/a | `string` | `"us-east-1"` | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | n/a | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster | `string` | `"cilium"` | no |
| <a name="input_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#input\_cluster\_oidc\_issuer\_url) | The OIDC issuer URL from the EKS cluster | `string` | n/a | yes |
| <a name="input_queue_name"></a> [queue\_name](#input\_queue\_name) | Name of the SQS queue | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where the cluster security group will be provisioned | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_public_subnet_ids_csv"></a> [public\_subnet\_ids\_csv](#output\_public\_subnet\_ids\_csv) | n/a |
<!-- END_TF_DOCS -->
