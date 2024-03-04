# Demo Application Data

output "demo_app_repository" {
  value = github_repository.codefresh-demo-app.http_clone_url
}
