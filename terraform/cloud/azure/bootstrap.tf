resource "azurerm_resource_group" "demo" {
  name     = "${var.azure_prefix}-rg"
  location = var.azure_location
}

resource "azurerm_container_registry" "demo" {
  name                = "${replace(var.azure_prefix, "-", "")}"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  sku                 = "Premium"
}

resource "azurerm_kubernetes_cluster" "demo" {
  name                = "${var.azure_prefix}-k8s"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  dns_prefix          = "${var.azure_prefix}-k8s"

  default_node_pool {
    name       = "default"
    node_count = var.azure_node_count
    vm_size    = "${var.azure_vm_size}"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "${var.azure_prefix}"
  }
}

# Create Codefresh Config

resource "docker_container" "cf_create_context" {
  count = var.create_isc ? 1 : 0
  name  = "cf_create_context"
  image = "quay.io/codefresh/cli-v2:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "cf",
              "config",
              "create-context",
              azurerm_kubernetes_cluster.demo.name,
              "--api-key",
              var.cf_api_token
            ]
  attach = "true"
  must_run = "false"
}

# Create Codefresh ISC Repository in GitHub

resource "github_repository" "codefresh-demo-isc" {
  count = var.github_isc ? 1 : 0
  name        = "${azurerm_kubernetes_cluster.demo.name}-isc"
  description = "Codefresh Shared Configuration Repository"

  visibility = "private"
  depends_on = [
    docker_container.cf_create_context
  ]
}

# Create Codefresh ISC Repository in Gitlab

resource "gitlab_project" "codefresh-demo-isc" {
  count = var.gitlab_isc ? 1 : 0
  name        = "${azurerm_kubernetes_cluster.demo.name}-isc"
  description = "Codefresh Shared Configuration Repository"

  default_branch = "main"
  initialize_with_readme = true
  visibility_level = "private"
  depends_on = [
    docker_container.cf_create_context
  ]
}
# Get Version Control Information

locals {
  repo_clone_url = try(github_repository.codefresh-demo-isc[0].http_clone_url, gitlab_project.codefresh-demo-isc[0].http_url_to_repo, null)
  vcs_api_token = try(var.github_api_token, var.gitlab_api_token)
  provider = var.github_isc ? "github" : "gitlab"
}

# Add Codefresh ISC Repository

resource "docker_container" "cf_configure_isc" {
  count = var.create_isc ? 1 : 0
  name  = "cf_configure_isc"
  image = "quay.io/codefresh/cli-v2:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "cf",
              "config",
              "update-gitops-settings",
              "--silent",
              "--git-provider",
              "${local.provider}",
              "--shared-config-repo",
              "${local.repo_clone_url}"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    github_repository.codefresh-demo-isc
  ]
}


# Create NGINX Controller

resource "helm_release" "nginx-ingress" {
  name       = "nginx-ingress"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  namespace  = "kube-system"

  depends_on = [
    azurerm_kubernetes_cluster.demo
  ]
}

# Create GitOps Runtime

resource "helm_release" "gitops-runtime" {
  name       = "${var.gitops_runtime_name}"
  repository = "https://chartmuseum.codefresh.io/gitops-runtime"
  chart      = "gitops-runtime"
  namespace  = "${var.gitops_runtime_namespace}"
  create_namespace = "true"

  values = [
    file("${path.module}/gitops-runtime-values.yaml")
  ]

  set {
    name  = "global.codefresh.accountId"
    value = var.cf_account_id
  }

  set_sensitive {
    name  = "global.codefresh.userToken.token"
    value = var.cf_api_token
  }

  set {
    name  = "global.runtime.name"
    value = azurerm_kubernetes_cluster.demo.name
  }

  depends_on = [
    azurerm_kubernetes_cluster.demo
  ]
}

# Create Codefresh Runtime

resource "helm_release" "cf-runtime" {
  name       = "${var.cf_runtime_name}"
  repository = "https://chartmuseum.codefresh.io/cf-runtime"
  chart      = "cf-runtime"
  namespace  = "${var.cf_runtime_namespace}"
  create_namespace = "true"

  values = [
    file("${path.module}/cf-runtime-values.yaml")
  ]

  set_sensitive {
    name  = "global.codefreshToken"
    value = var.cf_api_token
  }

  set {
    name  = "global.runtimeName"
    value = azurerm_kubernetes_cluster.demo.name
  }

  set {
    name  = "global.context"
    value = azurerm_kubernetes_cluster.demo.name
  }

  set {
    name  = "global.agentName"
    value = azurerm_kubernetes_cluster.demo.name
  }

  set {
    name = "installer.skipValidation"
    value = "true"
  }

  depends_on = [
    azurerm_kubernetes_cluster.demo
  ]
}
