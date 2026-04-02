include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  repository_catalog = read_terragrunt_config(find_in_parent_folders("catalog/repositories.hcl"))

  protected_main_repositories = {
    for repository_name, repository in local.repository_catalog.locals.repositories :
    repository_name => try(repository.protected_main, {})
    if try(repository.protected_main, null) != null
  }
}

terraform {
  source = "${get_repo_root()}/infra/github/terragrunt/modules/protected-main-rulesets"
}

inputs = {
  repositories = local.protected_main_repositories
}
