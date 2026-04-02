locals {
  installed_apps = {
    for app_name, app in var.apps :
    app_name => {
      installation_id       = app.installation_id
      selected_repositories = app.selected_repositories
    }
    if try(app.installation_id, null) != null && length(try(app.selected_repositories, [])) > 0
  }
}

resource "github_app_installation_repositories" "selected" {
  for_each = local.installed_apps

  installation_id       = each.value.installation_id
  selected_repositories = each.value.selected_repositories
}
