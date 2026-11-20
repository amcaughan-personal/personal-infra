variable "role_name" {
  type = string
}

variable "role_description" {
  type    = string
  default = null
}

variable "oidc_provider_arn" {
  type = string
}

variable "provider_url" {
  type    = string
  default = "https://token.actions.githubusercontent.com"
}

variable "allowed_subjects" {
  type = list(string)
}

variable "allowed_audiences" {
  type    = list(string)
  default = ["sts.amazonaws.com"]
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "inline_policy_jsons" {
  type    = map(string)
  default = {}
}

variable "max_session_duration" {
  type    = number
  default = 3600
}

variable "deny_data_reads" {
  description = "Attach an explicit-deny inline policy that blocks reading data contents (S3 objects, stream/queue/table records, log events, query results, image layers, secrets, KMS decrypt) while leaving configuration reads intact. Intended for plan-only roles that carry ReadOnlyAccess."
  type        = bool
  default     = false
}

variable "data_read_allowed_s3_object_arns" {
  description = "S3 object ARNs exempt from the data-read deny, e.g. the role's own Terraform state prefix."
  type        = list(string)
  default     = []
}

variable "data_read_allowed_ssm_parameter_paths" {
  description = "SSM parameter path patterns (e.g. \"/network/*\") the role may still read when deny_data_reads is on. Everything else is denied."
  type        = list(string)
  default     = []
}
