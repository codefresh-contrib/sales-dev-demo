# Copy Demo App Repository to GitHub

resource "github_repository" "codefresh-demo-app" {
  name        = "${var.runtime_name}-demo-app"
  description = "Codefresh Demo App Repository"

  visibility = "public"

  template {
    owner                = "codefresh-contrib"
    repository           = "example-voting-app"
  }
}

# Update Application Manifests

data "github_repository_file" "eva_development_app_manifest_temp" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-development.yaml"

  depends_on = [
    github_repository.codefresh-demo-app
  ]
}

data "github_repository_file" "eva_staging_app_manifest_temp" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-staging.yaml"

  depends_on = [
    github_repository.codefresh-demo-app
  ]
}

data "github_repository_file" "eva_production_app_manifest" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-production.yaml"

  depends_on = [
    github_repository.codefresh-demo-app
  ]
}

data "dataprocessor_yq" "development" {
  input_data = data.github_repository_file.eva_development_app_manifest_temp.content
  expression = ".spec.source.repoURL = \"${github_repository.codefresh-demo-app.http_clone_url}\""

  depends_on = [
    data.github_repository_file.eva_development_app_manifest_temp
  ]
}

data "dataprocessor_yq" "staging" {
  input_data = data.github_repository_file.eva_staging_app_manifest_temp.content
  expression = ".spec.source.repoURL = \"${github_repository.codefresh-demo-app.http_clone_url}\""

  depends_on = [
    data.github_repository_file.eva_staging_app_manifest_temp
  ]
}

data "dataprocessor_yq" "production" {
  input_data = data.github_repository_file.eva_production_app_manifest.content
  expression = ".spec.source.repoURL = \"${github_repository.codefresh-demo-app.http_clone_url}\""

  depends_on = [
    data.github_repository_file.eva_production_app_manifest
  ]
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

  depends_on = [
    data.dataprocessor_yq.development
  ]
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

  depends_on = [
    data.dataprocessor_yq.staging
  ]
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

  depends_on = [
    data.dataprocessor_yq.production
  ]
}

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
              var.runtime_name,
              "--token",
              var.github_api_token
            ]
  attach = "true"
  must_run = "false"
  depends_on = [
    github_repository.codefresh-demo-app
  ]
}

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
              var.runtime_name,
              "codefresh-demo-apps",
              "--git-src-git-token",
              var.github_api_token,
              "--git-src-repo",
              "${github_repository.codefresh-demo-app.http_clone_url}/argocd/applications"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    docker_container.cf_register_git_integration
  ]
}
