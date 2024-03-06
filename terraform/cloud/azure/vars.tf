#### Azure Configuration

variable "azure_location" {
  type        = string
  description = "The Azure Region in which all resources in this example should be provisioned"
}

variable "azure_subscription" {
  type        = string
  description = "The Azure Subscription ID to deploy to"
}

variable "azure_prefix" {
  type        = string
  description = "A prefix used for all resources in this example"
}

variable "azure_node_count" {
  type        = number
  default     = 1
  description = "Number of Azure Kubernetes Worker Nodes"
}

variable "azure_vm_size" {
  type        = string
  default     = "Standard_DS3_v2"
  description = "VM Size of Azure Kubernetes Worker Nodes"
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
  default = ""
  #sensitive = true
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

variable "cf_runtime_az" {
  type = string
  default = "us-east-1f"
  description = "Codefresh Runtime installation namespace"
}

variable "cf_runtime_version" {
  type = string
  default = "6.3.14"
  description = "Codefresh Runtime version"
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

variable "gitops_runtime_version" {
  type = string
  default = "0.4.6"
  description = "GitOps Runtime version"
}

#### ISC Configuration, requires GitHub or Gitlab

variable "create_isc" {
  type    = string
  default = false
  description = "Creates Codefresh Internal Shared Configuration Repository"
}

variable "docker_host" {
  type    = string
  default = "unix:///var/run/docker.sock"
  description = "Docker deamon host.  Default is for MacOS, for Windows use npipe:////.//pipe//docker_engine"
}

#### GitHub Configuration

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

variable "github_base_url" {
  type    = string
  default = "https://api.github.com/"
  description = "This is the target GitHub base API endpoint, if creating ISC.  Requires a trailing slash."
}

variable "github_owner" {
  type    = string
  default = null
  description = "GitHub Owner (Personal Account or Organization), if creating ISC"
}

variable "create_github_demo_app" {
  type    = string
  default = false
  description = "Creates demo app in GitHub"
}

#### Gitlab Configuration

variable "gitlab_isc" {
  type    = string
  default = false
  description = "Selects Gitlab for ISC"
}

variable "gitlab_api_token" {
  type    = string
  sensitive = true
  default = "glpat-"
  description = "Gitlab API Token, if creating ISC"
}

variable "gitlab_base_url" {
  type    = string
  default = "https://gitlab.com/"
  description = "This is the target GitLab base API endpoint, if creating ISC.  Requires a trailing slash."
}

variable "create_gitlab_demo_app" {
  type    = string
  default = false
  description = "Creates demo app in Gitlab"
}
