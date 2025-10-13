variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  type = string # "dev" | "stg" | "prod"
}

variable "cluster_endpoint" {
  type = string
}

variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "coredns_ready_id" {
  type = string
}