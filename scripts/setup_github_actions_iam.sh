#!/usr/bin/env bash
set -euo pipefail

# Setup GitHub Actions Service Account IAM Roles
# This script assigns all required IAM roles for the GitHub Actions service account
# to successfully deploy the cloud-native microservices infrastructure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="mis-research-cloud-native"
SA_NAME="github-actions"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Required IAM roles for GitHub Actions service account
REQUIRED_ROLES=(
    "roles/storage.objectAdmin"              # Terraform state management
    "roles/serviceusage.serviceUsageAdmin"   # Enable/disable APIs
    "roles/resourcemanager.projectEditor"    # Project resource management
    "roles/compute.admin"                    # VPCs, networking, compute
    "roles/compute.networkAdmin"             # Network security, firewall
    "roles/container.admin"                  # GKE cluster management
    "roles/container.clusterAdmin"           # Advanced GKE operations
    "roles/iam.serviceAccountAdmin"          # Create/manage service accounts
    "roles/iam.roleAdmin"                    # Manage IAM role bindings
    "roles/iam.securityAdmin"                # Security policy management
    "roles/cloudsql.admin"                   # PostgreSQL database management
    "roles/secretmanager.admin"              # Secure credential storage
    "roles/artifactregistry.admin"           # Container image repositories
    "roles/monitoring.editor"                # Monitoring and logging
    "roles/logging.admin"                    # Advanced logging management
)

echo -e "${BLUE}=== GitHub Actions Service Account IAM Setup ===${NC}"
echo -e "${YELLOW}Project ID: ${PROJECT_ID}${NC}"
echo -e "${YELLOW}Service Account: ${SA_EMAIL}${NC}"
echo ""

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${RED}❌ Error: gcloud is not authenticated${NC}"
    echo -e "${YELLOW}Please run: gcloud auth login${NC}"
    exit 1
fi

# Check if the project exists and is accessible
echo -e "${BLUE}🔍 Checking project access...${NC}"
if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Cannot access project '$PROJECT_ID'${NC}"
    echo -e "${YELLOW}Please ensure:${NC}"
    echo -e "${YELLOW}  1. The project exists${NC}"
    echo -e "${YELLOW}  2. You have permission to access it${NC}"
    echo -e "${YELLOW}  3. You're authenticated with the correct account${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Project access confirmed${NC}"

# Check if service account exists
echo -e "${BLUE}🔍 Checking if service account exists...${NC}"
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Service account '$SA_EMAIL' does not exist${NC}"
    echo -e "${BLUE}🔧 Creating service account...${NC}"

    gcloud iam service-accounts create "$SA_NAME" \
        --project="$PROJECT_ID" \
        --display-name="GitHub Actions CI/CD" \
        --description="Service account for GitHub Actions CI/CD pipeline"

    echo -e "${GREEN}✅ Service account created successfully${NC}"
else
    echo -e "${GREEN}✅ Service account already exists${NC}"
fi

# Get current roles for the service account
echo -e "${BLUE}🔍 Checking current IAM bindings...${NC}"
CURRENT_ROLES=$(gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --format="value(bindings.role)" \
    --filter="bindings.members:serviceAccount:$SA_EMAIL" 2>/dev/null || echo "")

echo -e "${YELLOW}Current roles assigned:${NC}"
if [ -z "$CURRENT_ROLES" ]; then
    echo -e "${YELLOW}  (none)${NC}"
else
    echo "$CURRENT_ROLES" | while read -r role; do
        echo -e "${YELLOW}  - $role${NC}"
    done
fi
echo ""

# Assign required roles
echo -e "${BLUE}🔧 Assigning required IAM roles...${NC}"
ASSIGNED_COUNT=0
SKIPPED_COUNT=0

for role in "${REQUIRED_ROLES[@]}"; do
    echo -n "  Checking $role... "

    # Check if role is already assigned
    if echo "$CURRENT_ROLES" | grep -q "^$role$"; then
        echo -e "${YELLOW}already assigned${NC}"
        ((SKIPPED_COUNT++))
    else
        # Assign the role
        if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$role" \
            --quiet >/dev/null 2>&1; then
            echo -e "${GREEN}assigned${NC}"
            ((ASSIGNED_COUNT++))
        else
            echo -e "${RED}failed${NC}"
            echo -e "${RED}    ❌ Failed to assign $role${NC}"
        fi
    fi
done

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "${GREEN}✅ Roles assigned: $ASSIGNED_COUNT${NC}"
echo -e "${YELLOW}⏭️  Roles already present: $SKIPPED_COUNT${NC}"
echo -e "${BLUE}📋 Total required roles: ${#REQUIRED_ROLES[@]}${NC}"

# Verify all roles are assigned
echo ""
echo -e "${BLUE}🔍 Verifying final role assignments...${NC}"
FINAL_ROLES=$(gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --format="value(bindings.role)" \
    --filter="bindings.members:serviceAccount:$SA_EMAIL")

MISSING_ROLES=()
for role in "${REQUIRED_ROLES[@]}"; do
    if ! echo "$FINAL_ROLES" | grep -q "^$role$"; then
        MISSING_ROLES+=("$role")
    fi
done

if [ ${#MISSING_ROLES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All required roles are successfully assigned!${NC}"
    echo ""
    echo -e "${BLUE}🔑 Service account is ready for GitHub Actions CI/CD${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "${YELLOW}  1. Generate a service account key${NC}"
    echo -e "${YELLOW}  2. Add the key to GitHub repository secrets as 'GCP_SA_KEY'${NC}"
    echo -e "${YELLOW}  3. Update the 'GCP_PROJECT' secret to '$PROJECT_ID'${NC}"
else
    echo -e "${RED}❌ Some roles are still missing:${NC}"
    for role in "${MISSING_ROLES[@]}"; do
        echo -e "${RED}  - $role${NC}"
    done
    echo ""
    echo -e "${YELLOW}Please check your permissions and try again${NC}"
    exit 1
fi

# Test critical permissions
echo ""
echo -e "${BLUE}🧪 Testing critical permissions...${NC}"

# Test storage access for Terraform state
echo -n "  Testing Cloud Storage access... "
if gsutil ls "gs://tfstate-mis-cloud-native-research-ac98/" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ accessible${NC}"
else
    echo -e "${YELLOW}⚠️  bucket not accessible (may not exist yet)${NC}"
fi

# Test project access
echo -n "  Testing project resource access... "
if gcloud compute regions list --project="$PROJECT_ID" --limit=1 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ accessible${NC}"
else
    echo -e "${RED}❌ failed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 GitHub Actions service account setup complete!${NC}"
echo -e "${BLUE}The service account '$SA_EMAIL' is now ready for CI/CD deployment.${NC}"
