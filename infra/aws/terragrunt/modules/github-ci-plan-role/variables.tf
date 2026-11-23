variable "repo" {
  description = "Repo name in the amcaughan-personal org. Also its Terraform state prefix and its /github/<repo>/ SSM path."
  type        = string
}

variable "oidc_subject_prefix" {
  description = "The repo part of GitHub's OIDC subject claim: `gh api repos/<org>/<repo>/actions/oidc/customization/sub` shows it as sub_claim_prefix."
  type        = string
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
  description = "SSM parameter paths the plan may read besides the repo's own, e.g. \"/services/*\"."
  type        = list(string)
  default     = []
}
