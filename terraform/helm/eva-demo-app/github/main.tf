terraform {
  required_providers {
    dataprocessor = {
      source = "slok/dataprocessor"
    }
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}
