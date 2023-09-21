# Create VPC

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.eks_cluster_name}"
  cidr = "10.1.0.0/16"

  azs             = var.eks_mng_availability_zones
  public_subnets  = ["10.1.0.0/20","10.1.16.0/20"]

  map_public_ip_on_launch = "true"
}

# Create EKS Cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.eks_cluster_name}"
  cluster_version = "${var.eks_cluster_version}"
  cluster_encryption_config = {}

  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = [
    "0.0.0.0/0"
  ]
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    node_group = {
      min_size     = var.eks_mng_min_size
      max_size     = var.eks_mng_max_size
      desired_size = var.eks_mng_desired_size
      availability_zones = var.cf_runtime_az

      instance_types = var.eks_mng_instance_types
      capacity_type  = "${var.eks_mng_capacity_type}"
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  tags = var.eks_mng_tags
}

# Create KubeConfig

data "aws_eks_cluster_auth" current {
  name = module.eks.cluster_name
}

locals {
  kubeconfig = <<-EOT
    apiVersion: v1
    clusters:
    - cluster:
        server: ${module.eks.cluster_endpoint}
        certificate-authority-data: ${module.eks.cluster_certificate_authority_data}
      name: ${module.eks.cluster_name}
    contexts:
    - context:
        cluster: ${module.eks.cluster_name}
        user: ${module.eks.cluster_name}
      name: ${module.eks.cluster_name}
    current-context: ${module.eks.cluster_name}
    kind: Config
    preferences: {}
    users:
    - name: ${module.eks.cluster_name}
      user:
        token: ${nonsensitive(data.aws_eks_cluster_auth.current.token)}
  EOT
}

resource "local_file" "temp_config" {
  filename  = "${module.eks.cluster_name}-kube-config.yaml"
  content   = local.kubeconfig
}

# Setup EBS Access
data "aws_iam_policy_document" "cf_runtime_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = [module.eks.eks_managed_node_groups.node_group.iam_role_arn]
      type        = "AWS"
    }
  }
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.cf_runtime_namespace}:cf-runtime-volume-provisioner"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.cf_runtime_namespace}:codefresh-engine"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
  depends_on = [
    module.eks
  ]
}

resource "aws_iam_role" "cf_runtime" {
  assume_role_policy = data.aws_iam_policy_document.cf_runtime_assume_role_policy.json
  name               = "${var.eks_cluster_name}"
  depends_on = [
    data.aws_iam_policy_document.cf_runtime_assume_role_policy
  ]
}

