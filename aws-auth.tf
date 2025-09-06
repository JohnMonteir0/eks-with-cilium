module "aws_auth" {
  source = "git::https://github.com/JohnMonteir0/terraform-aws-eks.git//modules/aws-auth?ref=master"

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = local.node_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/cloud_user"
      username = "cloud_user"
      groups   = ["system:masters"]
    }
  ]

}


