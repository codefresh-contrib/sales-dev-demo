# Azure Terraform Automation

What's included?

1. AKS Cluster Automation
1. Codefresh Runtime installation.
1. GitOps Runtime installation.
1. NGINX installation

What's not included?

1. Automated GIT repository setup.

What you'll need to setup prior to running automation.

1. Azure Subscription (Capability to create Resource Group)
1. GIT repository for Codefresh Internal Shared Configuration (ISC), this contains Codefresh configuration files.
1. GIT repository for Example Voting Application (EVA)
1. GIT source for ArgoCD Applications (for demo application is sub directory in EVA repository)