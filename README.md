# This repository is experimental.  Please be careful using this repository at this time.

## This project is meant to...

1. Create the necessary infrastructure in Amazon for Codefresh.
1. Install Codefresh Runtime
1. Install GitOps Runtime
1. Install a Demo GitOps Application

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
