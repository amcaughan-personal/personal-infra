locals {
  repositories = {
    data-simulator-api = {
      class = "service"

      protected_main = {}
    }

    data-simulator-elt = {
      class = "data-platform"

      protected_main = {}
    }

    personal_infra = {
      class = "control-plane"

      protected_main = {}
    }

    shared_workflows = {
      class = "shared-automation"

      protected_main = {}
    }
  }
}
