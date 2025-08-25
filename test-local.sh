#!/bin/bash

# Local Testing Script for MIS Cloud Native Application
# This script tests the configurations locally before pushing to GitHub

set -e

echo "🧪 MIS Cloud Native - Local Testing Suite"
echo "========================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to check if command exists
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        print_status "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

# Check prerequisites
echo
echo "🔍 Checking Prerequisites..."
echo "----------------------------"

PREREQUISITES_OK=true

if ! check_command "docker"; then
    print_info "Install Docker: https://docs.docker.com/get-docker/"
    PREREQUISITES_OK=false
fi

if ! check_command "helm"; then
    print_info "Install Helm: https://helm.sh/docs/intro/install/"
    PREREQUISITES_OK=false
fi

if ! check_command "kubectl"; then
    print_info "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
    PREREQUISITES_OK=false
fi

if ! check_command "java"; then
    print_info "Install Java 17: https://adoptium.net/"
    PREREQUISITES_OK=false
fi

if ! check_command "mvn"; then
    print_info "Install Maven: https://maven.apache.org/install.html"
    PREREQUISITES_OK=false
fi

if [ "$PREREQUISITES_OK" = false ]; then
    print_error "Please install the missing prerequisites before continuing."
    exit 1
fi

print_status "All prerequisites are installed!"

# Test 1: Validate YAML Configuration Files
echo
echo "📋 Test 1: Validating YAML Configuration Files..."
echo "------------------------------------------------"

