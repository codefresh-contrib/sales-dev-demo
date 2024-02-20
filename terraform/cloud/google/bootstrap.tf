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
  repository_id = "${var.gke_cluster_name}"
  description   = "codefresh demo docker repository"
  format        = "DOCKER"
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
