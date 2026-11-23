# What a repo's CI roles may read, as policy documents for the role modules to attach. Both
# its plan and apply roles get exactly this: every resource's configuration (ReadOnlyAccess,
# attached by the role module) but not data contents, except the repo's own Terraform state
# and SSM parameters and the shared parameters in var.shared_ssm_parameter_paths. Secrets
# stay out of reach: they are set by hand and never held in the repo's state.

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  state_bucket  = "arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket}"
  ssm_parameter = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter"
}

# Explicit denies win over ReadOnlyAccess's allows (and over any allow the role adds).
data "aws_iam_policy_document" "deny_data_reads" {
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
      # Secrets
      "secretsmanager:GetSecretValue",
    ]
    resources = ["*"]
  }

  # Lambda decrypts a function's environment variables for whoever reads the function;
  # nothing else may be decrypted.
  statement {
    sid       = "DenyDecryptExceptLambda"
    effect    = "Deny"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "kms:ViaService"
      values   = ["lambda.${data.aws_region.current.region}.amazonaws.com"]
    }
  }
}

# Reads that ReadOnlyAccess doesn't cover but plans need.
data "aws_iam_policy_document" "plan_reads" {
  statement {
    sid       = "ReadLambdaEnvironment"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["lambda.${data.aws_region.current.region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "ReadFlatRatePlans" # CloudFront flat-rate pricing plans
    actions   = ["pricingplanmanager:GetSubscription", "pricingplanmanager:ListSubscriptions"]
    resources = ["*"]
  }
}