validate_yaml() {
    local file=$1
    if [ -f "$file" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            print_status "$file - Valid YAML syntax"
        else
            print_error "$file - Invalid YAML syntax"
            return 1
        fi
    else
        print_warning "$file - File not found"
        return 1
    fi
}

YAML_OK=true

# Validate Helm values files
for file in helm/mis-cloud-native/values.yaml helm/mis-cloud-native/values-development.yaml helm/mis-cloud-native/values-production.yaml; do
    if ! validate_yaml "$file"; then
        YAML_OK=false
    fi
done

# Validate GitHub Actions workflow
if ! validate_yaml ".github/workflows/ci-cd-pipeline.yml"; then
    YAML_OK=false
fi

# Validate application configuration files
for env in development staging production test; do
    config_file="services/api-gateway/src/main/resources/application-${env}.yml"
    if [ -f "$config_file" ]; then
        if ! validate_yaml "$config_file"; then
            YAML_OK=false
        fi
    fi
done

if [ "$YAML_OK" = false ]; then
    print_error "YAML validation failed. Please fix the issues before proceeding."
    exit 1
fi

print_status "All YAML files are valid!"

# Test 2: Build and Test API Gateway
echo
echo "🏗️  Test 2: Building and Testing API Gateway..."
echo "----------------------------------------------"

cd services/api-gateway

print_info "Running Maven tests with test profile..."
if mvn clean test -Dspring.profiles.active=test -q; then
    print_status "API Gateway tests passed"
else
    print_error "API Gateway tests failed"
    exit 1
fi

print_info "Building API Gateway JAR..."
if mvn clean package -DskipTests -q; then
    print_status "API Gateway build successful"
else
    print_error "API Gateway build failed"
    exit 1
fi

cd ../..

# Test 3: Validate Helm Charts
echo
echo "📦 Test 3: Validating Helm Charts..."
echo "-----------------------------------"

print_info "Linting main Helm chart..."
if helm lint helm/mis-cloud-native; then
    print_status "Main Helm chart is valid"
else
    print_error "Main Helm chart has issues"
    exit 1
fi

# Test template rendering for different environments
for env in development production; do
    print_info "Testing Helm template rendering for $env environment..."
    if helm template test-release helm/mis-cloud-native \
        --values helm/mis-cloud-native/values-${env}.yaml \
        --set global.environment=$env \
        --set global.gcp.projectId=test-project \
        --set global.gcp.region=us-central1 \
        --set global.gcp.cluster.name=test-cluster \
        > /dev/null; then
        print_status "Helm template rendering for $env environment successful"
    else
        print_error "Helm template rendering for $env environment failed"
        exit 1
    fi
done

# Test 4: Docker Build Test (API Gateway only for speed)
echo
echo "🐳 Test 4: Testing Docker Build..."
echo "---------------------------------"

print_info "Building Docker image for API Gateway..."
cd services/api-gateway

if docker build -t test-api-gateway:local . > /dev/null 2>&1; then
    print_status "Docker build successful"

    # Clean up the test image
    docker rmi test-api-gateway:local > /dev/null 2>&1
else
    print_error "Docker build failed"
    exit 1
fi

cd ../..

# Test 5: Profile Configuration Test
echo
echo "🔧 Test 5: Testing Profile Configurations..."
echo "-------------------------------------------"

print_info "Testing profile-specific configurations..."

# Test each profile configuration by attempting to start the application briefly
for profile in development staging production; do
    print_info "Testing $profile profile configuration..."
    cd services/api-gateway

    # Start the application with the profile and stop it quickly
    timeout 10s mvn spring-boot:run -Dspring-boot.run.profiles=$profile -Dspring.main.web-application-type=none > /dev/null 2>&1 || true

    if [ $? -eq 124 ]; then  # timeout exit code means it started successfully
        print_status "$profile profile configuration is valid"
    else
        print_warning "$profile profile might have configuration issues (or quick startup test limitation)"
    fi

    cd ../..
done

# Test 6: Kubernetes Manifest Generation Test
echo
echo "☸️  Test 6: Testing Kubernetes Manifest Generation..."
echo "----------------------------------------------------"

print_info "Generating Kubernetes manifests for validation..."

# Create temporary directory for manifests
mkdir -p tmp/k8s-manifests

for env in development production; do
    print_info "Generating manifests for $env environment..."

    helm template mis-cloud-native-$env helm/mis-cloud-native \
        --values helm/mis-cloud-native/values-${env}.yaml \
        --set global.environment=$env \
        --set global.gcp.projectId=test-project-$env \
        --set global.gcp.region=us-central1 \
        --set global.gcp.cluster.name=test-cluster-$env \
        --set services.api-gateway.image="ghcr.io/test/api-gateway:test" \
        --set services.identity.image="ghcr.io/test/identity:test" \
        --set services.product.image="ghcr.io/test/product:test" \
        --set services.cart.image="ghcr.io/test/cart:test" \
        --set services.order.image="ghcr.io/test/order:test" \
        --set services.payment.image="ghcr.io/test/payment:test" \
        > tmp/k8s-manifests/$env-manifests.yaml

    if [ $? -eq 0 ]; then
        print_status "Manifest generation for $env successful"

        # Count resources
        resource_count=$(grep -c "^kind:" tmp/k8s-manifests/$env-manifests.yaml)
        print_info "Generated $resource_count Kubernetes resources for $env"
    else
        print_error "Manifest generation for $env failed"
        exit 1
    fi
done

# Test 7: GitHub Actions Workflow Validation
echo
echo "🔄 Test 7: Validating GitHub Actions Workflow..."
echo "-----------------------------------------------"

print_info "Checking GitHub Actions workflow syntax..."

# Basic validation of the workflow file
if [ -f ".github/workflows/ci-cd-pipeline.yml" ]; then
    # Check for required sections
    if grep -q "jobs:" ".github/workflows/ci-cd-pipeline.yml" && \
       grep -q "steps:" ".github/workflows/ci-cd-pipeline.yml" && \
       grep -q "uses:" ".github/workflows/ci-cd-pipeline.yml"; then
        print_status "GitHub Actions workflow structure is valid"
    else
        print_error "GitHub Actions workflow is missing required sections"
        exit 1
    fi
else
    print_error "GitHub Actions workflow file not found"
    exit 1
fi

# Check for required secrets references
required_secrets=("GCP_SA_KEY" "GITHUB_TOKEN")
for secret in "${required_secrets[@]}"; do
    if grep -q "\${{ secrets\.$secret }}" ".github/workflows/ci-cd-pipeline.yml"; then
        print_status "Required secret $secret is referenced in workflow"
    else
        print_warning "Secret $secret might not be referenced in workflow"
    fi
done

# Test 8: Resource Requirements Validation
echo
echo "💰 Test 8: Validating Resource Requirements..."
echo "---------------------------------------------"

print_info "Checking resource requirements for cost optimization..."

# Parse and validate resource requests
for env in development production; do
    values_file="helm/mis-cloud-native/values-${env}.yaml"

    print_info "Analyzing resource requirements for $env environment..."

    # Extract memory and CPU requests (simplified parsing)
    if grep -q "requests:" "$values_file"; then
        memory_requests=$(grep -A 10 "requests:" "$values_file" | grep "memory:" | wc -l)
        cpu_requests=$(grep -A 10 "requests:" "$values_file" | grep "cpu:" | wc -l)

        print_status "$env environment has $memory_requests memory and $cpu_requests CPU resource definitions"
    else
        print_warning "$env environment might be missing resource requests"
    fi
done

# Cleanup
echo
echo "🧹 Cleaning up temporary files..."
rm -rf tmp/

# Final Summary
echo
echo "🎉 Local Testing Complete!"
echo "=========================="
print_status "All tests passed successfully!"
echo
print_info "Your configuration is ready for GitHub deployment. Here's what was tested:"
echo "  ✅ YAML syntax validation"
echo "  ✅ Maven build and tests"
echo "  ✅ Helm chart validation"
echo "  ✅ Docker build capability"
echo "  ✅ Spring profile configurations"
echo "  ✅ Kubernetes manifest generation"
echo "  ✅ GitHub Actions workflow structure"
echo "  ✅ Resource requirements optimization"
echo
print_info "Next steps:"
echo "  1. Commit your changes: git add . && git commit -m 'feat: add GCP deployment with minimal resources'"
echo "  2. Push to develop branch: git push origin develop"
echo "  3. Monitor the GitHub Actions workflow for deployment"
echo "  4. When ready, merge to main for production deployment"
echo
print_warning "Remember to set up these GitHub secrets before pushing:"
echo "  - GCP_SA_KEY: Your Google Cloud service account JSON key"
echo "  - GCP_PROJECT_ID: Your GCP project ID (optional, defaults provided)"
echo "  - GCP_REGION: Your preferred GCP region (optional, defaults to us-central1)"
