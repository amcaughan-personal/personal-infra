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
