include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  config = yamldecode(file("${get_parent_terragrunt_dir("root")}/config/repositories.yaml"))
}

terraform {
  source = "${get_repo_root()}/infra/github/terragrunt/modules/repositories"
}

inputs = {
  repositories         = local.config.repositories
  deploy_reviewers     = local.config.deploy_reviewers
}
