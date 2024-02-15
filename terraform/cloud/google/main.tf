terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 5.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.11.0"
    }
  }
}

provider "google" {
  project     = var.google_project_id
  region      = var.google_location
}

data "google_client_config" "current" {}

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