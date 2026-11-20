locals {
  provider_host = trimprefix(var.provider_url, "https://")
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid    = "AllowGitHubActionsOidc"
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider_host}:aud"
      values   = var.allowed_audiences
    }

    condition {
      test     = "StringLike"
      variable = "${local.provider_host}:sub"
      values   = var.allowed_subjects
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.role_description
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policy_jsons

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}

# ---------------------------------------------------------------------------
# Optional "configuration yes, contents no" guardrail for plan-only roles.
# Explicit denies win over any Allow, including ReadOnlyAccess.
# ---------------------------------------------------------------------------
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  ssm_parameter_arn_prefix = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter"

  allowed_ssm_parameter_arns = [
    for path in var.data_read_allowed_ssm_parameter_paths :
    "${local.ssm_parameter_arn_prefix}${path}"
  ]
}

data "aws_iam_policy_document" "deny_data_reads" {
  count = var.deny_data_reads ? 1 : 0

  statement {
    sid    = "DenyS3ObjectReads"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTorrent",
      "s3:GetObjectVersionTorrent",
    ]
    resources     = length(var.data_read_allowed_s3_object_arns) == 0 ? ["*"] : null
    not_resources = length(var.data_read_allowed_s3_object_arns) > 0 ? var.data_read_allowed_s3_object_arns : null
  }

  statement {
    sid    = "DenySsmParameterValueReads"
    effect = "Deny"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameterHistory",
    ]
    resources     = length(local.allowed_ssm_parameter_arns) == 0 ? ["*"] : null
    not_resources = length(local.allowed_ssm_parameter_arns) > 0 ? local.allowed_ssm_parameter_arns : null
  }

  statement {
    sid    = "DenyDataPlaneReads"
    effect = "Deny"
    actions = [
      # Tables, streams, queues
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:GetRecords",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:SubscribeToShard",
      "sqs:ReceiveMessage",
      # Logs and query results
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:GetLogRecord",
      "logs:StartQuery",
      "logs:GetQueryResults",
      "logs:StartLiveTail",
      "athena:GetQueryResults",
      "athena:GetQueryResultsStream",
      # Container images and instance output
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ec2:GetConsoleOutput",
      "ec2:GetConsoleScreenshot",
      # Secrets and keys
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deny_data_reads" {
  count = var.deny_data_reads ? 1 : 0

  name   = "deny_data_reads"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.deny_data_reads[0].json
}
