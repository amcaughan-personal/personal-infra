output "ruleset_ids" {
  description = "Repository ruleset IDs keyed by repository name."

  value = {
    for repository, ruleset in github_repository_ruleset.release_tags :
    repository => ruleset.id
  }
}
