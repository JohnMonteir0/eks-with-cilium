variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster security group will be provisioned"
  type        = string
  default     = null
}

variable "cluster_oidc_issuer_url" {
  type        = string
  description = "The OIDC issuer URL from the EKS cluster"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "public_subnet_ids_csv" {
  type    = string
  default = ""
}

variable "tags" {
  type = map(string)
}
variable "name_prefix" {
  type        = string
  description = "Prefix for IAM names and tags (e.g., platform-stg)"
}

variable "environment" {
  type = string # "dev" | "stg" | "prod"
}

# Choose which helm installation to enable
variable "addons" {
  type = object({
    alb                   = optional(bool, false)
    external_dns          = optional(bool, false)
    ingress_nginx         = optional(bool, false)
    ebs_csi               = optional(bool, false)
    cert_manager          = optional(bool, false)
    kube_prometheus_stack = optional(bool, false)
    argocd                = optional(bool, false)
    jaeger                = optional(bool, false)
    otel_collector        = optional(bool, false)
    loki                  = optional(bool, false)
    tempo                 = optional(bool, false)
  })
  default = {}
}
