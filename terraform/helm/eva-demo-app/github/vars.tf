#### Codefresh Configuration

variable "runtime_name" {
  type = string
  default = "gitops_runtime"
  description = "Codefresh GitOps Runtime Name"
}

#### Docker Configuration

variable "docker_host" {
  type    = string
  default = "unix:///var/run/docker.sock"
  description = "Docker deamon host.  Default is for MacOS, for Windows use npipe:////.//pipe//docker_engine"
}

#### GitHub Configuration

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
