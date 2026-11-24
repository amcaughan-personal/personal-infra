include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path           = find_in_parent_folders("common.hcl")
  merge_strategy = "deep"
}

terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt//modules/github-ci-lambda-deploy-role"
}

inputs = {
  repo                = "data-simulator-elt"
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/data-simulator-elt@1179589127"
  github_environment  = "production"
  function_name       = "data-simulator-elt-ingest"
}