data "aws_iam_policy_document" "cf_runtime_ebs_csi" {
  statement {
    actions   = [
                  "ec2:AttachVolume",
                  "ec2:CreateSnapshot",
                  "ec2:CreateTags",
                  "ec2:CreateVolume",
                  "ec2:DeleteSnapshot",
                  "ec2:DeleteTags",
                  "ec2:DeleteVolume",
                  "ec2:DescribeInstances",
                  "ec2:DescribeSnapshots",
                  "ec2:DescribeTags",
                  "ec2:DescribeVolumes",
                  "ec2:DetachVolume"
                ]
    resources = ["*"]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "cf_runtime_ebs_csi" {
  name        = "cf_runtime_ebs_csi"
  description = "Custom EBS Policy for Codefresh"
  policy = data.aws_iam_policy_document.cf_runtime_ebs_csi.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.cf_runtime.name
  policy_arn = aws_iam_policy.cf_runtime_ebs_csi.arn
}

# Setup S3 (Storage Integration)

resource "aws_s3_bucket" "codefresh-demo" {
  bucket = "codefresh-demo"

  tags = {
    Name        = "Codefresh Demo"
    Environment = "Demo"
  }
}

resource "aws_iam_role_policy_attachment" "s3_poweruser" {
  role       = aws_iam_role.cf_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Setup EC2 Container Registry
# BUG: Destroy is unable to delete repositories containing images 
# https://github.com/hashicorp/terraform-provider-aws/issues/33523
# TODO: Write script to clean out images before deletion by destroy

# Workaround for 33523
resource "null_resource" "delete_result_images" {
  triggers = {
    aws_region = var.aws_region
    repository_name = var.eks_cluster_name
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws ecr batch-delete-image --region ${self.triggers.aws_region} \
      --repository-name ${self.triggers.repository_name}/result \
      --image-ids "$(aws ecr list-images --region ${self.triggers.aws_region} --repository-name ${self.triggers.repository_name}/result --query 'imageIds[*]' --output json)" || true
    EOT
  }
}

resource "aws_ecr_repository" "result" {
  name                 = "${module.eks.cluster_name}/result"
  force_delete         = true

  # Workaround for 33523
  depends_on = [
    null_resource.delete_result_images
  ]
}

# Workaround for 33523
resource "null_resource" "delete_tests_images" {
  triggers = {
    aws_region = var.aws_region
    repository_name = var.eks_cluster_name
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws ecr batch-delete-image --region ${self.triggers.aws_region} \
      --repository-name ${self.triggers.repository_name}/tests \
      --image-ids "$(aws ecr list-images --region ${self.triggers.aws_region} --repository-name ${self.triggers.repository_name}/tests --query 'imageIds[*]' --output json)" || true
    EOT
  }
}

resource "aws_ecr_repository" "tests" {
  name                 = "${module.eks.cluster_name}/tests"
  force_delete         = true

   # Workaround for 33523
  depends_on = [
    null_resource.delete_tests_images
  ]
}

# Workaround for 33523
resource "null_resource" "delete_vote_images" {
  triggers = {
    aws_region = var.aws_region
    repository_name = var.eks_cluster_name
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws ecr batch-delete-image --region ${self.triggers.aws_region} \
      --repository-name ${self.triggers.repository_name}/vote \
      --image-ids "$(aws ecr list-images --region ${self.triggers.aws_region} --repository-name ${self.triggers.repository_name}/vote --query 'imageIds[*]' --output json)" || true
    EOT
  }
}

resource "aws_ecr_repository" "vote" {
  name                 = "${module.eks.cluster_name}/vote"
  force_delete         = true

  # Workaround for 33523
  depends_on = [
    null_resource.delete_vote_images
  ]
}

# Workaround for 33523
resource "null_resource" "delete_worker_images" {
  triggers = {
    aws_region = var.aws_region
    repository_name = var.eks_cluster_name
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws ecr batch-delete-image --region ${self.triggers.aws_region} \
      --repository-name ${self.triggers.repository_name}/worker \
      --image-ids "$(aws ecr list-images --region ${self.triggers.aws_region} --repository-name ${self.triggers.repository_name}/worker --query 'imageIds[*]' --output json)" || true
    EOT
  }
}

resource "aws_ecr_repository" "worker" {
  name                 = "${module.eks.cluster_name}/worker"
  force_delete         = true

  # Workaround for 33523
  depends_on = [
    null_resource.delete_worker_images
  ]
}

resource "aws_iam_role_policy_attachment" "ecr_poweruser" {
  role       = aws_iam_role.cf_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Create NGINX Controller

module "nginx-controller" {
  source  = "terraform-iaac/nginx-controller/helm"

  create_namespace = true

  additional_set = [
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
      type  = "string"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
      value = "true"
      type  = "string"
    }
  ]
  depends_on = [
    module.eks
  ]
}

# Automated DNS Creation
# module "eks-external-dns_example_basic" {
#   source  = "lablabs/eks-external-dns/aws//examples/basic"
#   version = "1.2.0"
# }

# Create GitOps Runtime

resource "helm_release" "gitops-runtime" {
  name       = "${var.gitops_runtime_name}"
  repository = "https://chartmuseum.codefresh.io/gitops-runtime"
  chart      = "gitops-runtime"
  version    = "0.2.17"
  devel      = "true"
  namespace  = "${var.gitops_runtime_namespace}"
  create_namespace = "true"

  values = [
    file("${path.module}/gitops-runtime-values.yaml")
  ]

  set {
    name  = "global.codefresh.accountId"
    value = var.cf_account_id
  }

  set {
    name  = "global.codefresh.userToken.token"
    value = var.cf_api_token
  }

  set {
    name  = "global.runtime.name"
    value = module.eks.cluster_name
  }

  set {
    name = "global.runtime.gitCredentials.password.value"
    value = var.github_api_token
  }

  depends_on = [
    module.vpc,
    module.eks
  ]
}

# Create Codefresh Config

resource "docker_container" "cf_create_context" {
  name  = "cf_create_context"
  image = "quay.io/codefresh/cli-v2:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "cf",
              "config",
              "create-context",
              var.eks_cluster_name,
              "--api-key",
              var.cf_api_token
            ]
  attach = "true"
  must_run = "false"
}

# Create Codefresh ISC Repository

resource "github_repository" "codefresh-demo-isc" {
  name        = "${var.eks_cluster_name}-demo-isc"
  description = "Codefresh Shared Configuration Repository"

  visibility = "private"
  depends_on = [
    docker_container.cf_create_context
  ]
}

# Add Codefresh ISC Repository

resource "docker_container" "cf_configure_isc" {
  name  = "cf_configure_isc"
  image = "quay.io/codefresh/cli-v2:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "cf",
              "config",
              "update-gitops-settings",
              "--shared-config-repo",
              github_repository.codefresh-demo-isc.http_clone_url,
              "--silent"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    github_repository.codefresh-demo-isc
  ]
}

# Create Codefresh Runtime

resource "helm_release" "cf-runtime" {
  name       = "${var.cf_runtime_name}"
  repository = "https://chartmuseum.codefresh.io/cf-runtime"
  chart      = "cf-runtime"
  version    = "6.1.3"
  namespace  = "${var.cf_runtime_namespace}"
  create_namespace = "true"

  values = [
    file("${path.module}/cf-runtime-values.yaml")
  ]

  set {
    name  = "global.codefreshToken"
    value = var.cf_api_token
  }

  set {
    name  = "global.runtimeName"
    value = module.eks.cluster_name
  }

  set {
    name  = "global.context"
    value = module.eks.cluster_name
  }

  set {
    name  = "global.agentName"
    value = module.eks.cluster_name
  }

  set {
    name = "installer.skipValidation"
    value = "true"
  }

  set {
    name = "runtime.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cf_runtime.arn
  }

  set {
    name = "volumeProvisioner.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cf_runtime.arn
  }

  set {
    name = "storage.ebs.availabilityZone"
    value = var.cf_runtime_az
  }

  depends_on = [
    module.vpc,
    module.eks
  ]
}

# Register GitOps GIT Integration

resource "docker_container" "cf_register_git_integration" {
  name  = "cf_register_git_integration"
  image = "quay.io/codefresh/cli-v2:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "cf",
              "integration",
              "git",
              "register",
              "default",
              "--runtime",
              module.eks.cluster_name,
              "--token",
              var.github_api_token
            ]
  attach = "true"
  must_run = "false"
  depends_on = [
    helm_release.gitops-runtime,
    docker_container.cf_configure_isc
  ]
}

