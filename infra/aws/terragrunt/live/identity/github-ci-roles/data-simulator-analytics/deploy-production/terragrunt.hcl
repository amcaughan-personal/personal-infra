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
  function_name  = "data-simulator-analytics-runner"
  function_arn   = "arn:aws:lambda:us-east-2:${get_aws_account_id()}:function:${local.function_name}"
  repository_arn = "arn:aws:ecr:us-east-2:${get_aws_account_id()}:repository/data-simulator-analytics-runner"
}

# Deploys the dbt runner's image to this environment's function, then runs it once.
inputs = {
  repo                = "data-simulator-analytics"
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/data-simulator-analytics@1466249789"
  github_environment  = "production"
  purpose             = "deploy"
  description         = "deploy the dbt runner image to ${local.function_name}"

  statements = [
    # Signing in to ECR is account-wide; reading and pushing are limited to the registry.
    {
      sid       = "SignInToEcr"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    },
    # Lambda checks that whoever points a function at an image can read it.
    {
      sid       = "ReadImages"
      actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
      resources = [local.repository_arn]
    },
    {
      sid       = "UpdateCode"
      actions   = ["lambda:UpdateFunctionCode", "lambda:GetFunction", "lambda:GetFunctionConfiguration"]
      resources = [local.function_arn]
    },
    # The smoke test runs dbt once after each deploy.
    {
      sid       = "SmokeTest"
      actions   = ["lambda:InvokeFunction"]
      resources = [local.function_arn]
    },
  ]

  role_arn_name = "DEPLOY_ROLE_ARN"
  published_values = {
    FUNCTION_NAME  = local.function_name
    REPOSITORY_URL = "${get_aws_account_id()}.dkr.ecr.us-east-2.amazonaws.com/data-simulator-analytics-runner"
  }
}
