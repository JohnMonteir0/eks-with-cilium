# Permissions for future AWS provider controllers, not the Crossplane core pod.
data "aws_partition" "crossplane" {}

locals {
  crossplane_name_prefix = "${var.name_prefix}-crossplane-"
  crossplane_arn_prefix  = "arn:${data.aws_partition.crossplane.partition}"
  crossplane_rds_arn     = "${local.crossplane_arn_prefix}:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"
  crossplane_ec2_arn     = "${local.crossplane_arn_prefix}:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"
  crossplane_vpc_arn     = "${local.crossplane_ec2_arn}:vpc/${var.vpc_id == null ? "" : var.vpc_id}"
  crossplane_owner_tag   = "crossplane-owner"

  crossplane_service_accounts = {
    rds = "crossplane-provider-aws-rds"
    ec2 = "crossplane-provider-aws-ec2"
  }

  crossplane_network_read = {
    Sid    = "DiscoverExistingNetwork"
    Effect = "Allow"
    Action = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeTags",
    ]
    Resource  = "*"
    Condition = { StringEquals = { "aws:RequestedRegion" = data.aws_region.current.name } }
  }

  crossplane_rds_resources = [
    for kind in ["db", "cluster", "pg", "cluster-pg", "og", "subgrp", "snapshot", "cluster-snapshot"] :
    "${local.crossplane_rds_arn}:${kind}:${local.crossplane_name_prefix}*"
  ]

  crossplane_policies = {
    rds = jsonencode({
      Version = "2012-10-17"
      Statement = [
        local.crossplane_network_read,
        {
          Sid       = "ObserveDatabases"
          Effect    = "Allow"
          Action    = ["rds:Describe*", "rds:ListTagsForResource"]
          Resource  = "*"
          Condition = { StringEquals = { "aws:RequestedRegion" = data.aws_region.current.name } }
        },
        {
          Sid    = "ManageNamedDatabases"
          Effect = "Allow"
          Action = [
            "rds:CreateDBInstance", "rds:ModifyDBInstance", "rds:DeleteDBInstance",
            "rds:CreateDBCluster", "rds:ModifyDBCluster", "rds:DeleteDBCluster",
            "rds:CreateDBSubnetGroup", "rds:ModifyDBSubnetGroup", "rds:DeleteDBSubnetGroup",
            "rds:CreateDBParameterGroup", "rds:ModifyDBParameterGroup", "rds:ResetDBParameterGroup", "rds:DeleteDBParameterGroup",
            "rds:CreateDBClusterParameterGroup", "rds:ModifyDBClusterParameterGroup", "rds:ResetDBClusterParameterGroup", "rds:DeleteDBClusterParameterGroup",
            "rds:CreateOptionGroup", "rds:ModifyOptionGroup", "rds:DeleteOptionGroup",
            "rds:CreateDBSnapshot", "rds:DeleteDBSnapshot",
            "rds:CreateDBClusterSnapshot", "rds:DeleteDBClusterSnapshot",
            "rds:AddTagsToResource", "rds:RemoveTagsFromResource",
          ]
          Resource = local.crossplane_rds_resources
        },
        {
          # RDS authorizes the parameter/option groups referenced by these calls.
          Sid    = "UseDefaultParameterAndOptionGroups"
          Effect = "Allow"
          Action = ["rds:CreateDBInstance", "rds:ModifyDBInstance", "rds:CreateDBCluster", "rds:ModifyDBCluster"]
          Resource = [
            "${local.crossplane_rds_arn}:pg:default*",
            "${local.crossplane_rds_arn}:cluster-pg:default*",
            "${local.crossplane_rds_arn}:og:default*",
          ]
        },
        {
          # RDS creates a KMS grant on behalf of the provider role when it
          # provisions encrypted database storage with the account RDS key.
          Sid      = "CreateRdsEncryptionGrants"
          Effect   = "Allow"
          Action   = "kms:CreateGrant"
          Resource = "${local.crossplane_arn_prefix}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
          Condition = {
            Bool = { "kms:GrantIsForAWSResource" = "true" }
            StringEquals = {
              "kms:CallerAccount" = data.aws_caller_identity.current.account_id
              "kms:ViaService"    = "rds.${data.aws_region.current.name}.amazonaws.com"
            }
          }
        },
        {
          # DescribeKey does not include the GrantIsForAWSResource context key,
          # so it must not share the grant-only Bool condition above.
          Sid      = "DescribeRdsEncryptionKeys"
          Effect   = "Allow"
          Action   = "kms:DescribeKey"
          Resource = "${local.crossplane_arn_prefix}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
          Condition = {
            StringEquals = {
              "kms:CallerAccount" = data.aws_caller_identity.current.account_id
              "kms:ViaService"    = "rds.${data.aws_region.current.name}.amazonaws.com"
            }
          }
        },
        {
          # RDS requires these dependent actions when it creates a managed
          # master-user password in Secrets Manager.
          Sid      = "CreateRdsMasterUserSecrets"
          Effect   = "Allow"
          Action   = ["secretsmanager:CreateSecret", "secretsmanager:TagResource"]
          Resource = "${local.crossplane_arn_prefix}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:rds!*"
        },
        {
          Sid      = "BootstrapRDSServiceLinkedRole"
          Effect   = "Allow"
          Action   = "iam:CreateServiceLinkedRole"
          Resource = "${local.crossplane_arn_prefix}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
          Condition = {
            StringEquals = { "iam:AWSServiceName" = "rds.amazonaws.com" }
          }
        },
      ]
    })
    ec2 = jsonencode({
      Version = "2012-10-17"
      Statement = [
        local.crossplane_network_read,
        {
          # VPC and new security-group authorization must be separate: the VPC
          # resource does not support aws:RequestTag conditions for this action.
          Sid      = "CreateSecurityGroupsInClusterVPC"
          Effect   = "Allow"
          Action   = "ec2:CreateSecurityGroup"
          Resource = local.crossplane_vpc_arn
        },
        {
          Sid      = "RequireSecurityGroupOwnership"
          Effect   = "Allow"
          Action   = "ec2:CreateSecurityGroup"
          Resource = "${local.crossplane_ec2_arn}:security-group/*"
          Condition = {
            StringEquals = { "aws:RequestTag/${local.crossplane_owner_tag}" = var.name_prefix }
          }
        },
        {
          Sid      = "TagSecurityGroupsOnCreation"
          Effect   = "Allow"
          Action   = "ec2:CreateTags"
          Resource = "${local.crossplane_ec2_arn}:security-group/*"
          Condition = {
            StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" }
          }
        },
        {
          Sid    = "ManageOwnedSecurityGroups"
          Effect = "Allow"
          Action = [
            "ec2:DeleteSecurityGroup",
            "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
            "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
            "ec2:ModifySecurityGroupRules",
            "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
            "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
          ]
          Resource = "${local.crossplane_ec2_arn}:security-group/*"
          Condition = {
            StringEquals = { "ec2:ResourceTag/${local.crossplane_owner_tag}" = var.name_prefix }
            ArnEquals    = { "ec2:Vpc" = local.crossplane_vpc_arn }
          }
        },
        {
          Sid      = "MaintainNonOwnershipTags"
          Effect   = "Allow"
          Action   = ["ec2:CreateTags", "ec2:DeleteTags"]
          Resource = "${local.crossplane_ec2_arn}:security-group/*"
          Condition = {
            StringEquals                   = { "ec2:ResourceTag/${local.crossplane_owner_tag}" = var.name_prefix }
            "ForAllValues:StringNotEquals" = { "aws:TagKeys" = [local.crossplane_owner_tag] }
          }
        },
      ]
    })
  }
}

