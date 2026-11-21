terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.7"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
