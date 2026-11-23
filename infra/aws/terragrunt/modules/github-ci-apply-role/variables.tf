variable "repo" {
  description = "Repo name in the amcaughan-personal org. Also its Terraform state prefix and its /github/<repo>/ SSM path."
  type        = string
}

variable "oidc_subject_prefix" {
  description = "The repo part of GitHub's OIDC subject claim: `gh api repos/<org>/<repo>/actions/oidc/customization/sub` shows it as sub_claim_prefix."
  type        = string
}

variable "github_environments" {
  description = "GitHub environments whose jobs may assume the role. Each should allow only the main branch."
  type        = list(string)
}

variable "oidc_provider_arn" {
  type = string
}

variable "provider_url" {
  type    = string
  default = "https://token.actions.githubusercontent.com"
}

variable "state_bucket" {
  description = "Terraform state bucket. The repo's state lives under the <repo>/ prefix."
  type        = string
}

variable "shared_ssm_parameter_paths" {
  description = "SSM parameter paths the role may read besides the repo's own, e.g. \"/network/*\"."
  type        = list(string)
  default     = []
}

variable "resource_prefix" {
  description = "Name prefix of the repo's resources and IAM roles (default: the repo name)."
  type        = string
  default     = null
}

variable "manage_statements" {
  description = "What the role may do to the repo's resources besides IAM roles: create and change, no deletes. Scope resources to the name prefix."
  type = list(object({
    sid       = string
    actions   = list(string)
    resources = list(string)
  }))
}

variable "boundary_statements" {
  description = "The permissions boundary: the most any role the repo creates may do."
  type = list(object({
    sid       = string
    actions   = list(string)
    resources = list(string)
  }))
}

variable "pass_role_services" {
  description = "Services the repo's roles may be passed to, e.g. lambda.amazonaws.com."
  type        = list(string)
}
