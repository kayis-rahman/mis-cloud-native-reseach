#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command_exists terraform; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi

    if ! command_exists kubectl; then
        print_warning "kubectl is not installed. Some Kubernetes cleanup may be skipped."
    fi

    if ! command_exists helm; then
        print_warning "helm is not installed. Some Helm cleanup may be skipped."
    fi

    if ! command_exists gcloud; then
        print_warning "gcloud CLI is not installed. Some GCP-specific cleanup may be skipped."
    fi

    print_success "Prerequisites check completed"
}

# Function to clean up Kubernetes resources
cleanup_kubernetes() {
    print_status "Cleaning up Kubernetes resources..."

    if command_exists kubectl; then
        # Check if kubectl context is set
        if kubectl config current-context >/dev/null 2>&1; then
            print_status "Cleaning up all Helm releases..."
            if command_exists helm; then
                helm list --all-namespaces -q | xargs -r helm uninstall
                print_status "Waiting for Helm releases to be cleaned up..."
                sleep 30
            fi

            print_status "Cleaning up all namespaces (except system ones)..."
            kubectl get namespaces -o name | grep -v "kube-\|default" | xargs -r kubectl delete --timeout=60s

            print_status "Force cleaning any remaining resources..."
            kubectl delete all --all --all-namespaces --force --grace-period=0 || true
            kubectl delete pvc --all --all-namespaces --force --grace-period=0 || true
            kubectl delete secrets --all --all-namespaces --force --grace-period=0 || true
            kubectl delete configmaps --all --all-namespaces --force --grace-period=0 || true
        else
            print_warning "No kubectl context found. Skipping Kubernetes cleanup."
        fi
    else
        print_warning "kubectl not found. Skipping Kubernetes cleanup."
    fi
}

# Function to clean up local Helm releases
cleanup_helm_local() {
    print_status "Cleaning up local Helm releases..."

    if command_exists helm; then
        # Force cleanup script if it exists
        if [ -f "../scripts/force-cleanup-helm.sh" ]; then
            print_status "Running force Helm cleanup script..."
            bash ../scripts/force-cleanup-helm.sh || true
        fi

        if [ -f "../scripts/quick-helm-cleanup.sh" ]; then
            print_status "Running quick Helm cleanup script..."
            bash ../scripts/quick-helm-cleanup.sh || true
        fi
    fi
}

# Function to disable deletion protection
disable_deletion_protection() {
    print_status "Disabling deletion protection..."

    # Create a temporary terraform file to disable deletion protection
    cat > disable_protection.tf << EOF
# Temporary override to disable deletion protection
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "gcp_project_id" {
  type = string
}

variable "project_name" {
  type = string
  default = "mis-cloud-native"
}

variable "gcp_region" {
  type = string
  default = "us-central1"
}

# Override deletion protection
locals {
  enable_deletion_protection = false
}
EOF

    print_status "Applying deletion protection override..."
    terraform init -upgrade || true
    terraform apply -auto-approve -var="enable_deletion_protection=false" || true

    # Clean up temporary file
    rm -f disable_protection.tf
}

# Function to destroy Terraform infrastructure
destroy_terraform() {
    print_status "Destroying Terraform infrastructure..."

    cd terraform || {
        print_error "Cannot find terraform directory"
        exit 1
    }

    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init -upgrade

    # Disable deletion protection first
    disable_deletion_protection

    # Plan destroy to see what will be destroyed
    print_status "Planning Terraform destroy..."
    terraform plan -destroy

    # Ask for confirmation
    echo
    print_warning "This will destroy ALL cloud resources including:"
    print_warning "- GKE Cluster and node pools"
    print_warning "- Cloud SQL PostgreSQL instance"
    print_warning "- VPC network and subnets"
    print_warning "- Secret Manager secrets"
    print_warning "- Service accounts and IAM bindings"
    print_warning "- All data will be permanently lost!"
    echo
    read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirmation

    if [ "$confirmation" != "yes" ]; then
        print_error "Destruction cancelled by user"
        exit 1
    fi

    # Destroy infrastructure
    print_status "Destroying infrastructure... This may take several minutes..."
    terraform destroy -auto-approve

    if [ $? -eq 0 ]; then
        print_success "Terraform destruction completed successfully"
    else
        print_error "Terraform destruction failed. Some resources may need manual cleanup."
        print_status "Attempting force cleanup..."

        # Try to destroy specific problematic resources
        terraform destroy -auto-approve -target=google_container_cluster.gke || true
        terraform destroy -auto-approve -target=google_sql_database_instance.postgres || true
        terraform destroy -auto-approve -target=google_compute_network.vpc || true

        # Final attempt
        terraform destroy -auto-approve || true
    fi

    # Clean up Terraform state
    print_status "Cleaning up Terraform state..."
    rm -rf .terraform/
    rm -f terraform.tfstate*
    rm -f .terraform.lock.hcl

    cd ..
}

# Function to clean up Docker resources
cleanup_docker() {
    print_status "Cleaning up local Docker resources..."

    if command_exists docker; then
        print_status "Stopping all containers..."
        docker stop $(docker ps -aq) 2>/dev/null || true

        print_status "Removing all containers..."
        docker rm $(docker ps -aq) 2>/dev/null || true

        print_status "Removing all images with project name..."
        docker images | grep "mis-cloud-native\|api-gateway\|cart\|identity\|order\|payment\|product" | awk '{print $3}' | xargs -r docker rmi -f || true

        print_status "Pruning Docker system..."
        docker system prune -af || true
        docker volume prune -f || true
        docker network prune -f || true
    else
        print_warning "Docker not found. Skipping Docker cleanup."
    fi
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local generated files..."

    # Clean up build artifacts
    find services/ -name "target" -type d -exec rm -rf {} + 2>/dev/null || true
    find services/ -name "*.log" -type f -delete 2>/dev/null || true
    find . -name "*.jar" -type f -delete 2>/dev/null || true

    # Clean up any local configuration files
    rm -f kubeconfig
    rm -f .env
    rm -f secrets.yaml

    print_success "Local cleanup completed"
}

# Main execution
main() {
    print_status "Starting complete infrastructure destruction..."
    echo "=============================================="

    check_prerequisites

    # Clean up in order
    cleanup_helm_local
    cleanup_kubernetes
    destroy_terraform
    cleanup_docker
    cleanup_local_files

    echo "=============================================="
    print_success "Complete destruction finished!"
    print_status "Your environment has been reset and is ready for a fresh deployment."
    print_status "Next steps:"
    print_status "1. Update terraform/variables.tf with your GCP project ID"
    print_status "2. Run terraform init in the terraform directory"
    print_status "3. Plan and apply your new infrastructure"
}

# Execute main function
main "$@"
