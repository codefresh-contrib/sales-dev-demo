# Required outputs for initialization of GitOps Demo Application

# Codefresh Runtime Name

output "codefresh_runtime" {
  value = helm_release.cf-runtime.name
}

# Azure Container Registry Name

output "azure_container_registry" {
  value = azurerm_container_registry.demo.name
}
