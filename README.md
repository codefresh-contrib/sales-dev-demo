We are focusing on quick starts (sandboxes) to get Codfresh Runtimes installed and a simple GitOps Demo application configured in you Codefresh account.

## This project is meant to...

1. Create the necessary infrastructure in your cloud for Codefresh.
1. Configure Version Control w/ Codefresh
1. Install Codefresh Runtime
1. Install GitOps Runtime
1. Install NGINX

## Testewd Operating Systems

MacOS:
- M2
  - Monterey 12.2
- M3
  - Sonoma 14.3

Windows OS:
- Windows 11 Enterprise
  - Version: 23H2 
    - OS Build 22631.3155

## Codefresh Configuration

Required Codefresh Configuration

```json
{
  "cf_account_id": "",
  "cf_api_token": ""
}
```

## Clouds

#### Exammple of Codefresh Variables Requires in tfvars.json

#### Amazon
./clouds/amazon
Codefresh Runner (CI) has EBS optimized caching

Required Amazon Configuration `tfvars.json`

```json
{
  "eks_cluster_name": "poc-demo-eks-1"
}
```

#### Azure
./clouds/azure
Codefresh Runner (CI) has no caching (Coming soon)

Required Azure Configuration for `tfvars.json`

```json
{
    "azure_location": "",
    "azure_prefix": "",
    "azure_subscription": ""
}
```

If you have any issue with registering providers in Azure please try exporting the VAR below to your terminal

`ARM_SKIP_PROVIDER_REGISTRATION=true`

### Google
./clouds/google
Codefresh Runner (CI) has no caching (Coming soon)

Required Google Configuration `tfvars.json`

```json
{
    "google_location": "",
    "google_project_id": "",
    "gke_cluster_name": ""
}
```

## Version Control

This requires Docker on your machine.

This also cannot be done later do to order of operations.  You must add this during the initial apply.  
The demo app creation can be done later.

If you're using Windows OS please add the following to your `tfvars.json`

```json
{
  "docker_host": "npipe:////.//pipe//docker_engine"
}
```

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

#### GitHub ArgoCD Example Application

To install a demo application into your cluster enable the following flag.  With this flag enabled a demo application will be installed.

- In your tfvars.json

```json
{
  "create_github_demo_app": true
}
```

### Gitlab


To configure Version Control for GitOps Runtime you will need a Personal Access Token and define the following:

- In your tfvars.json

```json
{
  "create_isc": true,
  "gitlab_isc": true,
  "gitlab_api_token": "glpat-.."
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

#### Gitlab ArgoCD Example Application

To install a demo application into your cluster enable the following flag.  With this flag enabled a demo application will be installed.

- In your tfvars.json

```json
{
  "create_gitlab_demo_app": true
}
```


## Future

If you'd like to see you cloud/version control supported please create and issue in this repository.
