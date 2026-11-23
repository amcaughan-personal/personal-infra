variable "repo" {
  description = "Repo name in the amcaughan-personal org."
  type        = string
}

variable "oidc_subject_prefix" {
  description = "The repo part of GitHub's OIDC subject claim: `gh api repos/<org>/<repo>/actions/oidc/customization/sub` shows it as sub_claim_prefix."
  type        = string
}

variable "github_environment" {
  description = "The GitHub environment whose jobs may deploy. It should allow only the main branch."
  type        = string
}

variable "function_name" {
  description = "The Lambda function to deploy to (created by the repo's own stacks)."
  type        = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "provider_url" {
  type    = string
  default = "https://token.actions.githubusercontent.com"
}
