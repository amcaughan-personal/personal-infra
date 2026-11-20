# Everything managed about each repository: its settings, the Protected Main ruleset and
# its deployment environments.
# config/repositories.yaml lists the repositories and what each one gets.

locals {
  # Repository admins (role id 5) can bypass main's protection, but only through a PR.
  admin_role_id = 5

  protected_main = { for name, repo in var.repositories : name => repo if repo.protected_main }
  environments = merge([
    for name, repo in var.repositories : {
      for environment, settings in repo.environments :
      "${name}/${environment}" => { repository = name, environment = environment, approval = settings.approval }
    }
  ]...)
}

# --------------------------------------------------------------------------------------
# The repository itself. A new entry creates the repo: from a template if given, otherwise
# with an initial commit so main exists. Terraform never deletes one: destroy is blocked,
# and removing an entry would archive the repo.
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
  is_template  = each.value.is_template

  auto_init = each.value.template == null

  dynamic "template" {
    for_each = each.value.template == null ? [] : [each.value.template]
    content {
      owner      = var.github_owner
      repository = template.value
    }
  }

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
    # Pages is configured by each repo's own workflow. auto_init and template only
    # matter when a repo is created.
    ignore_changes = [pages, auto_init, template]
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
# Deployment environments: deploy only from main; those with approval = true also wait for
# a reviewer. A repo's AWS deploy roles trust only jobs in their environment (OIDC subject
# repo:<org>/<repo>:environment:<name>), so neither rule can be skipped by editing a
# workflow. Set approval = false (or remove every reviewer) for pure CI/CD.
# --------------------------------------------------------------------------------------

data "github_user" "reviewer" {
  for_each = toset(var.deploy_reviewers)
  username = each.value
}

resource "github_repository_environment" "this" {
  for_each = local.environments

  repository  = each.value.repository
  environment = each.value.environment

  can_admins_bypass   = false
  prevent_self_review = false # a solo maintainer approves their own deploys

  dynamic "reviewers" {
    for_each = each.value.approval && length(var.deploy_reviewers) > 0 ? [1] : []
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
  for_each = local.environments

  repository     = each.value.repository
  environment    = github_repository_environment.this[each.key].environment
  branch_pattern = "main"
}
