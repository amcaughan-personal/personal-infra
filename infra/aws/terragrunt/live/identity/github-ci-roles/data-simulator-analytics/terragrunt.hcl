include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path           = find_in_parent_folders("common.hcl")
  merge_strategy = "deep"
}

inputs = {
  repo = "data-simulator-analytics"

  # GitHub's immutable OIDC subject: org and repo by name and numeric ID, so a repo
  # deleted and recreated under the same name doesn't match.
  oidc_subject_prefix = "repo:amcaughan-personal@271645414/data-simulator-analytics@1466249789"
}
