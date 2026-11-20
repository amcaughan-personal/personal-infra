include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  repository_data = yamldecode(file("${get_parent_terragrunt_dir("root")}/data/repositories.yaml"))

  protected_main_repositories = {
    for repository_name, repository in local.repository_data.repositories :
    repository_name => {}
    if contains(try(repository.rulesets, []), "protected_main")
  }
}

terraform {
  source = "${get_repo_root()}/infra/github/terragrunt/modules/protected-main-rulesets"
}

inputs = {
  repositories = local.protected_main_repositories
}
