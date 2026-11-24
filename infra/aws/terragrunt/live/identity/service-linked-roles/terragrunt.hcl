include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/aws/terragrunt/modules/service-linked-roles"
}

inputs = {
  services = [
    # EC2 Spot: without it, spot requests (e.g. eks-platform's Karpenter nodes) fail and
    # fall back to on-demand.
    "spot.amazonaws.com",
  ]
}
