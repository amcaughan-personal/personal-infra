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
# Environment variables published by other repos: an SSM parameter at
# /github/<repo>/<environment>/<NAME> becomes the variable <NAME> in that repo's
# environment, so workflows read vars.<NAME> instead of hard-coding values. Parameters
# for environments not managed here are ignored. These are not secrets (URLs, role ARNs),
# so they're unmarked from the provider's blanket "sensitive".
# --------------------------------------------------------------------------------------

data "aws_ssm_parameters_by_path" "published" {
  path      = "/github/"
  recursive = true
}

locals {
  published = zipmap(
    [for name in data.aws_ssm_parameters_by_path.published.names : trimprefix(name, "/github/")],
    nonsensitive(data.aws_ssm_parameters_by_path.published.values),
  )

  environment_variables = {
    for path, value in local.published : path => {
      environment = join("/", slice(split("/", path), 0, 2))
      name        = split("/", path)[2]
      value       = value
    }
    if length(split("/", path)) == 3 && contains(keys(local.environments), join("/", slice(split("/", path), 0, 2)))
  }
}

resource "github_actions_environment_variable" "published" {
  for_each = local.environment_variables

  repository    = github_repository_environment.this[each.value.environment].repository
  environment   = github_repository_environment.this[each.value.environment].environment
  variable_name = each.value.name
  value         = each.value.value
}
