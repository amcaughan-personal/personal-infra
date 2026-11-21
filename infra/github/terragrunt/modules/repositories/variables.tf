variable "repositories" {
  description = "Managed repositories, from config/repositories.yaml."

  type = map(object({
    protected_main  = optional(bool, true)       # PRs required on main (the Protected Main ruleset)
    required_checks = optional(list(string), []) # must pass before merging to main
    # Versioned with automatic tags: every merge to main is tagged v<major>.<minor>.<patch>
    # (by the repo's own workflow). Adds the release labels that choose a bigger bump, and
    # protects v* tags from being moved or deleted.
    releases = optional(bool, false)
    # Deployment environments, e.g. { staging = {}, production = { approval = true } }.
    # All deploy only from main; approval = true also needs a reviewer to approve.
    environments = optional(map(object({
      approval = optional(bool, false)
    })), {})

    pages = optional(bool, false) # publish GitHub Pages, built by the repo's own workflow

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

variable "deploy_reviewers" {
  description = "GitHub users who approve deploys to environments with approval = true."
  type        = list(string)
}
