# This repository is experimental.  Please be careful using this repository at this time.

Currently working to support Amazon cloud and GitHub.

You'll need the following today to spin up a demo environment.

1. [Codefresh Account](https://g.codefresh.io/signup)
1. [Amazon Account](https://aws.amazon.com/)
1. [GitHub Account](https://github.com/signup)

## This project is meant to...

1. Create the necessary Cloud infrastructure for Codefresh.
1. Install [Codefresh Runtime](https://artifacthub.io/packages/helm/codefresh-runner/cf-runtime)
1. Install [GitOps Runtime](https://artifacthub.io/packages/helm/codefresh-gitops-runtime/gitops-runtime)
1. Install a [Demo GitOps Application](https://github.com/codefresh-contrib/example-voting-app)

### Required Variables

| Arguments | DEFAULT | TYPE | DESCRIPTION |
|------------------|-------------------------|--------|---------------------------------------------------------------------------------------------------------------------------------|
| eks_cluster_name | Amazon EKS Cluster Name | string | Used throughout Terraform as unique name for many Amazon/Codefresh Resources |
| cf_account_id | Codefresh Account ID | string | https://g.codefresh.io/2.0/account-settings/account-information |
| cf_api_token | Codefresh API Key | string | [Generate API Key](https://g.codefresh.io/user/settings) All Scopes |
| github_api_token | GitHub API Token | string | [Generate Classic Token](https://github.com/settings/tokens), Scopes - *.repo, admin:repo_hook.*,   |
| github_owner | GitHub Organization | string | Organization or Personal Account |
| jira_api_token | Jira API Token | string | [Generate API Token](https://id.atlassian.com/manage-profile/security/api-tokens) |

Example Variable Files

``` terraform.tfvars.json
{
  "eks_cluster_name": ",
  "cf_account_id": "",
  "cf_api_token": "",
  "github_api_token": "",
  "github_owner": "",
  "jira_api_token": ""
}
```

If you need to customize either runtime installation you'll find Helm values files in this repository which will be applied to the installs.