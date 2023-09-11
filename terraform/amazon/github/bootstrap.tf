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

resource "aws_ecr_repository" "result" {
  name                 = "example-voting-app/result"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "test" {
  name                 = "example-voting-app/test"
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

# Create GitOps Runtime

resource "helm_release" "gitops-runtime" {
  name       = "${var.gitops_runtime_name}"
  repository = "https://chartmuseum.codefresh.io/gitops-runtime"
  chart      = "gitops-runtime"
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
              "temp",
              "--api-key",
              var.cf_api_token
            ]
  attach = "true"
  must_run = "false"
}

# Create Codefresh ISC Repository

resource "github_repository" "codefresh-demo-isc" {
  name        = "codefresh-demo-isc"
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
              github_repository.codefresh-demo-isc.http_clone_url
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

# Add GitOps GIT Integration

resource "docker_container" "cf_add_git_integration" {
  name  = "cf_add_git_integration"
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
              "add",
              "default",
              "--api-url",
              "https://api.github.com",
              "--runtime",
              module.eks.cluster_name
            ]
  attach = "true"
  must_run = "false"

  depends_on = [
    helm_release.gitops-runtime
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
    docker_container.cf_add_git_integration
  ]
}

# Copy Demo App Repository to GitHub

resource "github_repository" "codefresh-demo-app" {
  name        = "codefresh-demo-app"
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

# TODO: Create Load Balancer

# TODO: Install NGINX via Helm and associate to Load Balancer

# TODO: Update example-voting-app to nginx ingress

# TODO: Codefresh Terraform Provider Work

# TODO: Add Project Creation

# TODO: Convert Codefresh Pipelines into Terraform Code

# TODO: Create Docker Registry Integration

# TODO: Create Storage Integration

# TODO: Codefresh run initialization pipeline to build all stable images to begin their life cycle

# TODO: Add NGINX deployment

# TODO: Add ingress to Helm Chart

# TODO: GitOps Works

# TODO: Create Codefresh Pipeline in Terraform for GitOps Promotion

# TODO: Create S
