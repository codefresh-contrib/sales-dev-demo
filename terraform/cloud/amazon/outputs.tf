# Required outputs for initialization of GitOps Demo Application

# Codefresh Runtime Name

output "codefresh_runtime" {
  value = helm_release.cf-runtime.name
}

# Elastic Container Registry Names

output "ecr_registry_result" {
  value = aws_ecr_repository.result.name
}

output "ecr_registry_tests" {
  value = aws_ecr_repository.test.name
}

output "ecr_registry_vote" {
  value = aws_ecr_repository.vote.name
}

output "ecr_registry_worker" {
  value = aws_ecr_repository.worker.name
}

output "isc_repository" {
  value = local.repo_clone_url

  depends_on = [
    docker_container.cf_configure_isc
  ]
}

output "github_demo_app_repository" {
  value = var.create_github_demo_app ? module.create_github_demo_app[0].demo_app_repository : null
}

output "gitlab_demo_app_repository" {
  value = var.create_gitlab_demo_app ? module.create_gitlab_demo_app[0].demo_app_repository : null
}
