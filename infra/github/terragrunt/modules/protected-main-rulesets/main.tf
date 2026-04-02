locals {
  repositories = {
    for name, repository in var.repositories :
    name => {
      ruleset_name                      = repository.ruleset_name
      enforcement                       = repository.enforcement
      include_refs                      = repository.include_refs
      required_approving_review_count   = repository.required_approving_review_count
      require_last_push_approval        = repository.require_last_push_approval
      require_code_owner_review         = repository.require_code_owner_review
      required_review_thread_resolution = repository.required_review_thread_resolution
      allowed_merge_methods             = repository.allowed_merge_methods
      required_linear_history           = repository.required_linear_history
      required_signatures               = repository.required_signatures
      block_branch_deletion             = repository.block_branch_deletion
      block_force_pushes                = repository.block_force_pushes
      bypass_actors                     = repository.bypass_actors
    }
  }
}

resource "github_repository_ruleset" "protected_main" {
  for_each = local.repositories

  name        = each.value.ruleset_name
  repository  = each.key
  target      = "branch"
  enforcement = each.value.enforcement

  conditions {
    ref_name {
      include = each.value.include_refs
      exclude = []
    }
  }

  rules {
    deletion                = each.value.block_branch_deletion
    non_fast_forward        = each.value.block_force_pushes
    required_linear_history = each.value.required_linear_history
    required_signatures     = each.value.required_signatures

    pull_request {
      allowed_merge_methods             = each.value.allowed_merge_methods
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = each.value.require_code_owner_review
      require_last_push_approval        = each.value.require_last_push_approval
      required_approving_review_count   = each.value.required_approving_review_count
      required_review_thread_resolution = each.value.required_review_thread_resolution
    }
  }

  dynamic "bypass_actors" {
    for_each = each.value.bypass_actors

    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }
}
