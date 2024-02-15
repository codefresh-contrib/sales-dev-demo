# Create Codefresh Config

resource "docker_container" "cf_create_context" {
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
              "temp",
              "--api-key",
              var.cf_api_token
            ]
  attach = "true"
  must_run = "false"
}

# Create Codefresh ISC Repository

resource "github_repository" "codefresh-demo-isc" {
  name        = "codefresh-demo-isc"
  description = "Codefresh Shared Configuration Repository"

  visibility = "private"
  depends_on = [
    docker_container.cf_create_context
  ]
}

# Add Codefresh ISC Repository

resource "docker_container" "cf_configure_isc" {
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
              "--shared-config-repo",
              github_repository.codefresh-demo-isc.http_clone_url
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    github_repository.codefresh-demo-isc
  ]
}

# Add GitOps GIT Integration

resource "docker_container" "cf_add_git_integration" {
  name  = "cf_add_git_integration"
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
              "integration",
              "git",
              "add",
              "default",
              "--api-url",
              "https://api.github.com",
              "--runtime",
              module.eks.cluster_name
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    helm_release.gitops-runtime
  ]
}

# Register GitOps GIT Integration

resource "docker_container" "cf_register_git_integration" {
  name  = "cf_register_git_integration"
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
              "integration",
              "git",
              "register",
              "default",
              "--runtime",
              module.eks.cluster_name,
              "--token",
              var.github_api_token
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    docker_container.cf_add_git_integration
  ]
}

# Copy Demo App Repository to GitHub

resource "github_repository" "codefresh-demo-app" {
  name        = "codefresh-demo-app"
  description = "Codefresh Demo App Repository"

  visibility = "public"

  template {
    owner                = "codefresh-contrib"
    repository           = "example-voting-app"
  }
  depends_on = [
    docker_container.cf_register_git_integration
  ]
}

# Update Application Manifests

data "github_repository_file" "eva_development_app_manifest_temp" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-development.yaml"
}

data "github_repository_file" "eva_staging_app_manifest_temp" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-staging.yaml"
}

data "github_repository_file" "eva_production_app_manifest" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-production.yaml"
}

data "dataprocessor_yq" "development" {
  input_data = data.github_repository_file.eva_development_app_manifest_temp.content
  expression = ".spec.source.repoURL = \"${github_repository.codefresh-demo-app.http_clone_url}\""
}

data "dataprocessor_yq" "staging" {
  input_data = data.github_repository_file.eva_staging_app_manifest_temp.content
  expression = ".spec.source.repoURL = \"${github_repository.codefresh-demo-app.http_clone_url}\""
}

data "dataprocessor_yq" "production" {
  input_data = data.github_repository_file.eva_production_app_manifest.content
  expression = ".spec.source.repoURL = \"${github_repository.codefresh-demo-app.http_clone_url}\""
}

resource "github_repository_file" "eva_development_app_manifest" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-development.yaml"
  content             = data.dataprocessor_yq.development.result
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

resource "github_repository_file" "eva_staging_app_manifest" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-staging.yaml"
  content             = data.dataprocessor_yq.staging.result
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}
resource "github_repository_file" "eva_production_app_manifest" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-production.yaml"
  content             = data.dataprocessor_yq.production.result
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

# Add Demo App Repository as GitOps Git-Source

resource "docker_container" "cf_create_git_source" {
  name  = "cf_create_git_source"
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
              "git-source",
              "create",
              module.eks.cluster_name,
              "codefresh-demo-apps",
              "--git-src-git-token",
              var.github_api_token,
              "--git-src-repo",
              "${github_repository.codefresh-demo-app.http_clone_url}/argocd/applications"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    github_repository.codefresh-demo-app
  ]
}

# TODO: Future Codefresh Terraform Provider Work

# TODO: Create Docker Registry Integration (No Terraform) < --- done
  # TODO: Add Project Creation
  # TODO: Create Codefresh Pipeline in Terraform for GitOps CD Initialization
  # TODO: Codefresh run initialization pipeline to build all stable images to begin their life cycle

# TODO: Create Storage Integration
  # TODO: Convert GitOps Promotion Pipeline into Terraform Code
  # TODO: Convert Codefresh EVA Pipelines into Terraform Code

# TODO: Update example-voting-app to nginx ingress (will take a rewrite of application code to support without subdomain configuration)
  # TODO: Add Route53 Automation for DNS Records
  # TODO: Automate DNS configuration
  # TODO: Move to demo app to Argo Rollouts
