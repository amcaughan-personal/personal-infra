variable "repo" {
  description = "Repo name in the amcaughan-personal org."
  type        = string
}

variable "oidc_subject_prefix" {
  description = "The repo part of GitHub's OIDC subject claim: `gh api repos/<org>/<repo>/actions/oidc/customization/sub` shows it as sub_claim_prefix."
  type        = string
}

variable "github_environment" {
  description = "The GitHub environment whose jobs may assume the role. It should allow only the main branch."
  type        = string
}

variable "purpose" {
  description = "One word for the role's job, e.g. deploy or dashboard: the role is github-ci-<purpose>-<repo>-<environment>."
  type        = string
}

variable "description" {
  description = "What the role is for, for its IAM description."
  type        = string
}

variable "statements" {
  description = "The role's permissions."
  type = list(object({
    sid       = string
    actions   = list(string)
    resources = list(string)
  }))
}

variable "role_arn_name" {
  description = "Name the role's ARN is published under, e.g. DEPLOY_ROLE_ARN."
  type        = string
}

variable "published_values" {
  description = "Other values the workflow reads, published next to the role ARN."
  type        = map(string)
  default     = {}
}

variable "oidc_provider_arn" {
  type = string
}

variable "provider_url" {
  type    = string
  default = "https://token.actions.githubusercontent.com"
}
