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

#### Gitlab Configuration

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
