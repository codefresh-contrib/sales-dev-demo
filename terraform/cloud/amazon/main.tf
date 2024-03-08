terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    codefresh = {
      source = "codefresh-io/codefresh"
      version = "0.8.0"
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

provider "aws" {
  region     = var.aws_region
}

provider "codefresh" {
  token = var.cf_api_token
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
  kubernetes {
    host                   = data.aws_eks_cluster.demo.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.demo.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
      command     = "aws"
    }  
  }
}
