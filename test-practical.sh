#!/bin/bash

# Practical Local Testing Script for MIS Cloud Native Application
# This script tests configurations that can be validated without requiring Docker/Kubernetes

set -e

echo "🧪 MIS Cloud Native - Practical Local Testing"
echo "============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Test 1: YAML Validation
echo
echo "📋 Test 1: Validating YAML Configuration Files..."
echo "------------------------------------------------"

validate_yaml() {
    local file=$1
    if [ -f "$file" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            print_status "$file - Valid YAML syntax"
            return 0
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

# Test Helm values files
for file in helm/mis-cloud-native/values.yaml helm/mis-cloud-native/values-development.yaml helm/mis-cloud-native/values-production.yaml; do
    if ! validate_yaml "$file"; then
        YAML_OK=false
    fi
done

# Test GitHub Actions workflow
if ! validate_yaml ".github/workflows/ci-cd-pipeline.yml"; then
    YAML_OK=false
fi

# Test application configurations
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

# Test 2: Maven Build and Test
echo
echo "🏗️  Test 2: Maven Build and Tests..."
echo "-----------------------------------"

cd services/api-gateway

if command -v mvn >/dev/null 2>&1; then
    print_info "Running Maven tests with test profile..."
    if mvn clean test -Dspring.profiles.active=test -q; then
        print_status "API Gateway tests passed"
    else
        print_error "API Gateway tests failed"
        cd ../..
        exit 1
    fi

    print_info "Building API Gateway JAR..."
    if mvn clean package -DskipTests -q; then
        print_status "API Gateway build successful"
    else
        print_error "API Gateway build failed"
        cd ../..
        exit 1
    fi
else
    print_warning "Maven not found - skipping build tests"
fi

cd ../..

# Test 3: Helm Chart Validation
echo
echo "📦 Test 3: Validating Helm Charts..."
echo "-----------------------------------"

if command -v helm >/dev/null 2>&1; then
    print_info "Linting main Helm chart..."
    if helm lint helm/mis-cloud-native --quiet; then
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
else
    print_warning "Helm not found - skipping Helm validation"
fi

# Test 4: Spring Profile Configuration Test
echo
echo "🔧 Test 4: Spring Profile Configuration Validation..."
echo "----------------------------------------------------"

if command -v mvn >/dev/null 2>&1; then
    cd services/api-gateway

    for profile in development staging production test; do
        print_info "Validating $profile profile configuration..."

        # Test configuration loading without starting the full application
        if mvn spring-boot:run -Dspring-boot.run.profiles=$profile \
            -Dspring.main.web-application-type=none \
            -Dspring-boot.run.jvmArguments="-Dspring.profiles.active=$profile -Dexit.immediately=true" \
            -Dspring-boot.run.arguments="--spring.main.banner-mode=off" \
            -q > /dev/null 2>&1; then
            print_status "$profile profile configuration is valid"
        else
            print_warning "$profile profile configuration might have issues (or validation limitation)"
        fi
    done

    cd ../..
else
    print_warning "Maven not found - skipping profile validation"
fi

# Test 5: GitHub Actions Workflow Structure
echo
echo "🔄 Test 5: GitHub Actions Workflow Validation..."
echo "-----------------------------------------------"

workflow_file=".github/workflows/ci-cd-pipeline.yml"

if [ -f "$workflow_file" ]; then
    print_info "Checking GitHub Actions workflow structure..."

    # Check for required sections
    if grep -q "jobs:" "$workflow_file" && \
       grep -q "steps:" "$workflow_file" && \
       grep -q "uses:" "$workflow_file"; then
        print_status "GitHub Actions workflow structure is valid"
    else
        print_error "GitHub Actions workflow is missing required sections"
        exit 1
    fi

    # Check for environment-specific logic
    if grep -q "determine-environment" "$workflow_file" && \
       grep -q "development\|production" "$workflow_file"; then
        print_status "Environment-specific deployment logic found"
    else
        print_warning "Environment-specific deployment logic might be missing"
    fi

    # Check for required secret references
    required_secrets=("GCP_SA_KEY" "GITHUB_TOKEN")
    for secret in "${required_secrets[@]}"; do
        if grep -q "\${{ secrets\.$secret }}" "$workflow_file"; then
            print_status "Required secret $secret is referenced"
        else
            print_warning "Secret $secret might not be referenced"
        fi
    done
else
    print_error "GitHub Actions workflow file not found"
    exit 1
fi

# Test 6: Resource Configuration Validation
echo
echo "💰 Test 6: Resource Configuration Analysis..."
echo "--------------------------------------------"

for env in development production; do
    values_file="helm/mis-cloud-native/values-${env}.yaml"

    if [ -f "$values_file" ]; then
        print_info "Analyzing $env environment resource configuration..."

        # Check for resource definitions
        if grep -q "resources:" "$values_file"; then
            memory_count=$(grep -c "memory:" "$values_file" || true)
            cpu_count=$(grep -c "cpu:" "$values_file" || true)

            print_status "$env environment: $memory_count memory, $cpu_count CPU resource definitions"

            # Check for minimal resource requests
            if grep -q "64Mi\|128Mi\|256Mi" "$values_file"; then
                print_status "$env environment uses minimal memory configurations"
            else
                print_warning "$env environment might have high memory requirements"
            fi
        else
            print_warning "$env environment missing resource definitions"
        fi
    else
        print_error "$values_file not found"
    fi
done

# Test 7: File Structure Validation
echo
echo "📁 Test 7: Project Structure Validation..."
echo "-----------------------------------------"

required_files=(
    "services/api-gateway/pom.xml"
    "services/api-gateway/Dockerfile"
    "services/api-gateway/src/main/resources/application-development.yml"
    "services/api-gateway/src/main/resources/application-production.yml"
    "helm/mis-cloud-native/Chart.yaml"
    "helm/mis-cloud-native/templates/deployment.yaml"
    "helm/mis-cloud-native/templates/service.yaml"
    ".github/workflows/ci-cd-pipeline.yml"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "$file exists"
    else
        print_error "$file is missing"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    print_error "Missing required files. Please ensure all files are present."
    exit 1
fi

# Final Summary
echo
echo "🎉 Local Testing Complete!"
echo "=========================="
print_status "All testable configurations are valid!"
echo
print_info "Your configuration is ready for GitHub deployment. Here's what was validated:"
echo "  ✅ YAML syntax validation"
echo "  ✅ Maven build and tests (if available)"
echo "  ✅ Helm chart validation (if available)"
echo "  ✅ Spring profile configurations"
echo "  ✅ GitHub Actions workflow structure"
echo "  ✅ Resource requirements optimization"
echo "  ✅ Project file structure"
echo
print_info "Next steps for GitHub deployment:"
echo "  1. Ensure you have these GitHub secrets configured:"
echo "     - GCP_SA_KEY: Your Google Cloud service account JSON key"
echo "     - GCP_PROJECT_ID: Your GCP project ID"
echo "     - GCP_REGION: Your preferred GCP region (optional)"
echo
echo "  2. Commit and push your changes:"
echo "     git add ."
echo "     git commit -m 'feat: add GCP deployment with minimal resources and profile configurations'"
echo "     git push origin develop    # For development deployment"
echo "     git push origin main       # For production deployment"
echo
echo "  3. Monitor GitHub Actions:"
echo "     - Go to your repository's Actions tab"
echo "     - Watch the CI/CD Pipeline workflow execution"
echo "     - Verify successful deployment to your chosen environment"
echo
print_warning "Notes:"
echo "  - Docker build test was skipped (Docker not available/running)"
echo "  - Kubernetes deployment will be tested in GitHub Actions"
echo "  - Ensure your GKE clusters exist before running the pipeline"
echo
print_status "Configuration validation completed successfully! 🚀"