resource "aws_iam_role" "crossplane_provider" {
  for_each = var.addons.crossplane ? local.crossplane_service_accounts : {}

  name = "${local.crossplane_name_prefix}${each.key}"
  path = local.iam_path
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.cluster.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
          "${local.oidc_host}:sub" = "system:serviceaccount:crossplane-system:${each.value}"
        }
      }
    }]
  })
  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.vpc_id != null && var.vpc_id != ""
      error_message = "Crossplane AWS permissions require the existing cluster VPC ID."
    }
  }
}

resource "aws_iam_policy" "crossplane_provider" {
  for_each = var.addons.crossplane ? local.crossplane_service_accounts : {}

  name   = "${local.crossplane_name_prefix}${each.key}"
  path   = local.iam_path
  policy = local.crossplane_policies[each.key]
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "crossplane_provider" {
  for_each = var.addons.crossplane ? local.crossplane_service_accounts : {}

  role       = aws_iam_role.crossplane_provider[each.key].name
  policy_arn = aws_iam_policy.crossplane_provider[each.key].arn
}

output "crossplane_aws_permissions" {
  description = "IRSA wiring and naming requirements for the future Crossplane AWS providers. Empty when Crossplane is disabled."
  value = {
    for kind, role in aws_iam_role.crossplane_provider : kind => {
      role_arn             = role.arn
      service_account_name = local.crossplane_service_accounts[kind]
      namespace            = "crossplane-system"
      resource_name_prefix = local.crossplane_name_prefix
      security_group_tags  = { (local.crossplane_owner_tag) = var.name_prefix }
    }
  }
}