# Create GitOps JIRA Integration

# resource "null_resource" "create_gitops_jira_integration" {
#   triggers = {
#     always_run = timestamp() # this will always run
#   }
#   provisioner "local-exec" {
#     command = <<EOT
#       curl --location 'https://${var.cf_account_id}-${module.eks.cluster_name}.tunnels.cf-cd.com/app-proxy/api/graphql' \
#       --header 'Content-Type: application/json' \
#       --header 'Accept: application/json' \
#       --header 'Authorization: ${var.cf_api_token}' \
#       --data '{
#         "operationName" : "IntegrationFlow",
#         "variables": {
#           "input": {
#             "metadata": {
#               "name": "cf-demo-jira",
#               "isAllRuntimes": false,
#               "runtimes": ["${module.eks.cluster_name}"],
#               "type": "issue.jira"
#             },
#             "providerInfo" : {
#               "host_url": "https://cf-demo-jira.atlassian.net",
#               "email": "salesdemocf@gmail.com"
#             },
#             "secureData":{
#               "api_token": "${var.jira_api_token}"
#             },
#             "operation": "CREATE"
#             }
#         },
#         "query": "mutation IntegrationFlow($input: IntegrationFlowInput!) {\n  applyIntegration(input: $input)\n}\n"
#       }'
#     EOT
#   }
#   depends_on = [
#     helm_release.gitops-runtime
#   ]
# }

# Create GitOps Docker Registry Integration

resource "null_resource" "create_gitops_docker_registry_integration" {
  provisioner "local-exec" {
    command = <<EOT
      curl --location 'https://${var.cf_account_id}-${module.eks.cluster_name}.tunnels.cf-cd.com/app-proxy/api/graphql' \
      --header 'Content-Type: application/json' \
      --header 'Accept: application/json' \
      --header 'Authorization: ${var.cf_api_token}' \
      --data '{
        "operationName" : "IntegrationFlow",
        "variables" : {
          "input" : {
            "metadata" : {
              "name" : "${var.github_owner}",
              "isAllRuntimes": false,
              "runtimes": ["${module.eks.cluster_name}"],
              "type": "registry.ecr"
            },
            "providerInfo": {
              "region": "${var.aws_region}",
              "role_arn": "${aws_iam_role.cf_runtime.arn}"
            },
            "operation": "CREATE"
          }
        },
          "query": "mutation IntegrationFlow($input: IntegrationFlowInput!) {\n  applyIntegration(input: $input)\n}\n"
      }'
    EOT
  }

  depends_on = [
    helm_release.gitops-runtime,
    docker_container.cf_register_git_integration
  ]
}

