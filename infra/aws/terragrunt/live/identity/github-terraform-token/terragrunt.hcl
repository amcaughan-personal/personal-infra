include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt/modules/manual-secret"
}

inputs = {
  # Read by infra/github/terragrunt/root.hcl when running the GitHub stack.
  name        = "/personal_infra/github-terraform-token"
  description = "Fine-grained GitHub token for the GitHub Terraform stack (amcaughan-personal: repository administration, environments, issues, variables)"
}
