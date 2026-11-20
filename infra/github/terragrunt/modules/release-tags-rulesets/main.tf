locals {
  repositories = {
    for name, repository in var.repositories :
    name => {
      ruleset_name         = repository.ruleset_name
      enforcement          = repository.enforcement
      include_refs         = repository.include_refs
      restrict_tag_updates = repository.restrict_tag_updates
      block_tag_deletion   = repository.block_tag_deletion
      required_signatures  = repository.required_signatures
      bypass_actors        = repository.bypass_actors
    }
  }
}

resource "github_repository_ruleset" "release_tags" {
  for_each = local.repositories

  name        = each.value.ruleset_name
  repository  = each.key
  target      = "tag"
  enforcement = each.value.enforcement

  conditions {
    ref_name {
      include = each.value.include_refs
      exclude = []
    }
  }

  rules {
    deletion            = each.value.block_tag_deletion
    required_signatures = each.value.required_signatures
    update              = each.value.restrict_tag_updates
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
