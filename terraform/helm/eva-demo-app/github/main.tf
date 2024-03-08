terraform {
  required_providers {
    dataprocessor = {
      source = "slok/dataprocessor"
    }
    codefresh = {
      source = "codefresh-io/codefresh"
      version = "0.8.0"
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
