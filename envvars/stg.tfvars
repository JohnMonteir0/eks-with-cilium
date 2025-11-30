project_name = "platform"
environment  = "stg"
cluster_name = "platform-stg"
aws_region   = "us-east-1"

create_kms_key = "false"

cluster_encryption_config = {
  resources        = ["secrets"]
  provider_key_arn = "arn:aws:kms:us-east-1:107363237542:key/811cfb58-f04d-4d5d-b481-233c8be15d9a"
}

vpc_cidr = "10.20.0.0/16"
pod_cidr = "100.65.0.0/17"

azs = ["us-east-1a", "us-east-1b"]

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
karpenter_instance_types = ["t3.medium"]
karpenter_cpu_limit      = "48"
karpenter_disk_gi        = 20

# Addons to enable or disable
addons = {
  alb                   = true
  external_dns          = true
  ingress_nginx         = true
  ebs_csi               = true
  cert_manager          = true
  kube_prometheus_stack = true
  argocd                = false
  jaeger                = false
  otel                  = false
  loki                  = false
  tempo                 = false
}
