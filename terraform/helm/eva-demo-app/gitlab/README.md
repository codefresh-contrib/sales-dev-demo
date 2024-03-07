# Argo Application Deployment

This module creates a Gitlab Repository using this [template repository](https://gitlab.com/codefresh-contrib/example-voting-app)

Then it adds the `argocd/applications` directory as a [GIT Source](https://codefresh.io/docs/docs/installation/gitops/git-sources)

This will create an Example Voting App (ArgoCD Application) in 3 different namespaces to reflect a very typical environment tier configuration of development, staging and production.