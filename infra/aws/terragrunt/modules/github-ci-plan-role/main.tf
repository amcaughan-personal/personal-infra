# A read-only plan role for one repo, used by Terragrunt plans on its pull requests and by
# its scheduled drift check on main. What it can read is the github-ci-read-access module's:
# every resource's configuration but not data contents, besides the repo's own state and
# parameters. It writes nothing: plans run without state locks.

data "aws_partition" "current" {}

locals {
  provider_host = trimprefix(var.provider_url, "https://")
  state_bucket  = "arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket}"
}

data "aws_iam_policy_document" "plan_assume" {
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

    # Pull requests, and jobs on main outside any environment (the scheduled drift check).
    # Either way it's read-only.
    condition {
      test     = "StringEquals"
      variable = "${local.provider_host}:sub"
      values = [
        "${var.oidc_subject_prefix}:pull_request",
        "${var.oidc_subject_prefix}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "github-ci-plan-${var.repo}"
  description        = "Read-only Terragrunt plans on ${var.repo} pull requests and main"
  assume_role_policy = data.aws_iam_policy_document.plan_assume.json
}

module "read_access" {
  source = "../github-ci-read-access"

  repo                       = var.repo
  state_bucket               = var.state_bucket
  shared_ssm_parameter_paths = var.shared_ssm_parameter_paths
}

resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = module.read_access.managed_policy_arns[0]
}

data "aws_iam_policy_document" "plan_state" {
  statement {
    sid       = "ListOwnState"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.repo}/*"]
    }
  }

  statement {
    sid       = "ReadOwnState"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket}/${var.repo}/*"]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform_state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

resource "aws_iam_role_policy" "plan_reads" {
  name   = "plan_reads"
  role   = aws_iam_role.plan.id
  policy = module.read_access.plan_reads_json
}

resource "aws_iam_role_policy" "plan_deny_data_reads" {
  name   = "deny_data_reads"
  role   = aws_iam_role.plan.id
  policy = module.read_access.deny_data_reads_json
}

# personal-infra's GitHub stack turns this into the repo's PLAN_ROLE_ARN Actions secret
# (a secret because it contains the account ID, so GitHub masks it in public logs).
resource "aws_ssm_parameter" "plan_role_arn" {
  #checkov:skip=CKV2_AWS_34:Not a secret: a role ARN, kept out of public logs by GitHub's secret masking
  name        = "/github/${var.repo}/PLAN_ROLE_ARN"
  description = "Terragrunt plan role for ${var.repo} pull requests"
  type        = "String"
  value       = aws_iam_role.plan.arn
}
