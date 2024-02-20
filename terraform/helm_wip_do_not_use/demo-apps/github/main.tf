terraform {
  required_providers {
    codefresh = {
      source = "codefresh-io/codefresh"
      version = "0.6.0-beta-1"
    }
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
    dataprocessor = {
      source = "slok/dataprocessor"
    }
  }
}

provider "codefresh" {
  token = var.cf_api_token
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

provider "github" {
  token = var.github_api_token
  owner = var.github_owner
}
