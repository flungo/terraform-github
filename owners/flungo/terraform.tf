terraform {
  cloud {
    organization = "flungo"
    workspaces {
      name    = "github-flungo"
      project = "terraform-github"
    }
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.9"
}
