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