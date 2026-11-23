# An apply role for one repo, used by Terragrunt applies from its main branch. It reads what
# the plan role reads (the github-ci-read-access module), writes the repo's Terraform state,
# and may create and change, but never delete, the resources named in var.manage_statements.
# Destroys and anything outside those stay local applies.
#
# IAM roles are the way out of any such limit, so the repo's own roles are handled
# separately: it may create and change roles named <prefix>-* only with this repo's
# permissions boundary attached, which caps what those roles can do at var.boundary_statements.
# It can't touch the boundary itself, or any github-ci-* role or policy.

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  partition     = data.aws_partition.current.partition
  account_id    = data.aws_caller_identity.current.account_id
  provider_host = trimprefix(var.provider_url, "https://")
  state_bucket  = "arn:${local.partition}:s3:::${var.state_bucket}"
  prefix        = coalesce(var.resource_prefix, var.repo)
  own_roles     = "arn:${local.partition}:iam::${local.account_id}:role/${local.prefix}-*"
  ci_identity = [
    "arn:${local.partition}:iam::${local.account_id}:role/github-ci-*",
    "arn:${local.partition}:iam::${local.account_id}:policy/github-ci-*",
  ]
}

module "read_access" {
  source = "../github-ci-read-access"

  repo                       = var.repo
  state_bucket               = var.state_bucket
  shared_ssm_parameter_paths = var.shared_ssm_parameter_paths
}

# --------------------------------------------------------------------------------------
# Permissions boundary for the repo's roles
# --------------------------------------------------------------------------------------

data "aws_iam_policy_document" "boundary" {
  dynamic "statement" {
    for_each = var.boundary_statements
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

resource "aws_iam_policy" "boundary" {
  name        = "github-ci-boundary-${var.repo}"
  description = "The most any IAM role created by ${var.repo}'s CI applies may do"
  policy      = data.aws_iam_policy_document.boundary.json
}

# --------------------------------------------------------------------------------------
# Role
# --------------------------------------------------------------------------------------

data "aws_iam_policy_document" "apply_assume" {
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

    # Only jobs in these GitHub environments, which allow only the main branch.
    condition {
      test     = "StringEquals"
      variable = "${local.provider_host}:sub"
      values   = [for env in var.github_environments : "${var.oidc_subject_prefix}:environment:${env}"]
    }
  }
}

resource "aws_iam_role" "apply" {
  name                 = "github-ci-apply-${var.repo}"
  description          = "Terragrunt applies from ${var.repo}'s main branch"
  assume_role_policy   = data.aws_iam_policy_document.apply_assume.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_read_only" {
  role       = aws_iam_role.apply.name
  policy_arn = module.read_access.managed_policy_arns[0]
}

resource "aws_iam_role_policy" "apply_deny_data_reads" {
  name   = "deny_data_reads"
  role   = aws_iam_role.apply.id
  policy = module.read_access.deny_data_reads_json
}

resource "aws_iam_role_policy" "apply_plan_reads" {
  name   = "plan_reads"
  role   = aws_iam_role.apply.id
  policy = module.read_access.plan_reads_json
}

data "aws_iam_policy_document" "apply_state" {
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
    sid       = "ReadAndWriteOwnState"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.state_bucket}/${var.repo}/*"]
  }

  statement {
    sid       = "UnlockOwnState"
    actions   = ["s3:DeleteObject"]
    resources = ["${local.state_bucket}/${var.repo}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "apply_state" {
  name   = "terraform_state"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_state.json
}

# Create and change the repo's own resources.
data "aws_iam_policy_document" "apply_resources" {
  dynamic "statement" {
    for_each = var.manage_statements
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

  statement {
    sid = "CreateOwnRolesWithBoundary"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = [local.own_roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.boundary.arn]
    }
  }

  # These actions don't support the boundary condition. They can't grant permissions, and
  # every <prefix>-* role carries the boundary, so its permissions stay capped.
  statement {
    sid = "ChangeOwnRoles"
    actions = [
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = [local.own_roles]
  }

  statement {
    sid       = "PassOwnRoles"
    actions   = ["iam:PassRole"]
    resources = [local.own_roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = var.pass_role_services
    }
  }
}

resource "aws_iam_role_policy" "apply_resources" {
  name   = "manage_resources"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_resources.json
}

# Explicit denies, so no allow added later can undo them.
data "aws_iam_policy_document" "apply_guardrails" {
  statement {
    sid    = "DenyCiIdentityChanges"
    effect = "Deny"
    actions = [
      "iam:Attach*",
      "iam:Create*",
      "iam:Delete*",
      "iam:Detach*",
      "iam:PassRole",
      "iam:Put*",
      "iam:SetDefaultPolicyVersion",
      "iam:Tag*",
      "iam:Untag*",
      "iam:Update*",
    ]
    resources = local.ci_identity
  }

  statement {
    sid       = "DenyBoundaryRemoval"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "apply_guardrails" {
  name   = "guardrails"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_guardrails.json
}

# personal-infra's GitHub stack turns this into the repo's APPLY_ROLE_ARN Actions secret
# (a secret because it contains the account ID, so GitHub masks it in public logs).
resource "aws_ssm_parameter" "apply_role_arn" {
  #checkov:skip=CKV2_AWS_34:Not a secret: a role ARN, kept out of public logs by GitHub's secret masking
  name        = "/github/${var.repo}/APPLY_ROLE_ARN"
  description = "Terragrunt apply role for ${var.repo}'s main branch"
  type        = "String"
  value       = aws_iam_role.apply.arn
}
