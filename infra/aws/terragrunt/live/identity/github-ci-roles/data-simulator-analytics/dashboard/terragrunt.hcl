include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path           = find_in_parent_folders("common.hcl")
  merge_strategy = "deep"
}

terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt//modules/github-ci-environment-role"
}

locals {
  workgroup = "data-simulator-analytics"
  gold      = "data_simulator_analytics_gold"
  warehouse = "arn:aws:s3:::data-simulator-analytics-warehouse-${get_aws_account_id()}"
  arn       = "arn:aws:%s:us-east-2:${get_aws_account_id()}:%s"
}

# The dashboard's daily refresh: query production's gold tables, nothing else.
inputs = {
  repo                = "data-simulator-analytics"
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/data-simulator-analytics@1466249789"
  github_environment  = "dashboard"
  purpose             = "dashboard"
  description         = "query the gold tables for the dashboard"

  statements = [
    {
      sid = "QueryInWorkgroup"
      actions = [
        "athena:StartQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults",
        "athena:GetWorkGroup",
      ]
      resources = [format(local.arn, "athena", "workgroup/${local.workgroup}")]
    },
    {
      sid     = "ReadGoldTables"
      actions = ["glue:GetDatabase", "glue:GetTable", "glue:GetTables", "glue:GetPartitions"]
      resources = [
        format(local.arn, "glue", "catalog"),
        format(local.arn, "glue", "database/${local.gold}"),
        format(local.arn, "glue", "table/${local.gold}/*"),
      ]
    },
    # The gold tables' files, and the query results Athena writes (and the refresh downloads).
    {
      sid       = "ReadGoldFiles"
      actions   = ["s3:GetObject"]
      resources = ["${local.warehouse}/tables/${local.gold}/*"]
    },
    {
      sid       = "QueryResults"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload"]
      resources = ["${local.warehouse}/athena-results/*"]
    },
    {
      sid       = "ListWarehouse"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = [local.warehouse]
    },
  ]

  role_arn_name = "DASHBOARD_ROLE_ARN"
}
