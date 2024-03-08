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

# Authenticate with Codefresh CLI

resource "docker_container" "codefresh_create_auth" {
  name  = "codefresh_create_auth"
  image = "quay.io/codefresh/cli:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "codefresh",
              "auth",
              "create-context",
              var.runtime_name,
              "--api-key",
              var.cf_api_token
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    docker_container.cf_register_git_integration
  ]
}

# Add Pipelines GIT Integration

resource "docker_container" "codefresh_create_git_context" {
  name  = "codefresh_create_git_context"
  image = "quay.io/codefresh/cli:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "codefresh",
              "create",
              "context",
              "git",
              "github",
              var.github_owner,
              "--sharing-policy",
              "AllUsersInAccount",
              "--access-token",
              var.github_api_token
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    docker_container.codefresh_create_auth
  ]
}

# Create Demo App Project

resource "codefresh_project" "create_demo_app_project" {
  name = "Initialize Codefresh Demo App Project"

  tags = [
    "demo"
  ]

  depends_on = [
    docker_container.cf_create_git_source
  ]
}

# Create Demo App Initialization Pipeline

resource "codefresh_pipeline" "create_demo_app_initialization_pipeline" {
  name = "${codefresh_project.create_demo_app_project.name}/demo-app-initialization"

  tags = [
    "demo",
    "initialization"
  ]

  spec {
    spec_template {
	  repo        = "${var.github_owner}/${github_repository.codefresh-demo-app.name}"
      path        = "./.codefresh/initialization/initialize-demo-app.yaml"
      revision    = "main"
      context     = "${var.github_owner}"
    }

    variables = {
      RESULT_DOCKER_REGISTRY = var.registry_result
      TEST_DOCKER_REGISTRY = var.registry_tests
      VOTE_DOCKER_REGISTRY = var.registry_vote
      WORKER_DOCKER_REGISTRY = var.registry_worker
      GITOPS_RUNTIME_NAME = var.runtime_name
    }

    trigger {
      name                = "${github_repository.codefresh-demo-app.name}-initialize"
      type                = "git"
      repo                = "${var.github_owner}/${github_repository.codefresh-demo-app.name}"
      events              = ["push.heads"]
      pull_request_allow_fork_events = false
      comment_regex       = "/.*/gi"
      branch_regex        = "/.*/gi"
      branch_regex_input  = "regex"
      provider            = "github"
      disabled            = true
      options {
        no_cache        = false
        no_cf_cache     = false
        reset_volume    = false
      }
      context             = "${var.github_owner}"
      contexts            = []
    }

    runtime_environment {
      name                = var.runtime_name
      cpu                 = "1000m"
      memory              = "2048Mi"
    }

  }
  depends_on = [
    codefresh_project.create_demo_app_project
  ]
}

# Run Demo App Initialization Pipeline

resource "docker_container" "codefesh_run_demo_app_initializaton_pipeline" {
  name  = "codefesh_run_demo_app_initializaton_pipeline"
  image = "quay.io/codefresh/cli:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "codefresh",
              "run",
              codefresh_pipeline.create_demo_app_initialization_pipeline.id,
              "--trigger",
              "${github_repository.codefresh-demo-app.name}-initialize",
              "--branch",
              "main"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    codefresh_pipeline.create_demo_app_initialization_pipeline,
    docker_container.codefresh_create_git_context
  ]
}
