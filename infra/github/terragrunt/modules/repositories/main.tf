# Everything managed about each repository: its settings, the Protected Main ruleset and
# its deployment environments.
# config/repositories.yaml lists the repositories and what each one gets.

locals {
  # Repository admins (role id 5) can bypass main's protection, but only through a PR.
  admin_role_id = 5

  protected_main = { for name, repo in var.repositories : name => repo if repo.protected_main }
  releases       = { for name, repo in var.repositories : name => repo if repo.releases }

  # A merged PR with one of these labels bumps that part of the version; otherwise patch.
  release_labels = {
    "release: minor" = { color = "0e8a16", description = "Merging tags a new minor version (new, backwards-compatible inputs or behaviour)" }
    "release: major" = { color = "b60205", description = "Merging tags a new major version (breaking change for callers)" }
  }
  release_label_pairs = merge([
    for repo in keys(local.releases) : {
      for label, settings in local.release_labels : "${repo}/${label}" => merge(settings, { repository = repo, name = label })
    }
  ]...)
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
  allow_update_branch         = true # the "Update branch" button, for the up-to-date rule
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

  # Pages sites are built and deployed by the repo's own workflow (GitHub Actions); this
  # only turns Pages on.
  dynamic "pages" {
    for_each = each.value.pages ? [1] : []
    content {
      build_type = "workflow"
    }
  }

  lifecycle {
    prevent_destroy = true
    # auto_init and template only matter when a repo is created.
    ignore_changes = [auto_init, template]
  }
}

# Dependabot opens PRs that fix dependencies with security alerts (on top of its version
# update PRs, configured in each repo's .github/dependabot.yml).
resource "github_repository_dependabot_security_updates" "this" {
  for_each = var.repositories

  repository = github_repository.this[each.key].name
  enabled    = each.value.vulnerability_alerts && each.value.dependabot_security_updates
}

# Actions may run only when pinned to a full commit SHA, so a moved tag can't change what
# runs. Set per repo because the GitHub App manages repositories, not the org's settings.
resource "github_actions_repository_permissions" "this" {
  for_each = var.repositories

  repository           = github_repository.this[each.key].name
  enabled              = true
  allowed_actions      = "all"
  sha_pinning_required = each.value.actions_sha_pinning_required
}

# --------------------------------------------------------------------------------------
# Protected Main: every change goes through a PR, and the repo's required checks pass
# --------------------------------------------------------------------------------------

resource "github_repository_ruleset" "protected_main" {
  for_each = local.protected_main

  name        = "Protected Main"
  repository  = github_repository.this[each.key].name
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
        # A PR must include the latest main before merging, so its checks (including the
        # Terraform plan comment) ran against what will actually land.
        strict_required_status_checks_policy = true
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
# Releases: protected v* tags and the labels that pick the next version
# --------------------------------------------------------------------------------------

resource "github_repository_ruleset" "release_tags" {
  for_each = local.releases

  name        = "Release Tags"
  repository  = github_repository.this[each.key].name
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*"]
      exclude = []
    }
  }

  # New tags can be created; existing ones can't be moved or deleted (admins can, to repair).
  rules {
    deletion = true
    update   = true
  }

  bypass_actors {
    actor_id    = local.admin_role_id
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }
}

resource "github_issue_label" "release" {
  for_each = local.release_label_pairs

  repository  = github_repository.this[each.value.repository].name
  name        = each.value.name
  color       = each.value.color
  description = each.value.description
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

  repository  = github_repository.this[each.value.repository].name
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

  repository     = github_repository.this[each.value.repository].name
  environment    = github_repository_environment.this[each.key].environment
  branch_pattern = "main"
}

# --------------------------------------------------------------------------------------
# Values published by other repos: an SSM parameter at /github/<repo>/<NAME> becomes
# <NAME> in that repo's Actions settings, and one at /github/<repo>/<environment>/<NAME> in
# that environment, so workflows read them instead of hard-coding values. Parameters for
# repos or environments not managed here are ignored.
#
# Values that contain the AWS account ID (role ARNs, ECR URLs) become secrets, which
# GitHub masks in public logs (secrets.<NAME>). The rest become variables (vars.<NAME>).
# None are secret in themselves, so they're unmarked from the provider's blanket
# "sensitive".
# --------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_ssm_parameters_by_path" "published" {
  path      = "/github/"
  recursive = true
}

locals {
  published = {
    for name, value in zipmap(
      data.aws_ssm_parameters_by_path.published.names,
      nonsensitive(data.aws_ssm_parameters_by_path.published.values),
    ) :
    trimprefix(name, "/github/") => {
      parts   = split("/", trimprefix(name, "/github/"))
      value   = value
      private = strcontains(value, data.aws_caller_identity.current.account_id)
    }
  }

  # /github/<repo>/<NAME>
  repo_values = {
    for path, p in local.published : path => {
      repository = p.parts[0]
      name       = p.parts[1]
      value      = p.value
      private    = p.private
    }
    if length(p.parts) == 2 && contains(keys(var.repositories), p.parts[0])
  }

  # /github/<repo>/<environment>/<NAME>
  environment_values = {
    for path, p in local.published : path => {
      environment = join("/", slice(p.parts, 0, 2))
      name        = p.parts[2]
      value       = p.value
      private     = p.private
    }
    if length(p.parts) == 3 && contains(keys(local.environments), join("/", slice(p.parts, 0, 2)))
  }
}

resource "github_actions_variable" "published" {
  for_each = { for path, v in local.repo_values : path => v if !v.private }

  repository    = github_repository.this[each.value.repository].name
  variable_name = each.value.name
  value         = each.value.value
}

resource "github_actions_secret" "published" {
  #checkov:skip=CKV_GIT_4:Values come from SSM, not code, and aren't secret in themselves; they're secrets so GitHub masks the account ID in logs
  for_each = { for path, v in local.repo_values : path => v if v.private }

  repository      = github_repository.this[each.value.repository].name
  secret_name     = each.value.name
  plaintext_value = each.value.value
}

resource "github_actions_environment_variable" "published" {
  for_each = { for path, v in local.environment_values : path => v if !v.private }

  repository    = github_repository_environment.this[each.value.environment].repository
  environment   = github_repository_environment.this[each.value.environment].environment
  variable_name = each.value.name
  value         = each.value.value
}

resource "github_actions_environment_secret" "published" {
  #checkov:skip=CKV_GIT_4:Values come from SSM, not code, and aren't secret in themselves; they're secrets so GitHub masks the account ID in logs
  for_each = { for path, v in local.environment_values : path => v if v.private }

  repository      = github_repository_environment.this[each.value.environment].repository
  environment     = github_repository_environment.this[each.value.environment].environment
  secret_name     = each.value.name
  plaintext_value = each.value.value
}
