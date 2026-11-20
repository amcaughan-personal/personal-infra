include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  repository_data = yamldecode(file("${get_parent_terragrunt_dir("root")}/data/repositories.yaml"))
}

terraform {
  source = "${get_repo_root()}/infra/github/terragrunt/modules/production-environments"
}

inputs = {
  repositories = [
    for repository_name, repository in local.repository_data.repositories :
    repository_name if try(repository.production_environment, false)
  ]
  reviewers = local.repository_data.production_reviewers
}
