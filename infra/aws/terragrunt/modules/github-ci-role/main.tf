# A read-only plan role for one repo, used by Terragrunt plans on its pull requests. It can
# read every resource's configuration (ReadOnlyAccess) but not data contents, except the
# repo's own Terraform state and SSM parameters and the shared parameters in
# var.shared_ssm_parameter_paths. Secrets stay out of reach: they are set by hand and never
# held in the repo's state.

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  provider_host = trimprefix(var.provider_url, "https://")
  state_bucket  = "arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket}"
  ssm_parameter = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter"
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

    condition {
      test     = "StringEquals"
      variable = "${local.provider_host}:sub"
      values   = ["${var.oidc_subject_prefix}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "github-ci-plan-${var.repo}"
  description        = "Read-only Terragrunt plans on ${var.repo} pull requests"
  assume_role_policy = data.aws_iam_policy_document.plan_assume.json
}

resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"
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

  statement {
    sid       = "LockOwnState"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket}/${var.repo}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform_state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

# Explicit denies win over ReadOnlyAccess's allows.
data "aws_iam_policy_document" "plan_deny_data_reads" {
  statement {
    sid           = "DenyOtherS3Objects"
    effect        = "Deny"
    actions       = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetObjectTorrent", "s3:GetObjectVersionTorrent"]
    not_resources = ["${local.state_bucket}/${var.repo}/*"]
  }

  statement {
    sid     = "DenyOtherSsmParameters"
    effect  = "Deny"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "ssm:GetParameterHistory"]
    not_resources = [
      for path in concat(["/github/${var.repo}/*"], var.shared_ssm_parameter_paths) :
      "${local.ssm_parameter}${path}"
    ]
  }

  statement {
    sid    = "DenyDataContents"
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

resource "aws_iam_role_policy" "plan_deny_data_reads" {
  name   = "deny_data_reads"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_deny_data_reads.json
}
