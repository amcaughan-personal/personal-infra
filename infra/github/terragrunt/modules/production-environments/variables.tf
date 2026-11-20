variable "repositories" {
  description = "Repositories that get a production environment."
  type        = set(string)
}

variable "reviewers" {
  description = "GitHub users who can approve production deploys."
  type        = list(string)
}

variable "deploy_branch" {
  description = "The only branch that can deploy to production."
  type        = string
  default     = "main"
}
