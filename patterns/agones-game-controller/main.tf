provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name   = basename(path.cwd)
  region = var.region

  cluster_version = var.kubernetes_version


  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  gameserver_minport = 7000
  gameserver_maxport = 8000

  enable_gitops_bridge = var.enable_gitops_bridge

  gitops_addons_url      = "${var.gitops_addons_org}/${var.gitops_addons_repo}"
  gitops_addons_basepath = var.gitops_addons_basepath
  gitops_addons_path     = var.gitops_addons_path
  gitops_addons_revision = var.gitops_addons_revision

  gitops_workload_url      = "${var.gitops_workload_org}/${var.gitops_workload_repo}"
  gitops_workload_basepath = var.gitops_workload_basepath
  gitops_workload_path     = var.gitops_workload_path
  gitops_workload_revision = var.gitops_workload_revision

  aws_addons = {
    enable_cert_manager       = try(var.addons.enable_cert_manager, false)
    enable_cluster_autoscaler = try(var.addons.enable_cluster_autoscaler, false)

  }
  oss_addons = {
    enable_argocd         = try(var.addons.enable_argocd, true)
    enable_metrics_server = try(var.addons.enable_metrics_server, false)
  }
  addons = merge(
    local.aws_addons,
    local.oss_addons,
    { kubernetes_version = local.cluster_version },
    { aws_cluster_name = module.eks.cluster_name }
  )

  addons_metadata = merge(
    module.eks_blueprints_addons.gitops_metadata,
    {
      aws_cluster_name = module.eks.cluster_name
      aws_region       = local.region
      aws_account_id   = data.aws_caller_identity.current.account_id
      aws_vpc_id       = module.vpc.vpc_id
    },
    {
      addons_repo_url      = local.gitops_addons_url
      addons_repo_basepath = local.gitops_addons_basepath
      addons_repo_path     = local.gitops_addons_path
      addons_repo_revision = local.gitops_addons_revision
    },
    {
      workload_repo_url      = local.gitops_workload_url
      workload_repo_basepath = local.gitops_workload_basepath
      workload_repo_path     = local.gitops_workload_path
      workload_repo_revision = local.gitops_workload_revision
    }
  )

  workload_metadata = {
    agones_gameserver_minport = local.gameserver_minport
    agones_gameserver_maxport = local.gameserver_maxport
  }

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

################################################################################
# Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id                   = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.private_subnets
  subnet_ids               = module.vpc.public_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = ["m5.large"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2
    }

    agones_system = {
      instance_types = ["m5.large"]
      labels = {
        "agones.dev/agones-system" = true
      }
      taint = {
        dedicated = {
          key    = "agones.dev/agones-system"
          value  = true
          effect = "NO_EXECUTE"
        }
      }
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }

    agones_metrics = {
      instance_types = ["m5.large"]
      labels = {
        "agones.dev/agones-metrics" = true
      }
      taints = {
        dedicated = {
          key    = "agones.dev/agones-metrics"
          value  = true
          effect = "NO_EXECUTE"
        }
      }
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }

  node_security_group_additional_rules = {
    ingress_gameserver_udp = {
      description      = "Agones Game Server Ports"
      protocol         = "udp"
      from_port        = local.gameserver_minport
      to_port          = local.gameserver_maxport
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    },
    ingress_gameserver_webhook = {
      description                   = "Cluster API to node 8081/tcp agones webhook"
      protocol                      = "tcp"
      from_port                     = 8081
      to_port                       = 8081
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  tags = local.tags
}

################################################################################
# EKS Blueprints Addons
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.7"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  helm_releases = local.enable_gitops_bridge ? {} : {
    agones = {
      description      = "A Helm chart for Agones game server"
      namespace        = "agones-system"
      create_namespace = true
      chart            = "agones"
      chart_version    = "1.32.0"
      repository       = "https://agones.dev/chart/stable"
      values = [
        templatefile("${path.module}/helm_values/agones-values.yaml", {
          expose_udp         = true
          gameserver_minport = local.gameserver_minport
          gameserver_maxport = local.gameserver_maxport
        })
      ]
    }
  }

  # Using GitOps Bridge
  create_kubernetes_resources = local.enable_gitops_bridge ? false : true

  # EKS Blueprints Addons
  enable_cert_manager       = local.aws_addons.enable_cert_manager
  enable_cluster_autoscaler = local.aws_addons.enable_cluster_autoscaler
  enable_metrics_server     = local.oss_addons.enable_metrics_server

  tags = local.tags
}

################################################################################
# GitOps Bridge: Bootstrap
################################################################################
module "gitops_bridge_bootstrap" {
  source = "github.com/gitops-bridge-dev/gitops-bridge-argocd-bootstrap-terraform?ref=v2.0.0"
  count  = local.enable_gitops_bridge ? 1 : 0

  cluster = {
    metadata = merge(local.addons_metadata, local.workload_metadata)
    addons   = local.addons
  }
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  # NOTE: Agones requires a Node group in Public Subnets and enable Public IP
  map_public_ip_on_launch = true

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
