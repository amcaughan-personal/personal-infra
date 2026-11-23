variable "repo" {
  description = "Repo name in the amcaughan-personal org. Also its Terraform state prefix and its /github/<repo>/ SSM path."
  type        = string
}

variable "state_bucket" {
  description = "Terraform state bucket. The repo's state lives under the <repo>/ prefix."
  type        = string
}

variable "shared_ssm_parameter_paths" {
  description = "SSM parameter paths the role may read besides the repo's own, e.g. \"/services/*\"."
  type        = list(string)
  default     = []
}
