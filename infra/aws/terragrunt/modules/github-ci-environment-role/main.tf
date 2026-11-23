# A role that one GitHub environment's jobs assume to do one job, e.g. deploy code or
# refresh a dashboard, with exactly the permissions in var.statements. It lives here, not in
# the project, so the project's CI applies can't change who can assume what.
#
# Its ARN and any other values the workflow needs are published to SSM under
# /github/<repo>/<environment>/; personal-infra's GitHub stack turns each into that
# environment's secret (values with the account ID) or variable.

locals {
  provider_host = trimprefix(var.provider_url, "https://")
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

resource "aws_iam_role" "this" {
  name                 = "github-ci-${var.purpose}-${var.repo}-${var.github_environment}"
  description          = "GitHub Actions: ${var.description} (${var.repo}, environment ${var.github_environment})"
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.statements
    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "this" {
  name   = var.purpose
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_ssm_parameter" "values" {
  #checkov:skip=CKV2_AWS_34:Not secrets: role ARNs and resource names; ones with the account ID become masked GitHub secrets
  for_each = merge({ (var.role_arn_name) = aws_iam_role.this.arn }, var.published_values)

  name        = "/github/${var.repo}/${var.github_environment}/${each.key}"
  description = "${each.key} for ${var.repo}'s ${var.github_environment} environment"
  type        = "String"
  value       = each.value
}
