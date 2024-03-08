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
  version = "~> 20.0"

  enable_cluster_creator_admin_permissions = true

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

# Authentication for Helm

data "aws_eks_cluster" "demo" {
  name = module.eks.cluster_name

  depends_on = [
    module.vpc,
    module.eks
  ]
}

# Setup EBS Access
data "aws_iam_policy_document" "cf_runtime_assume_role_policy" {
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
  name        = "var.eks_cluster_name"
  description = "Custom EBS Policy for Codefresh"
  policy = data.aws_iam_policy_document.cf_runtime_ebs_csi.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.cf_runtime.name
  policy_arn = aws_iam_policy.cf_runtime_ebs_csi.arn
}

# Setup S3 (Storage Integration)

resource "aws_s3_bucket" "codefresh-demo" {
  bucket = "${replace(var.eks_cluster_name, "-", "")}"

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

resource "aws_ecr_repository" "result" {
  name                 = "example-voting-app/result"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "tests" {
  name                 = "example-voting-app/tests"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "vote" {
  name                 = "example-voting-app/vote"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "worker" {
  name                 = "example-voting-app/worker"
  image_tag_mutability = "MUTABLE"
}

resource "aws_iam_role_policy_attachment" "ecr_poweruser" {
  role       = aws_iam_role.cf_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Create ECR Docker Registry Integration

resource "terraform_data" "docker_registry" {
  provisioner "local-exec" {
    on_failure = continue
    command = <<EOT
      curl --location 'https://g.codefresh.io/api/registries' \
      --header 'Content-Type: application/json' \
      --header 'Accept: application/json' \
      --header 'Authorization: Bearer ${var.cf_api_token}' \
      --data '{
        "name": "${var.eks_cluster_name}",
        "provider": "ecr",
        "region": "${var.aws_region}",
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

# Create Codefresh Config

resource "docker_container" "cf_create_context" {
  count = var.create_isc ? 1 : 0
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
              module.eks.cluster_name,
              "--api-key",
              var.cf_api_token
            ]
  attach = "true"
  must_run = "false"
}

# Create Codefresh ISC Repository in GitHub

resource "github_repository" "codefresh-demo-isc" {
  count = var.github_isc ? 1 : 0
  name        = "${module.eks.cluster_name}-isc"
  description = "Codefresh Shared Configuration Repository"

  visibility = "private"
  depends_on = [
    docker_container.cf_create_context
  ]
}

# Create Codefresh ISC Repository in Gitlab

resource "gitlab_project" "codefresh-demo-isc" {
  count = var.gitlab_isc ? 1 : 0
  name        = "${module.eks.cluster_name}-isc"
  description = "Codefresh Shared Configuration Repository"

  default_branch = "main"
  initialize_with_readme = true
  visibility_level = "private"
  depends_on = [
    docker_container.cf_create_context
  ]
}

# Get Version Control Information

locals {
  repo_clone_url = try(github_repository.codefresh-demo-isc[0].http_clone_url, gitlab_project.codefresh-demo-isc[0].http_url_to_repo, null)
  provider = var.github_isc ? "github" : "gitlab"
}

# Add Codefresh ISC Repository

resource "docker_container" "cf_configure_isc" {
  count = var.create_isc ? 1 : 0
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
              "--silent",
              "--git-provider",
              "${local.provider}",
              "--shared-config-repo",
              "${local.repo_clone_url}"
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    github_repository.codefresh-demo-isc
  ]
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
    module.vpc,
    module.eks
  ]
}

# Create GitOps Runtime

resource "helm_release" "gitops-runtime" {
  name       = "${var.gitops_runtime_name}"
  repository = "oci://quay.io/codefresh"
  chart      = "gitops-runtime"
  version    = "${var.gitops_runtime_version}"
  namespace  = "${var.gitops_runtime_namespace}"
  create_namespace = "true"

  values = [
    file("${path.module}/gitops-runtime-values.yaml")
  ]

  set {
    name  = "global.codefresh.accountId"
    value = var.cf_account_id
  }

  set_sensitive {
    name  = "global.codefresh.userToken.token"
    value = var.cf_api_token
  }

  set {
    name  = "global.runtime.name"
    value = module.eks.cluster_name
  }

  depends_on = [
    module.vpc,
    module.eks,
    docker_container.cf_configure_isc
  ]
}

# Create Codefresh Runtime

resource "helm_release" "cf-runtime" {
  name       = "${var.cf_runtime_name}"
  repository = "oci://quay.io/codefresh"
  chart      = "cf-runtime"
  version    = "${var.cf_runtime_version}"
  namespace  = "${var.cf_runtime_namespace}"
  create_namespace = "true"

  values = [
    file("${path.module}/cf-runtime-values.yaml")
  ]

  set_sensitive {
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

# Create Demo App GitHub

module "create_github_demo_app" {
  count = var.create_github_demo_app ? 1 : 0

  source = "../../helm/eva-demo-app/github"

  providers = {
    github = github
    dataprocessor = dataprocessor
  }

  cf_api_token = var.cf_api_token
  docker_host = var.docker_host
  github_api_token = var.github_api_token 
  github_base_url = var.github_base_url
  github_owner = var.github_owner
  registry_result = aws_ecr_repository.result.repository_url
  registry_tests = aws_ecr_repository.tests.repository_url
  registry_vote = aws_ecr_repository.vote.repository_url
  registry_worker = aws_ecr_repository.worker.repository_url
  runtime_name = var.eks_cluster_name

  depends_on = [
    helm_release.gitops-runtime
  ]
}

# Create Demo App Gitlab

module "create_gitlab_demo_app" {
  count = var.create_gitlab_demo_app ? 1 : 0

  source = "../../helm/eva-demo-app/gitlab"

  providers = {
    gitlab = gitlab
    dataprocessor = dataprocessor
  }

  runtime_name = var.eks_cluster_name
  docker_host = var.docker_host
  gitlab_api_token = var.gitlab_api_token 
  gitlab_base_url = var.gitlab_base_url

  depends_on = [
    helm_release.gitops-runtime
  ]
}
