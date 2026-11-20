# A `production` environment per repository: deploys only from main, and only after a
# reviewer approves. AWS roles for deploying trust only jobs in this environment
# (OIDC subject `repo:<org>/<repo>:environment:production`), so the approval can't be
# skipped by editing a workflow.

data "github_user" "reviewer" {
  for_each = toset(var.reviewers)
  username = each.value
}

resource "github_repository_environment" "production" {
  for_each = var.repositories

  repository  = each.value
  environment = "production"

  # Admins can't skip the approval; a solo maintainer approves their own deploys.
  can_admins_bypass   = false
  prevent_self_review = false

  reviewers {
    users = [for user in data.github_user.reviewer : user.id]
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "deploy_branch" {
  for_each = var.repositories

  repository     = each.value
  environment    = github_repository_environment.production[each.value].environment
  branch_pattern = var.deploy_branch
}
