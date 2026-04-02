locals {
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
