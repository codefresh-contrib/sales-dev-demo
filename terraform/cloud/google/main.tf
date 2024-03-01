terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 5.0"
    }
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
    gitlab = {
      source = "gitlabhq/gitlab"
      version = "16.9.1"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.12.1"
    }
  }
}

provider "google" {
  project     = var.google_project_id
  region      = var.google_location
}

data "google_client_config" "current" {}

provider "docker" {
  host = var.docker_host
}

provider "gitlab" {
  token = var.gitlab_api_token
  base_url = var.gitlab_base_url
  early_auth_check = false
}

provider "github" {
  token = var.github_api_token
  base_url = var.github_base_url
  owner = var.github_owner
}

provider "helm" {
  # https://registry.terraform.io/providers/hashicorp/helm/latest/docs
  kubernetes {
    host                   = "${google_container_cluster.demo.endpoint}"
    token                  = "${data.google_client_config.current.access_token}"

    client_certificate     = "${base64decode(google_container_cluster.demo.master_auth.0.client_certificate)}"
    client_key             = "${base64decode(google_container_cluster.demo.master_auth.0.client_key)}"
    cluster_ca_certificate = "${base64decode(google_container_cluster.demo.master_auth.0.cluster_ca_certificate)}"
  }
}