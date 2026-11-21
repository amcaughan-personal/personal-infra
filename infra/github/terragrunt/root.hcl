# Tool versions are set once, in the repo's .tool-versions (also read by the dev image and
# CI). Running with any other version stops here instead of drifting.
terraform_version_constraint  = "= ${local.tool_versions.terraform}"
terragrunt_version_constraint = "= ${local.tool_versions.terragrunt}"

locals {
  tool_versions = {
    for line in split("\n", file("${get_repo_root()}/.tool-versions")) :
    split(" ", trimspace(line))[0] => split(" ", trimspace(line))[1]
    if length(regexall("^[a-z]", trimspace(line))) > 0
  }

  aws_region   = "us-east-2"
  github_owner = "amcaughan-personal"
}

remote_state {
  backend = "s3"

  config = {
    bucket       = "amcaughan-tf-state-us-east-2"
    key          = "personal_infra/github/${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

# The GitHub provider authenticates as the org's GitHub App (amcaughan-personal-terraform:
# repository administration, environments, issues and variables), which issues short-lived
# tokens. Its App and installation IDs aren't secret; its private key is kept in SSM and
# stored by hand (see live/identity/github-app-private-key in the AWS tree). Everything is
# passed to Terraform as environment variables, so the key never lands in generated files,
# state or output.
terraform {
  extra_arguments "github_app" {
    commands = ["init", "plan", "apply", "destroy", "import", "refresh", "state", "show", "output", "console"]
    env_vars = {
      GITHUB_APP_ID              = "5857621"
      GITHUB_APP_INSTALLATION_ID = "184228691"
      GITHUB_APP_PEM_FILE = run_cmd(
        "--terragrunt-quiet", "aws", "ssm", "get-parameter", "--region", local.aws_region,
        "--name", "/personal-infra/github-app-private-key", "--with-decryption",
        "--query", "Parameter.Value", "--output", "text",
      )
    }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
variable "github_owner" {
  type    = string
  default = "${local.github_owner}"
}

provider "github" {
  owner = var.github_owner

  # Credentials come from the GITHUB_APP_* environment variables set above.
  app_auth {}
}

# Reads values other repos publish for their workflows (see modules/repositories).
provider "aws" {
  region = "${local.aws_region}"
}
EOF
}

generate "backend_stub" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
terraform {
  backend "s3" {}
}
EOF
}
