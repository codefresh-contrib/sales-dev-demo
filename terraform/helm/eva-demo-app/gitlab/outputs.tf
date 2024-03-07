# Demo Application Data

output "demo_app_repository" {
  value = gitlab_project.codefresh-demo-app.http_url_to_repo
}
