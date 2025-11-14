project_name = "platform"
environment  = "prod"
cluster_name = "platform-prod"
aws_region   = "us-east-1"

# Give prod more room up front
vpc_cidr = "10.30.0.0/16"
pod_cidr = "100.66.0.0/16" # bigger pool if expect many pods

# Possible to use 2 or 3 AZs; NAT costs rise with more AZs if flip single_nat_gateway=false later
azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

tags = {
  Owner = "platform-team"
  Tier  = "critical"
}

bootstrap_node = {
  instance_type = "t3.medium"
  min           = 3
  max           = 8
  desired       = 5
}

enable_nat_gateway     = true
single_nat_gateway     = false
one_nat_gateway_per_az = true

# allow both t3.small and t3.medium, on-demand (or spot)
karpenter_capacity_type  = "on-demand"
karpenter_instance_types = ["t3.medium"]
karpenter_cpu_limit      = "128"
karpenter_disk_gi        = 30

# Addons to enable or disable
addons = {
  alb                   = true
  external_dns          = true
  ingress_nginx         = false
  ebs_csi               = true
  cert_manager          = true
  kube_prometheus_stack = true
  argocd                = true
  jaeger                = true
  otel_collector        = true
  loki                  = true
  tempo                 = true
}
