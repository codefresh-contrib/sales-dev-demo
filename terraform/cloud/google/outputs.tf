# Required outputs for initialization of GitOps Demo Application

# Codefresh Runtime Name

output "codefresh_runtime" {
  value = helm_release.cf-runtime.name
}

# Azure Container Registry Name

output "google_artifact_registry" {
  value = google_artifact_registry_repository.demo.name
}
