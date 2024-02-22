#### Google Configuration

variable "google_location" {
  type        = string
  description = "The Google Region in which all resources in this example should be provisioned"
}

variable "google_project_id" {
  type        = string
  description = "Google Project ID"
}

variable "gke_cluster_name" {
  type        = string
  description = "Google Kubernetes Cluster Name"
}

variable "gke_worker_node_count" {
  type        = number
  default     = 1
  description = "Number of Google Kubernetes Worker Nodes"
}

variable "gke_worker_machine_type" {
  type        = string
  default     = "n1-standard-4"
  description = "VM Size of Google Kubernetes Worker Nodes"
}

# Documentation: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs

#### Codefresh Configuration

variable "cf_account_id" {
  type    = string
  default = ""
  #sensitive = true
  description = "Codefresh Account ID"
}
# Available at: https://g.codefresh.io/2.0/account-settings/account-information

variable "cf_api_host" {
  type = string
  default = "http://g.codefresh.io/api"
  description = "Codefresh URL access. SAAS is at http://g.codefresh.io/api"
}
# Only required to be changed for self hosted control plane.

variable "cf_api_token" {
  type    = string
  description = "Codefresh access token. Create it from the Codefresh UI"
}
# Documentation: https://codefresh.io/docs/docs/integrations/codefresh-api/#authentication-instructions

variable "cf_runtime_name" {
  type = string
  default = "cf-runtime"
  description = "Codefresh Runtime name"
}

variable "cf_runtime_namespace" {
  type = string
  default = "cf-runtime"
  description = "Codefresh Runtime installation namespace"
}

variable "gitops_runtime_name" {
  type = string
  default = "gitops-runtime"
  description = "GitOps Runtime name"
}

variable "gitops_runtime_namespace" {
  type = string
  default = "gitops-runtime"
  description = "GitOps Runtime installation namespace"
}

#### GitHub Configuration

variable "create_isc" {
  type    = string
  default = false
  description = "Creates Codefresh Internal Shared Configuration Repository"
}

variable "github_isc" {
  type    = string
  default = false
  description = "Selects GitHub for ISC"
}

variable "github_api_token" {
  type    = string
  sensitive = true
  default = null
  description = "GitHub API Token, if creating ISC"
}

variable "github_owner" {
  type    = string
  default = null
  description = "GitHub Owner (Personal Account or Organization), if creating ISC"
}
