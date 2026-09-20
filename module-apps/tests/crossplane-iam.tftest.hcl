# Offline plan tests: no AWS credentials or Kubernetes cluster are used.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/TEST" }
  }
}
mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  cluster_name            = "platform-dev"
  cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/TEST"
  vpc_id                  = "vpc-0123456789abcdef0"
  environment             = "dev"
  name_prefix             = "platform-dev"
  tags                    = {}
}

run "disabled_creates_no_permissions" {
  command = plan
  variables {
    addons = {}
  }
  assert {
    condition = (
      length(aws_iam_role.crossplane_provider) == 0 &&
      length(aws_iam_policy.crossplane_provider) == 0 &&
      length(aws_iam_role_policy_attachment.crossplane_provider) == 0 &&
      length(output.crossplane_aws_permissions) == 0
    )
    error_message = "Disabled Crossplane must not create AWS permissions."
  }
}

run "enabled_permissions_are_scoped" {
  command = plan
  variables {
    addons = { crossplane = true }
  }

  assert {
    condition = (
      toset(keys(aws_iam_role.crossplane_provider)) == toset(["rds", "ec2"]) &&
      length(aws_iam_role_policy_attachment.crossplane_provider) == 2
    )
    error_message = "RDS and EC2 controllers must have separate attached IAM roles."
  }

  assert {
    condition = alltrue([
      for kind, role in aws_iam_role.crossplane_provider :
      length(jsondecode(role.assume_role_policy).Statement[0].Condition.StringEquals) == 2 &&
      jsondecode(role.assume_role_policy).Statement[0].Condition.StringEquals["oidc.eks.us-east-1.amazonaws.com/id/TEST:aud"] == "sts.amazonaws.com" &&
      jsondecode(role.assume_role_policy).Statement[0].Condition.StringEquals["oidc.eks.us-east-1.amazonaws.com/id/TEST:sub"] == "system:serviceaccount:crossplane-system:crossplane-provider-aws-${kind}"
    ])
    error_message = "IRSA must trust only the exact provider service account and STS audience."
  }

  assert {
    condition = alltrue(flatten([
      for policy in aws_iam_policy.crossplane_provider : [
        for statement in jsondecode(policy.policy).Statement :
        statement.Resource != "*" || alltrue([
          for action in flatten([statement.Action]) :
          can(regex("^(ec2:Describe|rds:Describe|rds:ListTagsForResource)", action))
        ])
      ]
    ]))
    error_message = "Only discovery operations may use a wildcard resource."
  }

  assert {
    condition = alltrue(flatten([
      for policy in aws_iam_policy.crossplane_provider : [
        for statement in jsondecode(policy.policy).Statement : [
          for action in flatten([statement.Action]) : !contains([
            "*", "rds:*", "ec2:*", "iam:*", "iam:PassRole",
            "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:CreateSubnet", "ec2:DeleteSubnet",
          ], action)
        ]
      ]
    ]))
    error_message = "Database providers must not get administrator, role-passing, or VPC/subnet lifecycle permissions."
  }

  assert {
    condition = alltrue([
      for arn in one([
        for statement in jsondecode(aws_iam_policy.crossplane_provider["rds"].policy).Statement :
        statement.Resource if statement.Sid == "ManageNamedDatabases"
      ]) : can(regex("^arn:aws:rds:us-east-1:123456789012:[a-z-]+:platform-dev-crossplane-\\*$", arn))
    ])
    error_message = "Database writes must be scoped to the account, region, and environment naming prefix."
  }

  assert {
    condition = one([
      for statement in jsondecode(aws_iam_policy.crossplane_provider["ec2"].policy).Statement :
      statement.Resource if statement.Sid == "CreateSecurityGroupsInClusterVPC"
    ]) == "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-0123456789abcdef0"
    error_message = "Security groups may only be created in the supplied VPC."
  }

  assert {
    condition = one([
      for statement in jsondecode(aws_iam_policy.crossplane_provider["ec2"].policy).Statement :
      statement.Condition.StringEquals["aws:RequestTag/crossplane-owner"] if statement.Sid == "RequireSecurityGroupOwnership"
    ]) == "platform-dev"
    error_message = "New security groups must carry the environment ownership tag."
  }

  assert {
    condition = one([
      for statement in jsondecode(aws_iam_policy.crossplane_provider["ec2"].policy).Statement :
      statement.Condition if statement.Sid == "ManageOwnedSecurityGroups"
      ]) == {
      StringEquals = { "ec2:ResourceTag/crossplane-owner" = "platform-dev" }
      ArnEquals    = { "ec2:Vpc" = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-0123456789abcdef0" }
    }
    error_message = "Security-group changes must require both VPC membership and ownership."
  }

  assert {
    condition = contains(one([
      for statement in jsondecode(aws_iam_policy.crossplane_provider["ec2"].policy).Statement :
      statement.Condition["ForAllValues:StringNotEquals"]["aws:TagKeys"] if statement.Sid == "MaintainNonOwnershipTags"
    ]), "crossplane-owner")
    error_message = "Tag updates must not allow changing the ownership tag."
  }
}

run "missing_vpc_is_rejected" {
  command = plan
  variables {
    addons = { crossplane = true }
    vpc_id = ""
  }
  expect_failures = [aws_iam_role.crossplane_provider]
}
