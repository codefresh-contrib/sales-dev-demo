terraform {
  required_providers {
    # TODO: Add Codefresh
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.15.0"
    }
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
    helm = {
      source = "hashicorp/helm"
      version = "2.11.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
}

provider "codefresh" {
  api_key = var.cf_api_token
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

provider "github" {
  token = var.github_api_token
  owner = var.github_owner
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "--region", var.aws_region, "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}
