locals {
  name = var.project_name
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for i, az in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Project = local.name
  }
}

data "aws_availability_zones" "available" {}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name                   = "${local.name}-eks"
  cluster_version                = var.eks_version
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }

  tags = {
    Project = local.name
  }
}

# Security group to allow EKS pods access to RDS
resource "aws_security_group" "db_access" {
  name        = "${local.name}-db-access"
  description = "Allow EKS subnets access to RDS"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "db_ingress" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  security_group_id        = module.db.security_group_id
  source_security_group_id = aws_security_group.db_access.id
}

# RDS PostgreSQL
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.6"

  identifier = "${local.name}-postgres"

  engine               = "postgres"
  engine_version       = var.db_engine_version
  family               = "postgres16"
  major_engine_version = "16"

  instance_class    = var.db_instance_class
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  port = 5432

  multi_az               = false
  publicly_accessible    = false
  manage_master_user_password = false

  vpc_security_group_ids = [aws_security_group.db_access.id]
  subnet_ids             = module.vpc.private_subnets

  create_db_subnet_group = true

  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Project = local.name
  }
}

# Optionally install initial Helm release for all services using repo chart
resource "helm_release" "mis" {
  count      = var.create_initial_helm ? 1 : 0
  name       = "mis"
  repository = null
  chart      = "../helm/mis-cloud-native"
  namespace  = "default"

  values = [yamlencode({
    global = {
      imageRegistry  = var.global_image_registry != "" ? var.global_image_registry : null
      imagePullPolicy = "IfNotPresent"
      ingress = {
        enabled   = false
        className = null
        hosts     = []
      }
    }
    services = {
      cart = {
        enabled       = true
        image         = var.service_images["cart"]
        containerPort = 8080
        service       = { port = 80 }
        env           = []
      }
      identity = {
        enabled       = true
        image         = var.service_images["identity"]
        containerPort = 8080
        service       = { port = 80 }
        env           = []
      }
      order = {
        enabled       = true
        image         = var.service_images["order"]
        containerPort = 8080
        service       = { port = 80 }
        env           = []
      }
      payment = {
        enabled       = true
        image         = var.service_images["payment"]
        containerPort = 8080
        service       = { port = 80 }
        env           = []
      }
      product = {
        enabled       = true
        image         = var.service_images["product"]
        containerPort = 8080
        service       = { port = 80 }
        env           = []
      }
    }
  })]

  depends_on = [module.eks]
}
