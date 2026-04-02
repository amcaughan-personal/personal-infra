variable "repositories" {
  description = "Managed repositories and any per-repo overrides for the release-tags ruleset."

  type = map(object({
    ruleset_name         = optional(string, "Release Tags")
    enforcement          = optional(string, "active")
    include_refs         = optional(list(string), ["v*"])
    restrict_tag_updates = optional(bool, true)
    block_tag_deletion   = optional(bool, true)
    required_signatures  = optional(bool, false)
    bypass_actors = optional(list(object({
      actor_id    = number
      actor_type  = string
      bypass_mode = string
    })), [{
      actor_id    = 5
      actor_type  = "RepositoryRole"
      bypass_mode = "always"
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
