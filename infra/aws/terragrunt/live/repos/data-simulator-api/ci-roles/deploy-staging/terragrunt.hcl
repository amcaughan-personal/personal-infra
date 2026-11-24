include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path           = find_in_parent_folders("common.hcl")
  merge_strategy = "deep"
}

terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt//modules/github-ci-environment-role"
}

locals {
  function_name = "data-simulator-api-staging"
  arn           = "arn:aws:%s:us-east-2:${get_aws_account_id()}:%s"
  function_arn  = format(local.arn, "lambda", "function:${local.function_name}")
}

# Publishes a new version of the API function and has CodeDeploy shift the live alias to it
# (the CodeDeploy application is named after the function; its deployment group after the alias).
inputs = {
  repo                = "data-simulator-api"
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/data-simulator-api@1179137908"
  github_environment  = "staging"
  purpose             = "deploy"
  description         = "publish ${local.function_name} and shift its live alias with CodeDeploy"

  statements = [
    {
      sid = "UploadAndPublishCode"
      actions = [
        "lambda:UpdateFunctionCode",
        "lambda:PublishVersion",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:GetAlias",
      ]
      resources = [local.function_arn, "${local.function_arn}:*"]
    },
    # Only for the first deploy, when the alias still points at $LATEST and there is no
    # version for CodeDeploy to shift from. Lambda authorizes UpdateAlias against the
    # function's ARN.
    {
      sid       = "PointNewAlias"
      actions   = ["lambda:UpdateAlias"]
      resources = [local.function_arn]
    },
    {
      sid       = "StartAndWatchDeployments"
      actions   = ["codedeploy:CreateDeployment", "codedeploy:GetDeployment"]
      resources = [format(local.arn, "codedeploy", "deploymentgroup:${local.function_name}/live")]
    },
    {
      sid       = "ReadDeploymentConfig"
      actions   = ["codedeploy:GetDeploymentConfig"]
      resources = [format(local.arn, "codedeploy", "deploymentconfig:CodeDeployDefault.LambdaAllAtOnce")]
    },
    {
      sid       = "RegisterRevision"
      actions   = ["codedeploy:RegisterApplicationRevision", "codedeploy:GetApplicationRevision"]
      resources = [format(local.arn, "codedeploy", "application:${local.function_name}")]
    },
  ]

  role_arn_name = "DEPLOY_ROLE_ARN"
}
