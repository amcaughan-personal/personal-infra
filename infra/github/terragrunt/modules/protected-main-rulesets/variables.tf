variable "repositories" {
  description = "Managed repositories and any per-repo overrides for the protected-main ruleset."

  type = map(object({
    ruleset_name                      = optional(string, "Protected Main")
    enforcement                       = optional(string, "active")
    include_refs                      = optional(list(string), ["~DEFAULT_BRANCH"])
    required_approving_review_count   = optional(number, 0)
    require_last_push_approval        = optional(bool, false)
    require_code_owner_review         = optional(bool, false)
    required_review_thread_resolution = optional(bool, true)
    allowed_merge_methods             = optional(list(string), ["squash", "rebase"])
    required_linear_history           = optional(bool, true)
    required_signatures               = optional(bool, false)
    block_branch_deletion             = optional(bool, true)
    block_force_pushes                = optional(bool, true)
    bypass_actors = optional(list(object({
      actor_id    = number
      actor_type  = string
      bypass_mode = string
      })), [{
      actor_id    = 5
      actor_type  = "RepositoryRole"
      bypass_mode = "pull_request"
    }])
  }))

  validation {
    condition = alltrue([
      for repository in values(var.repositories) :
      contains(["disabled", "active", "evaluate"], repository.enforcement)
    ])
    error_message = "Ruleset enforcement must be one of disabled, active, or evaluate."
  }
}
