variable "project_name" {
  type = string
}
variable "environment" {
  type = string # "dev" | "stg" | "prod"
}
variable "cluster_name" {
  type = string
}

# Core CIDRs
variable "vpc_cidr" {
  type = string
}
variable "pod_cidr" {
  type = string # secondary CIDR for Cilium ENI (non-overlapping with vpc_cidr)
}

# AZs you want to use, e.g., ["us-east-1a","us-east-1b"]
variable "azs" {
  type = list(string)
}

# Optional common tags
variable "tags" {
  type    = map(string)
  default = {}
}

variable "aws_region" {
  description = "AWS region for the AWS provider"
  type        = string
}

# cert-manager / ACME settings
variable "cm_acme_email" {
  type        = string
  description = "Email used for ACME registration"
  default     = "johnmonteiro78@yahoo.com"
}

# "staging" or "prod" 
variable "cm_acme_env" {
  type        = string
  description = "Which ACME environment to use for the ClusterIssuer"
  default     = "staging"
}

# ingress class used for the HTTP01 solver
variable "cm_ingress_class" {
  type    = string
  default = "nginx"
}

variable "bootstrap_node" {
  description = "Fixed system node group for Cilium/CoreDNS/Karpenter controller"
  type = object({
    instance_type = string
    min           = number
    max           = number
    desired       = number
  })
}

# NAT (set in each env tfvars)
variable "enable_nat_gateway" {
  type        = bool
  description = "Create NAT gateways at all?"
  default     = true
}
variable "single_nat_gateway" {
  type        = bool
  description = "Use a single shared NAT gateway (cheaper) vs per-AZ (HA/costly)."
  default     = true
}
variable "one_nat_gateway_per_az" {
  type        = bool
  description = "When not single, prefer one NAT per AZ."
  default     = false
}

variable "create_kms_key" {
  type        = bool
  description = "Controls if a KMS key for cluster encryption should be created"
  default     = true
}

variable "cluster_encryption_config" {
  description = "Configuration block with encryption configuration for the cluster. To disable secret encryption, set this value to `{}`"
  type        = any
  default = {
    resources = ["secrets"]
  }
}

# Karpenter nodeclass/nodepool inputs (per env via envvars/*)
variable "karpenter_capacity_type" { type = string } # "on-demand" or "spot"

variable "karpenter_instance_types" { type = list(string) } # e.g. ["t3.small","t3.medium"]

variable "karpenter_cpu_limit" { type = string } # e.g. "16" (cluster-wide pool cap; K8s quantity)

variable "karpenter_disk_gi" { type = number } # e.g. 20

### Addons ###
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
