module "aws_auth" {
  source  = "git::https://github.com/JohnMonteir0/terraform-aws-eks.git//modules/aws-auth?ref=master"

  manage_aws_auth_configmap = true

#   aws_auth_roles = [
#     {
#       rolearn  = "arn:aws:iam::66666666666:role/role1"
#       username = "role1"
#       groups   = ["system:masters"]
#     },
#   ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/cloud_user"
      username = "cloud_user"
      groups   = ["system:masters"]
    }
  ]
}