terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.90.0"
    }
    dataprocessor = {
      source = "slok/dataprocessor"
      version = "0.4.0"
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

provider "azurerm" {
  subscription_id = var.azure_subscription
  # The AzureRM Provider supports authenticating using via the Azure CLI, a Managed Identity
  # and a Service Principal. More information on the authentication methods supported by
  # the AzureRM Provider can be found here:
  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure

  # The features block allows changing the behaviour of the Azure Provider, more
  # information can be found here:
  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/features-block
  features {}
}

provider "docker" {
  host = var.docker_host
}

provider "github" {
  token = var.github_api_token
  base_url = var.github_base_url
  owner = var.github_owner
}

provider "gitlab" {
  token = var.gitlab_api_token
  base_url = var.gitlab_base_url
  early_auth_check = false
}

provider "helm" {
  # https://registry.terraform.io/providers/hashicorp/helm/latest/docs
  kubernetes {
    host                   = azurerm_kubernetes_cluster.demo.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.demo.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.demo.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.demo.kube_config.0.cluster_ca_certificate)
  }
}
