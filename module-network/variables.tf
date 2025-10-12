variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  type = string # "dev" | "stg" | "prod"
}