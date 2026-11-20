output "environments" {
  value = { for repository, environment in github_repository_environment.production : repository => environment.environment }
}
