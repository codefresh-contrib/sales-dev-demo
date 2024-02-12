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
  description = "A prefix used for all resources in this example"
}

variable "azure_vm_size" {
  type        = string
  default     = "Standard_DS3_v2"
  description = "A prefix used for all resources in this example"
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

variable "github_api_token" {
  type    = string
  default = ""
  #sensitive = true
  description = "GitHub API Token"
}

variable "github_owner" {
  type    = string
  default = ""
  description = "GitHub Owner (Personal Account or Organization)"
}
