output "crossplane_aws_permissions" {
  description = "IAM roles and service-account settings for Crossplane AWS providers."
  value       = module.helm.crossplane_aws_permissions
}
