include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  app_data = yamldecode(file("${get_parent_terragrunt_dir("root")}/data/apps.yaml"))

  apps = {
    platform_sync = {
      installation_id       = try(local.app_data.apps.platform_sync.installation.id, null)
      selected_repositories = try(local.app_data.apps.platform_sync.installation.selected_repositories, [])
    }
  }
}

terraform {
  source = "${get_repo_root()}/infra/github/terragrunt/modules/github-app-installation-repositories"
}

inputs = {
  apps = local.apps
}