# Copy Demo App Repository to GitHub

resource "github_repository" "codefresh-demo-app" {
  name        = "${var.eks_cluster_name}-demo-app"
  description = "Codefresh Demo App Repository"

  visibility = "public"

  template {
    owner                = "codefresh-contrib"
    repository           = "example-voting-app"
  }
  depends_on = [
    docker_container.cf_register_git_integration
  ]
}

# Update Application Manifests

data "github_repository_file" "eva_development_app_manifest_temp" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-development.yaml"

  depends_on = [
    github_repository.codefresh-demo-app
  ]
}

data "github_repository_file" "eva_staging_app_manifest_temp" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-staging.yaml"

  depends_on = [
    github_repository.codefresh-demo-app
  ]
}

data "github_repository_file" "eva_production_app_manifest" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-production.yaml"

  depends_on = [
    github_repository.codefresh-demo-app
  ]
}

data "dataprocessor_yq" "development" {
  input_data = data.github_repository_file.eva_development_app_manifest_temp.content
  expression = ".spec.source.repoURL = \"${github_repository.codefresh-demo-app.http_clone_url}\""

  depends_on = [
    data.github_repository_file.eva_development_app_manifest_temp
  ]
}

data "dataprocessor_yq" "staging" {
  input_data = data.github_repository_file.eva_staging_app_manifest_temp.content
  expression = ".spec.source.repoURL = \"${github_repository.codefresh-demo-app.http_clone_url}\""

  depends_on = [
    data.github_repository_file.eva_staging_app_manifest_temp
  ]
}

data "dataprocessor_yq" "production" {
  input_data = data.github_repository_file.eva_production_app_manifest.content
  expression = ".spec.source.repoURL = \"${github_repository.codefresh-demo-app.http_clone_url}\""

  depends_on = [
    data.github_repository_file.eva_production_app_manifest
  ]
}

resource "github_repository_file" "eva_development_app_manifest" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-development.yaml"
  content             = data.dataprocessor_yq.development.result
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true

  depends_on = [
    data.dataprocessor_yq.development
  ]
}

resource "github_repository_file" "eva_staging_app_manifest" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-staging.yaml"
  content             = data.dataprocessor_yq.staging.result
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true

  depends_on = [
    data.dataprocessor_yq.staging
  ]
}

resource "github_repository_file" "eva_production_app_manifest" {
  repository          = github_repository.codefresh-demo-app.name
  branch              = "main"
  file                = "argocd/applications/helm-eva-production.yaml"
  content             = data.dataprocessor_yq.production.result
  commit_message      = "Managed by Terraform"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true

  depends_on = [
    data.dataprocessor_yq.production
  ]
}

# Add Demo App Repository as GitOps Git-Source

resource "docker_container" "cf_create_git_source" {
  name  = "cf_create_git_source"
  image = "quay.io/codefresh/cli-v2:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "cf",
              "git-source",
              "create",
              module.eks.cluster_name,
              "codefresh-demo-apps",
              "--git-src-git-token",
              var.github_api_token,
              "--git-src-repo",
              "${github_repository.codefresh-demo-app.http_clone_url}/argocd/applications"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    github_repository.codefresh-demo-app
  ]
}

# Authenticate with Codefresh CLI

resource "docker_container" "codefresh_create_auth" {
  name  = "codefresh_create_auth"
  image = "quay.io/codefresh/cli:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "codefresh",
              "auth",
              "create-context",
              module.eks.cluster_name,
              "--api-key",
              var.cf_api_token
            ]
  attach = "true"
  must_run = "false"
}

# Add Pipelines GIT Integration

resource "docker_container" "codefresh_create_git_context" {
  name  = "codefresh_create_git_context"
  image = "quay.io/codefresh/cli:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "codefresh",
              "create",
              "context",
              "git",
              "github",
              var.github_owner,
              "--sharing-policy",
              "AllUsersInAccount",
              "--access-token",
              var.github_api_token
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    docker_container.codefresh_create_auth
  ]
}

