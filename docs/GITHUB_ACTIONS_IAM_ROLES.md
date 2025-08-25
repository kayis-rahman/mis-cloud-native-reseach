# GitHub Actions Service Account - Required IAM Roles

## Overview
This document lists all the IAM roles required for the GitHub Actions service account (`github-actions@***.iam.gserviceaccount.com`) to successfully deploy the entire cloud-native microservices infrastructure using Terraform.

## Essential IAM Roles

### 1. **Terraform State Management**
```bash
roles/storage.objectAdmin
```
- **Purpose**: Access to Google Cloud Storage bucket for Terraform state
- **Permissions**: `storage.objects.list`, `storage.objects.get`, `storage.objects.create`, `storage.objects.update`, `storage.objects.delete`
- **Why needed**: Terraform backend uses GCS bucket `tfstate-mis-cloud-native-research-ac98`

### 2. **Project and Service Management**
```bash
roles/serviceusage.serviceUsageAdmin
roles/resourcemanager.projectEditor
```
- **Purpose**: Enable/disable APIs and manage project resources
- **APIs managed**: Container, Compute, IAM, Cloud SQL, Artifact Registry, Secret Manager
- **Why needed**: Terraform needs to enable required GCP APIs

### 3. **Compute Engine and Networking**
```bash
roles/compute.admin
roles/compute.networkAdmin
```
- **Purpose**: Create VPCs, subnets, firewall rules, and compute resources
- **Resources**: VPC networks, subnets, firewall rules, load balancers
- **Why needed**: Infrastructure foundation for GKE and networking

### 4. **Google Kubernetes Engine (GKE)**
```bash
roles/container.admin
roles/container.clusterAdmin
```
- **Purpose**: Create and manage GKE clusters and node pools
- **Resources**: GKE clusters, node pools, cluster configurations
- **Why needed**: Core Kubernetes infrastructure for microservices

### 5. **Identity and Access Management**
```bash
roles/iam.serviceAccountAdmin
roles/iam.roleAdmin
roles/iam.securityAdmin
```
- **Purpose**: Create service accounts and manage IAM bindings
- **Resources**: Service accounts for GKE nodes, IAM role bindings
- **Why needed**: Security and access control for all resources

### 6. **Cloud SQL Database**
```bash
roles/cloudsql.admin
```
- **Purpose**: Create and manage Cloud SQL PostgreSQL instances
- **Resources**: PostgreSQL databases, users, connections
- **Why needed**: Database infrastructure for microservices

### 7. **Secret Manager**
```bash
roles/secretmanager.admin
```
- **Purpose**: Create and manage secrets for database passwords and tokens
- **Resources**: Database passwords, GHCR tokens, API keys
- **Why needed**: Secure credential management

### 8. **Artifact Registry**
```bash
roles/artifactregistry.admin
```
- **Purpose**: Manage container image repositories
- **Resources**: Docker repositories for microservice images
- **Why needed**: Container image storage and management

### 9. **Monitoring and Logging**
```bash
roles/monitoring.editor
roles/logging.admin
```
- **Purpose**: Set up observability stack
- **Resources**: Monitoring dashboards, log sinks, alerts
- **Why needed**: Observability and monitoring infrastructure

## Complete gcloud Command

To assign all required roles to your GitHub Actions service account, run:

```bash
# Set variables
export PROJECT_ID="mis-research-cloud-native"
export SA_EMAIL="github-actions@${PROJECT_ID}.iam.gserviceaccount.com"

# Core infrastructure roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.objectAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/serviceusage.serviceUsageAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/resourcemanager.projectEditor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/compute.networkAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/container.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/container.clusterAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/iam.roleAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/iam.securityAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/cloudsql.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/secretmanager.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/monitoring.editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/logging.admin"
```

## Alternative: Using a Single Broad Role (Not Recommended for Production)

For development/testing purposes only, you could use:
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/iam.serviceAccountAdmin"
```

## Verification Commands

To verify the service account has the required permissions:

```bash
# List all IAM bindings for the service account
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --format="table(bindings.role)" \
    --filter="bindings.members:$SA_EMAIL"

# Test specific bucket access
gsutil ls gs://tfstate-mis-cloud-native-research-ac98/ || echo "No bucket access"
```

## Security Best Practices

1. **Principle of Least Privilege**: In production, consider using more granular custom roles instead of broad predefined roles
2. **Conditional IAM**: Use IAM conditions to restrict access by time, IP, or other factors
3. **Regular Audits**: Periodically review and audit service account permissions
4. **Key Rotation**: Regularly rotate service account keys

## Troubleshooting Common Permission Issues

### Storage Backend Access Error
```
Error: storage.objects.list access denied
```
**Solution**: Ensure `roles/storage.objectAdmin` is assigned

### API Enablement Error
```
Error: API not enabled
```
**Solution**: Ensure `roles/serviceusage.serviceUsageAdmin` is assigned

### GKE Creation Error
```
Error: Insufficient permissions for container.clusters.create
```
**Solution**: Ensure `roles/container.admin` is assigned

### IAM Binding Error
```
Error: Permission 'iam.serviceAccounts.create' denied
```
**Solution**: Ensure `roles/iam.serviceAccountAdmin` is assigned
