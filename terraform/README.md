Infrastructure as Code (Terraform)

This Terraform stack provisions:
- AWS VPC
- AWS EKS (Kubernetes)
- AWS RDS PostgreSQL
- Optional initial Helm deployment of all microservices using the repo chart (helm/mis-cloud-native)

Prerequisites
- Terraform >= 1.5
- AWS credentials with permissions to manage VPC/EKS/RDS (export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION)
- For local Helm provider use, ensure kubectl/helm can reach the cluster (providers are auto-configured from EKS data sources)

Quick start
1. cd terraform
2. Create a tfvars file (terraform.tfvars) and set db_password and optionally service images:

   db_password = "strong-password"
   service_images = {
     cart     = "ghcr.io/OWNER/cart:latest"
     identity = "ghcr.io/OWNER/identity:latest"
     order    = "ghcr.io/OWNER/order:latest"
     payment  = "ghcr.io/OWNER/payment:latest"
     product  = "ghcr.io/OWNER/product:latest"
   }

3. terraform init
4. terraform apply

Outputs
- cluster_name, cluster_endpoint
- db_address, db_name

Kubeconfig
After apply, set kubeconfig with:

  aws eks update-kubeconfig --name <cluster_name> --region <region>

Then you can manage releases via Helm. CI workflows (see .github/workflows) build/push service images to GHCR and upgrade the Helm release per service.
