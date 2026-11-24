# Shared by every stack under repos/ (<repo>/ci-roles/plan, <repo>/ci-roles/apply, ...). Each stack picks
# its module and adds its repo's name and OIDC subject prefix.

dependency "github_oidc" {
  config_path = "${get_repo_root()}/infra/aws/terragrunt/live/identity/github-oidc"

  mock_outputs = {
    provider_arn = "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
    provider_url = "https://token.actions.githubusercontent.com"
  }

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  oidc_provider_arn = dependency.github_oidc.outputs.provider_arn
  provider_url      = dependency.github_oidc.outputs.provider_url
  state_bucket      = "amcaughan-tf-state-us-east-2"

  shared_ssm_parameter_paths = [
    "/services/*", # service URLs, e.g. the API's, read by the ELT
  ]
}
