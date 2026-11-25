variable "repo" {
  description = "Repo name in the amcaughan-personal org."
  type        = string
}

variable "oidc_subject_prefix" {
  description = "The repo part of GitHub's OIDC subject claim: `gh api repos/<org>/<repo>/actions/oidc/customization/sub` shows it as sub_claim_prefix."
  type        = string
}

variable "github_environment" {
  description = "The GitHub environment whose jobs may assume the role (unless var.trusted is set), and the role name's suffix. It should allow only the main branch. Null for a role used outside one environment."
  type        = string
  default     = null
}

variable "trusted" {
  description = "Who may assume the role, if not just var.github_environment's jobs: each entry is an environment, or a branch (ref), optionally pinned to one workflow file in the repo (e.g. cluster-down.yml)."
  type = list(object({
    environment = optional(string)
    ref         = optional(string, "refs/heads/main")
    workflow    = optional(string)
  }))
  default = null
}

variable "github_owner" {
  description = "The GitHub organization, for workflow file references."
  type        = string
  default     = "amcaughan-personal"
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
    # e.g. a tag condition, for resources whose ARNs don't carry a name to scope by
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
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

variable "read_access" {
  description = "Also read every resource's configuration (not data contents), like the plan roles."
  type        = bool
  default     = false
}

variable "state_write_prefixes" {
  description = "Paths under the repo's Terraform state prefix the role may write, e.g. live/clusters/."
  type        = list(string)
  default     = []
}

variable "state_bucket" {
  description = "Terraform state bucket (with read_access or state_write_prefixes)."
  type        = string
  default     = null
}

variable "shared_ssm_parameter_paths" {
  description = "SSM parameter paths readable besides the repo's own (with read_access)."
  type        = list(string)
  default     = []
}
