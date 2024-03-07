# Copy Demo App Repository to Gitlab

resource "gitlab_project" "codefresh-demo-app" {
  name       = "${var.runtime_name}-demo-app"
  description = "Codefresh Demo App Repository"

  visibility_level = "public"

  import_url = "https://gitlab.com/codefresh-contrib/example-voting-app.git"
}

# Update Application Manifests

data "gitlab_repository_file" "eva_development_app_manifest_temp" {
  project        = gitlab_project.codefresh-demo-app.id
  file_path      = "argocd/applications/helm-eva-development.yaml"
  ref            = "main"

  depends_on = [
    gitlab_project.codefresh-demo-app
  ]  
}

data "gitlab_repository_file" "eva_staging_app_manifest_temp" {
  project        = gitlab_project.codefresh-demo-app.id
  file_path      = "argocd/applications/helm-eva-staging.yaml"
  ref            = "main"

  depends_on = [
    gitlab_project.codefresh-demo-app
  ]  
}

data "gitlab_repository_file" "eva_production_app_manifest_temp" {
  project        = gitlab_project.codefresh-demo-app.id
  file_path      = "argocd/applications/helm-eva-production.yaml"
  ref            = "main"

  depends_on = [
    gitlab_project.codefresh-demo-app
  ]  
}

data "dataprocessor_yq" "development" {
  input_data = data.gitlab_repository_file.eva_development_app_manifest_temp.content
  expression = ".spec.source.repoURL = \"${gitlab_project.codefresh-demo-app.http_url_to_repo}\""

  depends_on = [
    data.gitlab_repository_file.eva_development_app_manifest_temp
  ]
}

data "dataprocessor_yq" "staging" {
  input_data = data.gitlab_repository_file.eva_staging_app_manifest_temp.content
  expression = ".spec.source.repoURL = \"${gitlab_project.codefresh-demo-app.http_url_to_repo}\""

  depends_on = [
    data.gitlab_repository_file.eva_staging_app_manifest_temp
  ]
}

data "dataprocessor_yq" "production" {
  input_data = data.gitlab_repository_file.eva_production_app_manifest_temp.content
  expression = ".spec.source.repoURL = \"${gitlab_project.codefresh-demo-app.http_url_to_repo}\""

  depends_on = [
    data.gitlab_repository_file.eva_production_app_manifest_temp
  ]
}

resource "gitlab_repository_file" "eva_development_app_manifest" {
  project             = gitlab_project.codefresh-demo-app.id
  branch              = "main"
  file_path           = "argocd/applications/helm-eva-development.yaml"
  content             = data.dataprocessor_yq.development.result
  commit_message      = "Managed by Terraform"
  author_name       = "Terraform User"
  author_email        = "terraform@example.com"
  overwrite_on_create = true

  depends_on = [
    data.dataprocessor_yq.development
  ]
}

resource "gitlab_repository_file" "eva_staging_app_manifest" {
  project             = gitlab_project.codefresh-demo-app.id
  branch              = "main"
  file_path           = "argocd/applications/helm-eva-staging.yaml"
  content             = data.dataprocessor_yq.staging.result
  commit_message      = "Managed by Terraform"
  author_name       = "Terraform User"
  author_email        = "terraform@example.com"
  overwrite_on_create = true

  depends_on = [
    data.dataprocessor_yq.staging
  ]
}

resource "gitlab_repository_file" "eva_production_app_manifest" {
  project             = gitlab_project.codefresh-demo-app.id
  branch              = "main"
  file_path           = "argocd/applications/helm-eva-production.yaml"
  content             = data.dataprocessor_yq.production.result
  commit_message      = "Managed by Terraform"
  author_name       = "Terraform User"
  author_email        = "terraform@example.com"
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
              var.gitlab_api_token
            ]
  attach = "true"
  must_run = "false"
  depends_on = [
    gitlab_project.codefresh-demo-app
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
              var.gitlab_api_token,
              "--git-src-repo",
              "${gitlab_project.codefresh-demo-app.http_url_to_repo}/argocd/applications"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    docker_container.cf_register_git_integration
  ]
}
