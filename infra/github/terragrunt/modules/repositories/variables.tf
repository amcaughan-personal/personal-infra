variable "repositories" {
  description = "Managed repositories, from config/repositories.yaml."

  type = map(object({
    protected_main         = optional(bool, true)       # PRs required on main (the Protected Main ruleset)
    required_checks        = optional(list(string), []) # must pass before merging to main
    production_environment = optional(bool, false)      # deploys from main, after approval

    template     = optional(string)      # create from this template repo in the org (new repos only)
    is_template  = optional(bool, false) # this repo is a template others can be created from
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

}

variable "production_reviewers" {
  description = "GitHub users who can approve production deploys."
  type        = list(string)
}
