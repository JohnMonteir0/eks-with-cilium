project_name = "platform"
environment  = "dev"
cluster_name = "platform-dev"
aws_region   = "us-east-1"

# VPC and Pods CIDRs
vpc_cidr = "10.10.0.0/16"
pod_cidr = "100.64.0.0/17" # non-overlapping with vpc_cidr

# Use two AZs to keep costs lower
azs = ["us-east-1a", "us-east-1b"]

# Optional extra tags
tags = {
  Owner = "platform-team"
}

bootstrap_node = {
  instance_type = "t3.medium"
  min           = 2
  max           = 5
  desired       = 2
}

enable_nat_gateway     = true
single_nat_gateway     = true
one_nat_gateway_per_az = false

# allow both t3.small and t3.medium, on-demand (or spot)
karpenter_capacity_type  = "on-demand"
karpenter_instance_types = ["t3.small", "t3.medium"]
karpenter_cpu_limit      = "16"
karpenter_disk_gi        = 20

# Addons to enable or disable
addons = {
  alb                   = true
  external_dns          = true
  ingress_nginx         = false
  ebs_csi               = true
  cert_manager          = true
  kube_prometheus_stack = false
  argocd                = false
  jaeger                = false
  otel                  = false
  loki                  = false
  tempo                 = false
}
