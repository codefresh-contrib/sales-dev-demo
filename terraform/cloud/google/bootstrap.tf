resource "google_service_account" "demo" {
  account_id   = "${var.gke_cluster_name}"
  project      = "${var.google_project_id}"
  display_name = "Codefresh Demo Service Account"
}

resource "google_container_cluster" "demo" {
  name     = "${var.gke_cluster_name}"
  location = "${var.google_location}"
  deletion_protection = false

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "demo" {
  name       = "${var.gke_cluster_name}"
  location   = "${var.google_location}"
  cluster    = google_container_cluster.demo.name
  node_count = var.gke_worker_node_count

  node_config {
    preemptible  = true
    machine_type = var.gke_worker_machine_type

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.demo.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_artifact_registry_repository" "demo" {
  location      = "${var.google_location}"
  repository_id = "${google_container_cluster.demo.name}"
  description   = "codefresh demo docker repository"
  format        = "DOCKER"
}

# Create Codefresh Config

resource "docker_container" "cf_create_context" {
  count = var.create_isc ? 1 : 0
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
              google_container_cluster.demo.name,
              "--api-key",
              var.cf_api_token
            ]
  attach = "true"
  must_run = "false"
}

# Create Codefresh ISC Repository in GitHub

resource "github_repository" "codefresh-demo-isc" {
  count = var.github_isc ? 1 : 0
  name        = "${google_container_cluster.demo.name}-isc"
  description = "Codefresh Shared Configuration Repository"

  visibility = "private"
  depends_on = [
    docker_container.cf_create_context
  ]
}

# Create Codefresh ISC Repository in Gitlab

resource "gitlab_project" "codefresh-demo-isc" {
  count = var.gitlab_isc ? 1 : 0
  name        = "${google_container_cluster.demo.name}-isc"
  description = "Codefresh Shared Configuration Repository"

  default_branch = "main"
  initialize_with_readme = true
  visibility_level = "private"
  depends_on = [
    docker_container.cf_create_context
  ]
}
# Get Version Control Information

locals {
  repo_clone_url = try(github_repository.codefresh-demo-isc[0].http_clone_url, gitlab_project.codefresh-demo-isc[0].http_url_to_repo, null)
  vcs_api_token = try(var.github_api_token, var.gitlab_api_token)
  provider = var.github_isc ? "github" : "gitlab"
}

# Add Codefresh ISC Repository

resource "docker_container" "cf_configure_isc" {
  count = var.create_isc ? 1 : 0
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
              "--silent",
              "--git-provider",
              "${local.provider}",
              "--shared-config-repo",
              "${local.repo_clone_url}"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    github_repository.codefresh-demo-isc
  ]
}

# Create NGINX Controller

resource "helm_release" "nginx-ingress" {
  name       = "nginx-ingress"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  namespace  = "kube-system"

  depends_on = [
    google_container_node_pool.demo
  ]
}

# Create GitOps Runtime

resource "helm_release" "gitops-runtime" {
  name       = "${var.gitops_runtime_name}"
  repository = "https://chartmuseum.codefresh.io/gitops-runtime"
  chart      = "gitops-runtime"
  namespace  = "${var.gitops_runtime_namespace}"
  create_namespace = "true"

  values = [
    file("${path.module}/gitops-runtime-values.yaml")
  ]

  set {
    name  = "global.codefresh.accountId"
    value = var.cf_account_id
  }

  set_sensitive {
    name  = "global.codefresh.userToken.token"
    value = var.cf_api_token
  }

  set {
    name  = "global.runtime.name"
    value = google_container_cluster.demo.name
  }

  depends_on = [
    google_container_node_pool.demo
  ]
}

# Create Codefresh Runtime

resource "helm_release" "cf-runtime" {
  name       = "${var.cf_runtime_name}"
  repository = "https://chartmuseum.codefresh.io/cf-runtime"
  chart      = "cf-runtime"
  namespace  = "${var.cf_runtime_namespace}"
  create_namespace = "true"

  values = [
    file("${path.module}/cf-runtime-values.yaml")
  ]

  set_sensitive {
    name  = "global.codefreshToken"
    value = var.cf_api_token
  }

  set {
    name  = "global.runtimeName"
    value = google_container_cluster.demo.name
  }

  set {
    name  = "global.context"
    value = google_container_cluster.demo.name
  }

  set {
    name  = "global.agentName"
    value = google_container_cluster.demo.name
  }

  set {
    name = "installer.skipValidation"
    value = "true"
  }

  depends_on = [
    google_container_node_pool.demo
  ]
}
