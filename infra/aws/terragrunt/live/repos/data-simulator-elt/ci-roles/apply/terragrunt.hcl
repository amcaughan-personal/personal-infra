include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path           = find_in_parent_folders("common.hcl")
  merge_strategy = "deep"
}

# The double slash copies all of modules/, which the role module's read-access module needs.
terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt//modules/github-ci-apply-role"
}

locals {
  # Every ELT resource is named data-simulator-elt-* (dev: data-simulator-elt-dev-*); Glue
  # names use underscores.
  prefix = "data-simulator-elt"
  arn    = "arn:aws:%s:us-east-2:${get_aws_account_id()}:%s"
}

inputs = {
  repo                = "data-simulator-elt"
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/data-simulator-elt@1179589127"
  github_environments = ["infra-dev", "infra-production"]

  manage_statements = [
    {
      sid = "RawZoneBuckets"
      actions = [
        "s3:CreateBucket",
        "s3:PutBucketPolicy",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketTagging",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration",
      ]
      resources = ["arn:aws:s3:::${local.prefix}-*"]
    },
    {
      sid = "RawZoneCatalog"
      actions = [
        "glue:CreateDatabase",
        "glue:UpdateDatabase",
        "glue:CreateTable",
        "glue:UpdateTable",
        "glue:TagResource",
        "glue:UntagResource",
      ]
      resources = [
        format(local.arn, "glue", "catalog"),
        format(local.arn, "glue", "database/data_simulator_elt*"),
        format(local.arn, "glue", "table/data_simulator_elt*/*"),
      ]
    },
    {
      sid = "IngestFunctions"
      actions = [
        "lambda:CreateFunction",
        "lambda:UpdateFunctionConfiguration",
        "lambda:PutFunctionConcurrency",
        "lambda:PutFunctionEventInvokeConfig",
        "lambda:UpdateFunctionEventInvokeConfig",
        "lambda:TagResource",
        "lambda:UntagResource",
      ]
      resources = [format(local.arn, "lambda", "function:${local.prefix}-*")]
    },
    {
      sid = "IngestLogGroups"
      actions = [
        "logs:CreateLogGroup",
        "logs:PutRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource",
      ]
      resources = [format(local.arn, "logs", "log-group:/aws/lambda/${local.prefix}-*")]
    },
    {
      sid       = "IngestSchedules"
      actions   = ["scheduler:CreateSchedule", "scheduler:UpdateSchedule"]
      resources = [format(local.arn, "scheduler", "schedule/default/${local.prefix}-*")]
    },
    {
      sid       = "IngestAlarms"
      actions   = ["cloudwatch:PutMetricAlarm", "cloudwatch:TagResource", "cloudwatch:UntagResource"]
      resources = [format(local.arn, "cloudwatch", "alarm:${local.prefix}-*")]
    },
  ]

  # The ingest function's role and the scheduler's role need no more than this.
  boundary_statements = [
    {
      sid       = "WriteOwnLogs"
      actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      resources = [format(local.arn, "logs", "log-group:/aws/lambda/${local.prefix}-*")]
    },
    {
      sid       = "UseRawZone"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      resources = ["arn:aws:s3:::${local.prefix}-*", "arn:aws:s3:::${local.prefix}-*/*"]
    },
    {
      sid       = "InvokeOwnFunctions"
      actions   = ["lambda:InvokeFunction"]
      resources = [format(local.arn, "lambda", "function:${local.prefix}-*")]
    },
  ]

  pass_role_services = ["lambda.amazonaws.com", "scheduler.amazonaws.com"]
}
