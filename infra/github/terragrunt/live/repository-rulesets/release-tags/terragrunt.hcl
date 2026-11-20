include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  repository_data = yamldecode(file("${get_parent_terragrunt_dir("root")}/data/repositories.yaml"))

  release_tag_repositories = {
    for repository_name, repository in local.repository_data.repositories :
    repository_name => {}
    if contains(try(repository.rulesets, []), "release_tags")
  }
}

terraform {
  source = "${get_repo_root()}/infra/github/terragrunt/modules/release-tags-rulesets"
}

inputs = {
  repositories = local.release_tag_repositories
}
