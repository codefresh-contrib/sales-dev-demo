# This repository is experimental.  Please be careful using this repository at this time.

We are focusing on quick starts (sandboxes) to get Codfresh Runtimes installed and a simple GitOps Demo application configured in you Codefresh account.

## This project is meant to...

1. Create the necessary infrastructure in your cloud for Codefresh.
1. Configure Version Control w/ Codefresh
1. Install Codefresh Runtime
1. Install GitOps Runtime
1. Install NGINX

# Future
1. Install a Demo GitOps Application via ArgoCD

### Clouds

#### Amazon
./clouds/amazon
Codefresh Runner (CI) has EBS optimized caching

#### Azure
./clouds/azure
Codefresh Runner (CI) has no caching (Coming soon)

### Google
./clouds/google
Codefresh Runner (CI) has no caching (Coming soon)

### Version Control

#### GitHub
To configure Version Control for GitOps Runtime you will need a Personal Access Token and define the following:

- In your tfvars.json

```json
{
  "create_isc": true,
  "github_isc": true,
  "github_api_token": "ghp_..",
  "github_owner": ""
}
```



- In gitops-runtime-values.yaml

```yaml
global:
  runtime:
    gitCredentials:
      password: 
        value: ghp_...

```

### Gitlab

To configure Version Control for GitOps Runtime you will need a Personal Access Token and define the following:

- In your tfvars.json

```json
{
  "create_isc": true,
  "gitlab_isc": true,
  "gitlab_api_token": "glpat-..",
}
```



- In gitops-runtime-values.yaml

```yaml
global:
  runtime:
    gitCredentials:
      password: 
        value: glpat-...

```

If you'd like to see you cloud/version control supported please create and issue in this repository.