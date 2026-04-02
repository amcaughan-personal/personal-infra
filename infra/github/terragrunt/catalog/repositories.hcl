locals {
  repositories = {
    data-simulator-api = {
      class = "service"
    }

    data-simulator-elt = {
      class = "data-platform"
    }

    personal_infra = {
      class = "control-plane"

      # Roll out the protected-main ruleset here first, then fan out to the
      # rest of the managed repos once the behavior feels right.
      protected_main = {}
    }

    shared_workflows = {
      class = "shared-automation"
    }
  }
}
