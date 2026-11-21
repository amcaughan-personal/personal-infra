variable "name" {
  description = "SSM parameter name, e.g. /personal-infra/github-app-private-key."
  type        = string
}

variable "description" {
  type = string
}
