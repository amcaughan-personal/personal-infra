variable "repositories" {
  description = "Managed repositories, from config/repositories.yaml."

  type = map(object({
    rulesets               = optional(list(string), []) # "protected_main", "release_tags"
    required_checks        = optional(list(string), []) # must pass before merging to main
    production_environment = optional(bool, false)      # deploys from main, after approval

    description  = optional(string, "")
    homepage_url = optional(string, "")
    topics       = optional(list(string), [])

    # Settings: the defaults are the org standard; override only with a reason.
    has_issues                      = optional(bool, true)
    has_projects                    = optional(bool, false)
    has_wiki                        = optional(bool, false) # docs live in each repo
    allow_merge_commit              = optional(bool, false) # squash or rebase keeps history linear
    delete_branch_on_merge          = optional(bool, true)
    vulnerability_alerts            = optional(bool, true)
    secret_scanning                 = optional(bool, true) # free for public repos
    secret_scanning_push_protection = optional(bool, true)
  }))

  validation {
    condition = alltrue(flatten([
      for repository in values(var.repositories) :
      [for ruleset in repository.rulesets : contains(["protected_main", "release_tags"], ruleset)]
    ]))
    error_message = "rulesets can contain protected_main and release_tags."
  }
}

variable "production_reviewers" {
  description = "GitHub users who can approve production deploys."
  type        = list(string)
}
