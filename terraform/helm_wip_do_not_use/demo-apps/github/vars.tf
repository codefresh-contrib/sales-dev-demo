#### Codefresh Configuration

variable "cf_account_id" {
  type    = string
  default = ""
  sensitive = true
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
  sensitive = true
  description = "Codefresh access token. Create it from the Codefresh UI"
}
# Documentation: https://codefresh.io/docs/docs/integrations/codefresh-api/#authentication-instructions

variable "cf_runtime_name" {
  type = string
  default = "cf-runtime"
  description = "Codefresh Runtime name"
}

variable "gitops_runtime_name" {
  type = string
  default = "gitops-runtime"
  description = "GitOps Runtime name"
}

variable "github_api_token" {
  type    = string
  default = ""
  sensitive = true
  description = "GitHub API Token"
}

variable "github_owner" {
  type    = string
  default = ""
  description = "GitHub Owner (Personal Account or Organization)"
}