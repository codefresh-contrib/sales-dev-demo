terraform {
  required_providers {
    dataprocessor = {
      source = "slok/dataprocessor"
    }
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
    gitlab = {
      source = "gitlabhq/gitlab"
      version = "16.9.1"
    }
  }
}