# Create ECR Docker Registry Integration
## TODO: Submit Request to support in Codefresh Provider

resource "terraform_data" "codefresh_create_docker_registry_integration" {
  provisioner "local-exec" {
    command = <<EOT
      curl --location 'https://g.codefresh.io/api/registries' \
      --header 'Content-Type: application/json' \
      --header 'Accept: application/json' \
      --header 'Authorization: Bearer ${var.cf_api_token}' \
      --data '{
        "name": "${module.eks.cluster_name}",
        "provider": "ecr",
        "region": "us-east-1",
        "behindFirewall": true,
        "primary": true,
        "default": true,
        "internal": true,
        "denyCompositeDomain": true,
        "domain": "from.service-account",
        "getCredsFromServiceAccount": true
      }'
    EOT
  }
}

# Create Demo App Project

resource "codefresh_project" "create_demo_app_project" {
  name = "Initialize Codefresh Demo App Project"

  tags = [
    "demo"
  ]

  depends_on = [
    terraform_data.codefresh_create_docker_registry_integration,
    docker_container.cf_create_git_source
  ]
}

# Create Demo App Initialization Pipeline

resource "codefresh_pipeline" "create_demo_app_initialization_pipeline" {
  name = "${codefresh_project.create_demo_app_project.name}/demo-app-initialization"

  tags = [
    "demo",
    "initialization"
  ]

  spec {
    spec_template {
	  repo        = "${var.github_owner}/${github_repository.codefresh-demo-app.name}"
      path        = "./.codefresh/initialization/initialize-demo-app.yaml"
      revision    = "main"
      context     = "${var.github_owner}"
    }

    variables = {
      RESULT_DOCKER_REGISTRY = aws_ecr_repository.result.repository_url
      VOTE_DOCKER_REGISTRY = aws_ecr_repository.vote.repository_url
      WORKER_DOCKER_REGISTRY = aws_ecr_repository.worker.repository_url
      GITOPS_RUNTIME_NAME = module.eks.cluster_name
    }

    trigger {
      name                = "${github_repository.codefresh-demo-app.name}-initialize"
      type                = "git"
      repo                = "${var.github_owner}/${github_repository.codefresh-demo-app.name}"
      events              = ["push.heads"]
      pull_request_allow_fork_events = false
      comment_regex       = "/.*/gi"
      branch_regex        = "/.*/gi"
      branch_regex_input  = "regex"
      provider            = "github"
      disabled            = true
      options {
        no_cache        = false
        no_cf_cache     = false
        reset_volume    = false
      }
      context             = "${var.github_owner}"
      contexts            = []
    }

    runtime_environment {
      name                = module.eks.cluster_name
      cpu                 = "1000m"
      memory              = "2048Mi"
    }

  }
  depends_on = [
    codefresh_project.create_demo_app_project,
    helm_release.cf-runtime
  ]
}

# Run Demo App Initialization Pipeline

resource "docker_container" "codefesh_run_demo_app_initializaton_pipeline" {
  name  = "codefesh_run_demo_app_initializaton_pipeline"
  image = "quay.io/codefresh/cli:latest"
  entrypoint = [""]
  env = ["HOME=/tmp"]
  working_dir = "/usr/local/bin"
  volumes {
    host_path = path.cwd
    container_path = "/tmp"
  }
  command = [
              "codefresh",
              "run",
              codefresh_pipeline.create_demo_app_initialization_pipeline.id,
              "--trigger",
              "${github_repository.codefresh-demo-app.name}-initialize",
              "--branch",
              "main"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    codefresh_pipeline.create_demo_app_initialization_pipeline,
    terraform_data.codefresh_create_docker_registry_integration,
    docker_container.codefresh_create_git_context
  ]
}


# TODO: Future Codefresh Terraform Provider Work
# TODO: Add JIRA Integration< --- blocked
# TODO: Add Pipeline success check

# TODO: Create Storage Integration (Role not supported)
# TODO: Convert Golden Pipeline to Terraform
# TODO: Convert GitOps Promotion Pipeline into Terraform Code
# TODO: Convert Codefresh EVA Pipelines into Terraform Code

# TODO: Update example-voting-app to nginx ingress (will take a rewrite of application code to support without subdomain configuration)
# TODO: Add Route53 Automation for DNS Records
# TODO: Automate DNS configuration
# TODO: Move to demo app to Argo Rollouts
