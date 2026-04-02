variable "apps" {
  description = "GitHub App installations and their selected repositories."

  type = map(object({
    installation_id       = optional(number)
    selected_repositories = optional(list(string), [])
  }))
}
