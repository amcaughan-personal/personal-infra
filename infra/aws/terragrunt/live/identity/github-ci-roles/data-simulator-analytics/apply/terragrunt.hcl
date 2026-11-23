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
  # Every analytics resource is named data-simulator-analytics-* (dev: -dev-*); Glue names
  # use underscores. Its runner reads the ELT's production raw zone.
  prefix = "data-simulator-analytics"
  arn    = "arn:aws:%s:us-east-2:${get_aws_account_id()}:%s"
}

inputs = {
  repo                = "data-simulator-analytics"
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/data-simulator-analytics@1466249789"
  github_environments = ["infra-dev", "infra-production"]

  # Creating the runner function itself stays a local apply: Lambda needs its creator to
  # read the image from ECR, which CI roles can't (image contents count as data).
  manage_statements = [
    {
      sid = "WarehouseBuckets"
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
      sid = "WarehouseCatalog"
      actions = [
        "glue:CreateDatabase",
        "glue:UpdateDatabase",
        "glue:TagResource",
        "glue:UntagResource",
      ]
      resources = [
        format(local.arn, "glue", "catalog"),
        format(local.arn, "glue", "database/data_simulator_analytics*"),
      ]
    },
    {
      sid = "Workgroups"
      actions = [
        "athena:CreateWorkGroup",
        "athena:UpdateWorkGroup",
        "athena:TagResource",
        "athena:UntagResource",
      ]
      resources = [format(local.arn, "athena", "workgroup/${local.prefix}*")]
    },
    {
      sid = "RunnerRegistry"
      actions = [
        "ecr:CreateRepository",
        "ecr:PutLifecyclePolicy",
        "ecr:PutImageTagMutability",
        "ecr:PutImageScanningConfiguration",
        "ecr:TagResource",
        "ecr:UntagResource",
      ]
      resources = [format(local.arn, "ecr", "repository/${local.prefix}-*")]
    },
    {
      sid = "RunnerFunctions"
      actions = [
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
      sid = "RunnerLogGroups"
      actions = [
        "logs:CreateLogGroup",
        "logs:PutRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource",
      ]
      resources = [format(local.arn, "logs", "log-group:/aws/lambda/${local.prefix}-*")]
    },
    {
      sid       = "RunnerSchedules"
      actions   = ["scheduler:CreateSchedule", "scheduler:UpdateSchedule"]
      resources = [format(local.arn, "scheduler", "schedule/default/${local.prefix}-*")]
    },
    {
      sid       = "RunnerAlarms"
      actions   = ["cloudwatch:PutMetricAlarm", "cloudwatch:TagResource", "cloudwatch:UntagResource"]
      resources = [format(local.arn, "cloudwatch", "alarm:${local.prefix}-*")]
    },
  ]

  # The runner's and scheduler's roles need no more than this: dbt in its own workgroups,
  # reading the ELT's raw zone, writing its own layers and warehouse.
  boundary_statements = [
    {
      sid       = "WriteOwnLogs"
      actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      resources = [format(local.arn, "logs", "log-group:/aws/lambda/${local.prefix}-*")]
    },
    {
      sid = "QueryInOwnWorkgroups"
      actions = [
        "athena:StartQueryExecution",
        "athena:StopQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults",
        "athena:GetWorkGroup",
      ]
      resources = [format(local.arn, "athena", "workgroup/${local.prefix}*")]
    },
    {
      sid = "ReadCatalog"
      actions = [
        "glue:GetDatabase",
        "glue:GetDatabases",
        "glue:GetTable",
        "glue:GetTables",
        "glue:GetPartition",
        "glue:GetPartitions",
        "glue:BatchGetPartition",
      ]
      resources = [
        format(local.arn, "glue", "catalog"),
        format(local.arn, "glue", "database/*"),
        format(local.arn, "glue", "table/data_simulator_elt_raw/*"),
        format(local.arn, "glue", "table/data_simulator_analytics*/*"),
      ]
    },
    {
      sid = "WriteOwnLayers"
      actions = [
        "glue:CreateTable",
        "glue:UpdateTable",
        "glue:DeleteTable",
        "glue:BatchDeleteTable",
        "glue:GetTableVersions",
        "glue:DeleteTableVersion",
        "glue:BatchDeleteTableVersion",
        "glue:CreatePartition",
        "glue:BatchCreatePartition",
        "glue:UpdatePartition",
        "glue:DeletePartition",
        "glue:BatchDeletePartition",
      ]
      resources = [
        format(local.arn, "glue", "catalog"),
        format(local.arn, "glue", "database/data_simulator_analytics*"),
        format(local.arn, "glue", "table/data_simulator_analytics*/*"),
      ]
    },
    {
      sid       = "ReadEltRawZone"
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::data-simulator-elt-raw-*/*"]
    },
    {
      sid       = "UseOwnWarehouse"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
      resources = ["arn:aws:s3:::${local.prefix}-*/*"]
    },
    {
      sid       = "ListBuckets"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = ["arn:aws:s3:::data-simulator-elt-raw-*", "arn:aws:s3:::${local.prefix}-*"]
    },
    {
      sid       = "InvokeOwnFunctions"
      actions   = ["lambda:InvokeFunction"]
      resources = [format(local.arn, "lambda", "function:${local.prefix}-*")]
    },
  ]

  pass_role_services = ["lambda.amazonaws.com", "scheduler.amazonaws.com"]
}
