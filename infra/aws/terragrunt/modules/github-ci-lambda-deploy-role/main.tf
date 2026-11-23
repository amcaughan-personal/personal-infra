# A role that deploys code to one Lambda function from one GitHub environment: it may
# update the function's code and invoke it (the smoke test), nothing else. It lives here,
# not in the project, because the project's infra is applied by CI, and CI must not be
# able to change who can assume what.

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  provider_host = trimprefix(var.provider_url, "https://")
  function_arn  = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${var.function_name}"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only jobs in this GitHub environment, which allows only the main branch.
    condition {
      test     = "StringEquals"
      variable = "${local.provider_host}:sub"
      values   = ["${var.oidc_subject_prefix}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "github-ci-deploy-${var.repo}-${var.github_environment}"
  description          = "GitHub Actions deploys of ${var.function_name} (${var.repo}, environment ${var.github_environment})"
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "UpdateCode"
    actions   = ["lambda:UpdateFunctionCode", "lambda:GetFunction", "lambda:GetFunctionConfiguration"]
    resources = [local.function_arn]
  }

  statement {
    sid       = "SmokeTest"
    actions   = ["lambda:InvokeFunction"]
    resources = [local.function_arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# personal-infra's GitHub stack turns these into the environment's DEPLOY_ROLE_ARN secret
# (it contains the account ID) and FUNCTION_NAME variable.
resource "aws_ssm_parameter" "values" {
  #checkov:skip=CKV2_AWS_34:Not secrets: a role ARN (masked as a GitHub secret) and a function name
  for_each = {
    DEPLOY_ROLE_ARN = aws_iam_role.deploy.arn
    FUNCTION_NAME   = var.function_name
  }

  name        = "/github/${var.repo}/${var.github_environment}/${each.key}"
  description = "${each.key} for ${var.repo}'s ${var.github_environment} deploys"
  type        = "String"
  value       = each.value
}
