include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path           = find_in_parent_folders("common.hcl")
  merge_strategy = "deep"
}

# The double slash copies all of modules/, which the role module's read-access module needs.
terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt//modules/github-ci-plan-role"
}

inputs = {
  repo = "data-pipelines"

  # GitHub's immutable OIDC subject: org and repo by name and numeric ID, so a repo
  # deleted and recreated under the same name doesn't match.
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/data-pipelines@1470781659"
}
