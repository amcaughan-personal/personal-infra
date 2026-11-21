include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt/modules/manual-secret"
}

inputs = {
  # Read by infra/github/terragrunt/root.hcl when running the GitHub stack.
  name        = "/personal-infra/github-app-private-key"
  description = "Private key (PEM) of the GitHub App the GitHub Terraform stack authenticates as"
}
