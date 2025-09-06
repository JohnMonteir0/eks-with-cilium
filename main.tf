module "eks_bottlerocket" {
  source = "git::https://github.com/JohnMonteir0/terraform-aws-eks.git?ref=master"

  cluster_name    = local.name
  cluster_version = "1.33"

  create_cloudwatch_log_group              = false
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  # disable all addons we will add them later.
  bootstrap_self_managed_addons = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  self_managed_node_groups = {
    karpenter = {
      ami_type      = "BOTTLEROCKET_x86_64"
      instance_type = "t3.medium"

      min_size     = 3
      max_size     = 6
      desired_size = 3

      create_iam_role            = true
      iam_role_name              = "${local.name}-nodes"
      iam_role_attach_cni_policy = true
      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      bootstrap_extra_args = <<-EOT
      [settings.host-containers.admin]
      enabled = false
      [settings.host-containers.control]
      enabled = true
      [settings.kernel]
      lockdown = "integrity"
    EOT

      labels = {
        "karpenter.sh/controller" = "true"
      }

      taints = [{
        key    = "node.cilium.io/agent-not-ready"
        value  = "true"
        effect = "NO_EXECUTE"
      }]
    }
  }

  depends_on = [module.aws_auth]
  node_security_group_additional_rules = {
    # allow all from VPC (simple + effective for tests)
    allow_all_from_vpc = {
      description = "Allow all traffic from VPC CIDR"
      type        = "ingress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = [module.vpc.vpc_cidr_block] # or local.vpc_cidr
    }

    # optional: be explicit for ICMP if you prefer tighter rules
    allow_icmp_from_vpc = {
      description = "Allow ICMP from VPC CIDR"
      type        = "ingress"
      protocol    = "icmp"
      from_port   = -1
      to_port     = -1
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  node_security_group_tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.name
  })

  tags = local.tags
}
