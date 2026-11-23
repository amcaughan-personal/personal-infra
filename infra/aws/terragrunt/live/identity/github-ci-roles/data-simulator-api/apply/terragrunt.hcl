include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path           = find_in_parent_folders("common.hcl")
  merge_strategy = "deep"
}

# The double slash copies all of modules/, which the role module's read-access module needs.
terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt//modules/github-ci-apply-role"
}

locals {
  # API resources are named data-simulator-api (prod) or data-simulator-api-staging; WAF web
  # ACLs live in us-east-1 (CloudFront's region). CloudFront distributions have only IDs, so
  # they're scoped by the Repo tag every resource here carries.
  prefix  = "data-simulator-api"
  account = get_aws_account_id()
  arn     = "arn:aws:%s:us-east-2:${get_aws_account_id()}:%s"
}

inputs = {
  repo                = "data-simulator-api"
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/data-simulator-api@1179137908"
  github_environments = ["infra-staging", "infra-production"]

  # Stays local: creating the API function (its package is built by the deploy workflow),
  # creating CloudFront distributions, the flat-rate pricing plan, and the smoke-test canary
  # (Synthetics builds its Lambda with the caller's credentials).
  manage_statements = [
    {
      sid = "Functions"
      actions = [
        "lambda:CreateFunction",
        "lambda:UpdateFunctionConfiguration",
        "lambda:PutFunctionConcurrency",
        "lambda:CreateAlias",
        "lambda:UpdateAlias",
        "lambda:CreateFunctionUrlConfig",
        "lambda:UpdateFunctionUrlConfig",
        "lambda:AddPermission",
        "lambda:TagResource",
        "lambda:UntagResource",
      ]
      resources = [
        format(local.arn, "lambda", "function:${local.prefix}*"),
        format(local.arn, "lambda", "function:${local.prefix}*:*"),
      ]
    },
    {
      sid = "LogGroups"
      actions = [
        "logs:CreateLogGroup",
        "logs:PutRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource",
      ]
      resources = [format(local.arn, "logs", "log-group:/aws/lambda/${local.prefix}*")]
    },
    {
      sid       = "Alarms"
      actions   = ["cloudwatch:PutMetricAlarm", "cloudwatch:TagResource", "cloudwatch:UntagResource"]
      resources = [format(local.arn, "cloudwatch", "alarm:${local.prefix}*")]
    },
    {
      sid = "Deployments"
      actions = [
        "codedeploy:CreateApplication",
        "codedeploy:UpdateApplication",
        "codedeploy:CreateDeploymentGroup",
        "codedeploy:UpdateDeploymentGroup",
        "codedeploy:TagResource",
        "codedeploy:UntagResource",
      ]
      resources = [
        format(local.arn, "codedeploy", "application:${local.prefix}*"),
        format(local.arn, "codedeploy", "deploymentgroup:${local.prefix}*/*"),
      ]
    },
    {
      sid       = "FrontDoorFirewalls"
      actions   = ["wafv2:UpdateWebACL", "wafv2:TagResource", "wafv2:UntagResource"]
      resources = ["arn:aws:wafv2:us-east-1:${local.account}:global/webacl/${local.prefix}*/*"]
    },
    {
      sid       = "FrontDoorDistributions"
      actions   = ["cloudfront:UpdateDistribution", "cloudfront:TagResource", "cloudfront:UntagResource"]
      resources = ["arn:aws:cloudfront::${local.account}:distribution/*"]
      conditions = [{
        test     = "StringEquals"
        variable = "aws:ResourceTag/Repo"
        values   = ["amcaughan-personal/data-simulator-api"]
      }]
    },
    {
      sid     = "PublishedValues"
      actions = ["ssm:PutParameter", "ssm:AddTagsToResource", "ssm:RemoveTagsFromResource"]
      resources = [
        format(local.arn, "ssm", "parameter/services/${local.prefix}/*"),
        format(local.arn, "ssm", "parameter/github/${local.prefix}/*"),
      ]
    },
  ]

  # The API function's, circuit breaker's and CodeDeploy's roles need no more than this.
  boundary_statements = [
    {
      sid       = "WriteOwnLogs"
      actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      resources = [format(local.arn, "logs", "log-group:/aws/lambda/${local.prefix}*")]
    },
    {
      # CodeDeploy moves the live alias; the circuit breaker throttles the API to zero.
      sid     = "OperateOwnFunctions"
      actions = ["lambda:GetAlias", "lambda:UpdateAlias", "lambda:GetFunction", "lambda:PutFunctionConcurrency"]
      resources = [
        format(local.arn, "lambda", "function:${local.prefix}*"),
        format(local.arn, "lambda", "function:${local.prefix}*:*"),
      ]
    },
    {
      sid       = "ReadAlarmState"
      actions   = ["cloudwatch:DescribeAlarms"]
      resources = ["*"]
    },
  ]

  pass_role_services = ["lambda.amazonaws.com", "codedeploy.amazonaws.com"]
}
