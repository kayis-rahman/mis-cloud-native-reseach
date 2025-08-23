# Terraform for GCP GKE and Dependencies

This Terraform configuration provisions the following on GCP:

- VPC network and subnetwork with secondary ranges for GKE Pods and Services
- Regional GKE cluster with a primary node pool
- Cloud SQL for PostgreSQL instance, database, and user
- Optionally, initial Helm releases to bootstrap services using the repo's shared Helm chart

## Prerequisites

- Terraform >= 1.5
- A GCP project and billing enabled
- The following APIs enabled (enabled automatically by this config):
  - container.googleapis.com
  - compute.googleapis.com
  - iam.googleapis.com
  - cloudresourcemanager.googleapis.com
  - sqladmin.googleapis.com
  - artifactregistry.googleapis.com

## Inputs

See `variables.tf` for all variables. Key ones:

- `gcp_project_id` (string, required)
- `gcp_region` (string, default: us-central1)
- `gcp_zone` (string, default: us-central1-a)
- `db_password` (string, optional; if not provided, a random password is generated)
- `create_initial_helm` (bool, default: true) — set to false when bootstrapping infra-only
- `global_image_registry` (string) — set to `ghcr.io/OWNER` to prefix images
- `service_images` (map) — service->image mapping (repository:tag)
- `enable_deletion_protection` (bool, default: true) — protects GKE cluster and Cloud SQL from accidental deletion. Set to false before `terraform destroy`. 

## Providers

Providers for google, kubernetes, and helm are configured automatically to target the newly created GKE cluster.

## Remote State (GCS)

For collaboration and CI, store Terraform state in a Google Cloud Storage (GCS) bucket. This repository includes a bootstrap to create a bucket safely, and a backend template to configure the main Terraform to use it.

### 1) Create the state bucket (bootstrap)

```
cd bootstrap
export TF_VAR_gcp_project_id="<YOUR_GCP_PROJECT_ID>"
# Optional overrides:
# export TF_VAR_bucket_location="US"        # or a specific region like us-central1
# export TF_VAR_bucket_name="my-unique-tf-bucket"  # supply your own globally-unique name

terraform init
terraform apply -auto-approve

TF_STATE_BUCKET=$(terraform output -raw tf_state_bucket_name)
echo "State bucket: ${TF_STATE_BUCKET}"
```

### 2) Configure the backend in main Terraform

Copy the example file and set the bucket name:

```
cp backend.tf.example backend.tf
# Edit backend.tf and set: bucket = "${TF_STATE_BUCKET}" (from previous step)
```

Then initialize and migrate state (if you had local state previously):

```
terraform init -migrate-state
```

From now on, Terraform state will be stored in GCS.

## Usage

```
export TF_VAR_gcp_project_id=your-project-id
export TF_VAR_gcp_region=us-central1
export TF_VAR_gcp_zone=us-central1-a
# Optional: keep resources safe from deletion (default is true)
export TF_VAR_enable_deletion_protection=true

terraform init
terraform plan
terraform apply
```

### Destroy everything (safe)
Option A — Use the helper script (recommended):
```
# From repo root
scripts/destroy_all.sh
```
The script will:
- Ask you to type the project id to confirm the destructive action.
- Run `terraform apply` with `TF_VAR_enable_deletion_protection=false` to disable protection.
- Run `terraform destroy` to remove all resources managed by this stack.

Option B — Manual commands:
```
export TF_VAR_enable_deletion_protection=false
terraform apply -auto-approve   # updates resources to disable protection
terraform destroy -auto-approve
```

Note: Terraform will not disable GCP project APIs on destroy (we set disable_on_destroy=false). This avoids dependency errors like compute.googleapis.com being required by container.googleapis.com. If you want to disable APIs after destroying infra, do so manually with gcloud, e.g.:
```
gcloud services disable container.googleapis.com --project "$PROJECT_ID" --force
gcloud services disable compute.googleapis.com --project "$PROJECT_ID" --force
```
Where --force implies disabling dependent services too.

Once applied, connect to the cluster:

```
gcloud container clusters get-credentials mis-cloud-native-gke --region us-central1 --project your-project-id

helm upgrade --install product ../helm/mis-cloud-native \
  --set services.product.enabled=true \
  --set services.product.image=ghcr.io/OWNER/product:TAG
```

## Outputs

- `cluster_name`, `cluster_endpoint`
- `cluster_location`, `project_id`
- `db_connection_name`, `db_public_ip`, `db_credentials` (sensitive)

## Validation

After terraform apply, validate your deployment:

1. Ensure gcloud is authenticated and project is set:
   - gcloud auth login
   - gcloud config set project <YOUR_PROJECT_ID>
2. Fetch kubeconfig for the cluster:
   - gcloud container clusters get-credentials $(terraform output -raw cluster_name) \
     --region $(terraform output -raw cluster_location) \
     --project $(terraform output -raw project_id)
3. Run the validation script to verify APIs, cluster reachability, workloads, and optional Cloud SQL:
   - bash ../scripts/validate_gcp_deployment.sh \
     --project $(terraform output -raw project_id) \
     --location $(terraform output -raw cluster_location) \
     --cluster $(terraform output -raw cluster_name)

The script requires: gcloud, terraform, kubectl, helm, jq.

## GitHub CI/CD

Two workflows are provided under `.github/workflows`:

- `terraform.yml`: validates, plans, and on manual dispatch applies Terraform.
  - Requires repository secrets:
    - `GCP_WORKLOAD_IDENTITY_PROVIDER`
    - `GCP_SERVICE_ACCOUNT`
  - Requires repository variables:
    - `GCP_PROJECT_ID`
    - optional: `GCP_REGION`, `GCP_ZONE`

- `deploy-service.yml`: on service or chart changes, builds/pushes images to GHCR and deploys the corresponding service to GKE with Helm.
  - Requires the same GCP auth secrets as above and variables:
    - `GCP_PROJECT_ID`
    - `GKE_CLUSTER_NAME` (defaults to `mis-cloud-native-gke` if not set)
    - `GKE_LOCATION` (defaults to `GCP_REGION` or `us-central1`)

Note: You can switch to Artifact Registry images by changing the login/push and the Helm image value in the workflow.
