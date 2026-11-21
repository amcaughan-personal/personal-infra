variable "name" {
  description = "SSM parameter name, e.g. /personal_infra/github-terraform-token."
  type        = string
}

variable "description" {
  type = string
}
