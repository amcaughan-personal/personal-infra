# A role that GitHub Actions jobs assume to do one job, e.g. deploy code, refresh a dashboard
# or bring a cluster up and down, with exactly the permissions in var.statements. It lives
# here, not in the project, so the project's CI applies can't change who can assume what.
#
# Who may assume it: jobs in var.github_environment, or each entry in var.trusted (an
# environment or a branch, optionally pinned to one workflow file in the repo).
#
# Its ARN and any other values the workflow needs are published to SSM under
# /github/<repo>/<environment>/ (or /github/<repo>/ for a role without one); personal-infra's
# GitHub stack turns each into a secret (values with the account ID) or variable.

locals {
  provider_host = trimprefix(var.provider_url, "https://")

  trusted = coalesce(var.trusted, [{ environment = var.github_environment, ref = "refs/heads/main", workflow = null }])

  name_suffix = var.github_environment == null ? "" : "-${var.github_environment}"
  ssm_prefix  = var.github_environment == null ? "/github/${var.repo}" : "/github/${var.repo}/${var.github_environment}"
}

data "aws_iam_policy_document" "assume" {
  dynamic "statement" {
    for_each = local.trusted
    content {
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

      # Jobs in this GitHub environment (which allows only the main branch), or on this branch.
      condition {
        test     = "StringEquals"
        variable = "${local.provider_host}:sub"
        values = [statement.value.environment != null
          ? "${var.oidc_subject_prefix}:environment:${statement.value.environment}"
        : "${var.oidc_subject_prefix}:ref:${statement.value.ref}"]
      }

      # And, when set, only jobs defined in this workflow file of the repo, on that branch.
      dynamic "condition" {
        for_each = statement.value.workflow == null ? [] : [statement.value.workflow]
        content {
          test     = "StringEquals"
          variable = "${local.provider_host}:job_workflow_ref"
          values   = ["${var.github_owner}/${var.repo}/.github/workflows/${condition.value}@${statement.value.ref}"]
        }
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = "github-ci-${var.purpose}-${var.repo}${local.name_suffix}"
  description          = var.github_environment == null ? "GitHub Actions: ${var.description} (${var.repo})" : "GitHub Actions: ${var.description} (${var.repo}, environment ${var.github_environment})"
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

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
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

  name        = "${local.ssm_prefix}/${each.key}"
  description = var.github_environment == null ? "${each.key} for ${var.repo}" : "${each.key} for ${var.repo}'s ${var.github_environment} environment"
  type        = "String"
  value       = each.value
}

# Optional: read every resource's configuration (not data contents), like the plan and apply
# roles, and write the repo's Terraform state under var.state_write_prefixes.
module "read_access" {
  source = "../github-ci-read-access"
  count  = var.read_access ? 1 : 0

  repo                       = var.repo
  state_bucket               = var.state_bucket
  shared_ssm_parameter_paths = var.shared_ssm_parameter_paths
}

resource "aws_iam_role_policy_attachment" "read_only" {
  count = var.read_access ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = module.read_access[0].managed_policy_arns[0]
}

resource "aws_iam_role_policy" "deny_data_reads" {
  count = var.read_access ? 1 : 0

  name   = "deny_data_reads"
  role   = aws_iam_role.this.id
  policy = module.read_access[0].deny_data_reads_json
}

resource "aws_iam_role_policy" "plan_reads" {
  count = var.read_access ? 1 : 0

  name   = "plan_reads"
  role   = aws_iam_role.this.id
  policy = module.read_access[0].plan_reads_json
}

data "aws_iam_policy_document" "state" {
  count = length(var.state_write_prefixes) > 0 ? 1 : 0

  statement {
    sid       = "ListOwnState"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.repo}/*"]
    }
  }

  statement {
    sid       = "WriteState"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = [for prefix in var.state_write_prefixes : "arn:aws:s3:::${var.state_bucket}/${var.repo}/${prefix}*"]
  }

  statement {
    sid       = "UnlockState"
    actions   = ["s3:DeleteObject"]
    resources = [for prefix in var.state_write_prefixes : "arn:aws:s3:::${var.state_bucket}/${var.repo}/${prefix}*.tflock"]
  }
}

resource "aws_iam_role_policy" "state" {
  count = length(var.state_write_prefixes) > 0 ? 1 : 0

  name   = "terraform_state"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.state[0].json
}
