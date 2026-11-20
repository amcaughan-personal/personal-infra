# Everything managed about each repository: its rulesets and production environment.
# config/repositories.yaml lists the repositories and what each one gets.

locals {
  # Repository admins (role id 5) can bypass: through a PR on main, directly on tags for repairs.
  admin_role_id = 5

  protected_main = { for name, repo in var.repositories : name => repo if contains(repo.rulesets, "protected_main") }
  release_tags   = { for name, repo in var.repositories : name => repo if contains(repo.rulesets, "release_tags") }
  production     = { for name, repo in var.repositories : name => repo if repo.production_environment }
}

# --------------------------------------------------------------------------------------
# The repository itself. Repos were created by hand and imported. Terraform never deletes
# one: destroy is blocked, and removing one from the config would archive it.
# --------------------------------------------------------------------------------------

resource "github_repository" "this" {
  #checkov:skip=CKV_GIT_1:Public on purpose: these repos are a public portfolio
  #checkov:skip=CKV2_GIT_1:Main is protected by the Protected Main ruleset below; Checkov only recognises classic branch protection
  for_each = var.repositories

  name         = each.key
  description  = each.value.description
  homepage_url = each.value.homepage_url
  topics       = each.value.topics
  visibility   = "public"

  has_issues      = each.value.has_issues
  has_projects    = each.value.has_projects
  has_wiki        = each.value.has_wiki
  has_discussions = false

  allow_merge_commit          = each.value.allow_merge_commit
  allow_squash_merge          = true
  allow_rebase_merge          = true
  allow_auto_merge            = false
  allow_update_branch         = false
  delete_branch_on_merge      = each.value.delete_branch_on_merge
  squash_merge_commit_title   = "COMMIT_OR_PR_TITLE"
  squash_merge_commit_message = "COMMIT_MESSAGES"

  vulnerability_alerts = each.value.vulnerability_alerts

  security_and_analysis {
    secret_scanning {
      status = each.value.secret_scanning ? "enabled" : "disabled"
    }
    secret_scanning_push_protection {
      status = each.value.secret_scanning_push_protection ? "enabled" : "disabled"
    }
  }

  archive_on_destroy = true

  lifecycle {
    prevent_destroy = true
    # GitHub Pages is configured by each repo's own workflow, not here.
    ignore_changes = [pages]
  }
}

# --------------------------------------------------------------------------------------
# Protected Main: every change goes through a PR, and the repo's required checks pass
# --------------------------------------------------------------------------------------

resource "github_repository_ruleset" "protected_main" {
  for_each = local.protected_main

  name        = "Protected Main"
  repository  = each.key
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true
    required_signatures     = false

    dynamic "required_status_checks" {
      for_each = length(each.value.required_checks) > 0 ? [1] : []
      content {
        strict_required_status_checks_policy = false
        dynamic "required_check" {
          for_each = each.value.required_checks
          content {
            context        = required_check.value
            integration_id = 15368 # GitHub Actions, so no other app can report these checks
          }
        }
      }
    }

    pull_request {
      allowed_merge_methods             = ["squash", "rebase"]
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = 0 # solo org: a PR, but no approval
      required_review_thread_resolution = true
    }
  }

  bypass_actors {
    actor_id    = local.admin_role_id
    actor_type  = "RepositoryRole"
    bypass_mode = "pull_request"
  }
}

# --------------------------------------------------------------------------------------
# Release Tags: v* tags can be created but not moved or deleted
# --------------------------------------------------------------------------------------

resource "github_repository_ruleset" "release_tags" {
  for_each = local.release_tags

  name        = "Release Tags"
  repository  = each.key
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*"]
      exclude = []
    }
  }

  rules {
    deletion            = true
    required_signatures = false
    update              = true
  }

  bypass_actors {
    actor_id    = local.admin_role_id
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }
}

# --------------------------------------------------------------------------------------
# Production environment: deploys from main only, after a reviewer approves. AWS deploy
# roles trust only jobs in this environment (OIDC subject
# repo:<org>/<repo>:environment:production), so the approval can't be skipped.
# Remove every reviewer to deploy without approval (pure CI/CD); main-only still applies.
# --------------------------------------------------------------------------------------

data "github_user" "reviewer" {
  for_each = toset(var.production_reviewers)
  username = each.value
}

resource "github_repository_environment" "production" {
  for_each = local.production

  repository  = each.key
  environment = "production"

  can_admins_bypass   = false
  prevent_self_review = false # a solo maintainer approves their own deploys

  dynamic "reviewers" {
    for_each = length(var.production_reviewers) > 0 ? [1] : []
    content {
      users = [for user in data.github_user.reviewer : user.id]
    }
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "deploy_branch" {
  for_each = local.production

  repository     = each.key
  environment    = github_repository_environment.production[each.key].environment
  branch_pattern = "main"
}
