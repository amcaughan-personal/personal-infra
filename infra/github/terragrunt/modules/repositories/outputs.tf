output "protected_main_ruleset_ids" {
  value = { for repository, ruleset in github_repository_ruleset.protected_main : repository => ruleset.id }
}

output "environments" {
  value = keys(github_repository_environment.this)
}
