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
