# Terraform Bootstrap for Remote State (GCS)

This folder creates a Google Cloud Storage bucket to be used as the Terraform remote state backend for the infrastructure in `../`.

Important: Terraform cannot create its own backend resource in the same configuration that uses it. Therefore, this bootstrap runs with local state, creates the bucket, and outputs its name. Then you configure the backend in `../` to point at that bucket and re-initialize Terraform.

## Prerequisites
- Terraform >= 1.5
- gcloud authenticated and project set or provide credentials via environment
- Project billing enabled
- API: `storage.googleapis.com` (usually enabled by default)

## Usage

1. Set variables:

```bash
export TF_VAR_gcp_project_id="<YOUR_GCP_PROJECT_ID>"
# Optional overrides
export TF_VAR_bucket_location="US"  # or specific region like us-central1
# export TF_VAR_bucket_name="your-unique-tfstate-bucket"  # if you want a fixed name
```

2. Initialize and apply:

```bash
terraform -chdir=. init
terraform -chdir=. apply -auto-approve
```

3. Capture output bucket name:

```bash
TF_STATE_BUCKET=$(terraform -chdir=. output -raw tf_state_bucket_name)
echo "Created bucket: ${TF_STATE_BUCKET}"
```

4. Configure the main Terraform to use GCS backend:
   - Copy `../backend.tf.example` to `../backend.tf`
   - Edit it to set `bucket = "${TF_STATE_BUCKET}"` if it is not already set.

5. Initialize the main Terraform and migrate state (if you had local state previously):

```bash
cd ..
terraform init -migrate-state
```

From now on, your state is stored in the GCS bucket.

## Clean up
If you ever need to remove the bucket, set `force_destroy=true` and apply, or empty the bucket manually before `terraform destroy`.
