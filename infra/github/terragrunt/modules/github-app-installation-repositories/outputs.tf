output "managed_installations" {
  description = "GitHub App installation IDs keyed by app name."

  value = {
    for app_name, installation in github_app_installation_repositories.selected :
    app_name => installation.installation_id
  }
}
