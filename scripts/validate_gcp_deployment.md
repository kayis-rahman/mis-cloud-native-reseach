# GCP/GKE Deployment Validation Guide

This guide walks you through validating the infrastructure and deployment pipeline provided in this repository. Follow it sequentially. Copy and paste commands as needed.

Prerequisites
- You have a GCP project with billing enabled.
- You have Owner or sufficient roles to provision GKE, VPC, and Cloud SQL.
- You have the Google Cloud SDK (gcloud) and kubectl installed locally, or you will use GitHub Actions to apply Terraform.
- Terraform >= 1.5 installed locally (if applying locally).

Repo paths
- Terraform: ./terraform
- Helm chart: ./helm/mis-cloud-native
- Services: ./services/*
- CI workflows: ./.github/workflows

Step 0 — Collect inputs
- GCP Project ID: YOUR_PROJECT_ID
- Region: us-central1 (or your choice)
- Zone: us-central1-a (or your choice)

Decide how to apply Terraform
- Option A: Local (faster for first-time validation)
- Option B: GitHub Actions (uses Workload Identity Federation)

Step 1 — Configure GitHub (for CI and/or deploy-service)
1. In your GitHub repository settings:
   - Secrets:
     - GCP_WORKLOAD_IDENTITY_PROVIDER: resource name of the OIDC provider (e.g., projects/123456789/locations/global/workloadIdentityPools/pool/providers/provider)
     - GCP_SERVICE_ACCOUNT: service-account@YOUR_PROJECT_ID.iam.gserviceaccount.com
   - Variables:
     - GCP_PROJECT_ID: YOUR_PROJECT_ID
     - (optional) GCP_REGION: us-central1
     - (optional) GCP_ZONE: us-central1-a
     - (optional) GKE_CLUSTER_NAME: mis-cloud-native-gke
     - (optional) GKE_LOCATION: us-central1
2. Ensure the service account has roles to manage GKE, VPC, and SQL (e.g., roles/container.admin, roles/compute.networkAdmin, roles/sql.admin, roles/iam.workloadIdentityUser on the pool binding). Refer to GCP docs for WIF setup.

Step 2 — Local Terraform validation (safe to run even if you plan to apply via CI)
1. cd terraform
2. Export variables:
   - export TF_VAR_gcp_project_id=YOUR_PROJECT_ID
   - export TF_VAR_gcp_region=us-central1
   - export TF_VAR_gcp_zone=us-central1-a
   - Optionally set: export TF_VAR_create_initial_helm=false (to deploy infra only first)
3. Initialize and validate:
   - terraform init
   - terraform fmt -check
   - terraform validate
4. Preview plan (non-destructive):
   - terraform plan

Step 3 — Apply Terraform (choose A or B)
Option A — Apply locally
- terraform apply -auto-approve

Option B — Apply via GitHub Actions
- Go to Actions -> Terraform GKE and Dependencies -> Run workflow
- Monitor the run; it will authenticate with GCP via WIF and apply

Step 4 — Configure kubectl for the new cluster
1. Authenticate locally (requires you have gcloud auth):
   - gcloud auth login
   - gcloud config set project YOUR_PROJECT_ID
2. Fetch credentials (use your region):
   - gcloud container clusters get-credentials mis-cloud-native-gke --region us-central1 --project YOUR_PROJECT_ID
3. Test access:
   - kubectl get nodes -o wide
   - kubectl get pods -A

Step 5 — Run Kubernetes sanity checks
1. Make the helper script executable:
   - chmod +x ./scripts/k8s_sanity_check.sh
2. Run it:
   - ./scripts/k8s_sanity_check.sh
3. Confirm it reports Ready nodes, core system pods Running, and Helm is available.

Step 6 — Validate Cloud SQL
1. From Terraform outputs (local apply):
   - terraform output
   - Note db_public_ip, db_connection_name, and db_credentials (sensitive) if needed.
2. In Cloud Console -> SQL -> Instances, verify the instance exists, is RUNNABLE, and the database/user created.
3. (Optional) Connect via psql (public IP must be enabled; this config enables it):
   - psql "host=$(terraform output -raw db_public_ip) user=misadmin dbname=misdb password=..."

Step 7 — Deploy a service using Helm (local)
Option A — Use an image you already have
- helm upgrade --install product ./helm/mis-cloud-native \
  --namespace default \
  --set services.product.enabled=true \
  --set services.product.image=ghcr.io/OWNER/product:TAG

Option B — Use GitHub Actions to build and deploy
- Push changes under services/product or trigger the workflow manually:
  - Actions -> Build and Deploy Services to GKE via Helm -> Run workflow
- The workflow builds the image, pushes to GHCR, and runs helm upgrade --install for the service

Step 8 — Verify the deployed service
1. Check deployment and pod:
   - kubectl get deploy,po,svc | egrep "product|NAME"
2. Port-forward for a quick test:
   - kubectl port-forward deploy/product 8080:8080
   - In another terminal: curl -i http://localhost:8080/actuator/health
3. If using Ingress (set global.ingress.enabled=true and hosts):
   - helm upgrade --install gateway ./helm/mis-cloud-native \
     --set global.ingress.enabled=true \
     --set global.ingress.hosts={your.domain} \
     --set services.product.enabled=true \
     --set services.product.image=ghcr.io/OWNER/product:TAG
   - Verify: kubectl get ingress

Step 9 — Common troubleshooting
- Providers fail at plan: ensure APIs are enabled and your auth has permissions.
- kubectl cannot connect: re-run gcloud get-credentials with correct region; check network egress/firewall policies.
- Pods Pending: check node pool Ready status and resource requests; describe the pod: kubectl describe po/<name>.
- Helm release fails: run helm template ./helm/mis-cloud-native with the flags you used to catch render errors.
- Cloud SQL connectivity from cluster: this setup exposes public IP; for private IP or proxy, additional configuration is required.

Step 10 — Clean up
- terraform destroy

Notes
- For team usage, configure a GCS backend (see terraform/README.md).
- To pin images per service via Terraform bootstrap, set TF_VAR_global_image_registry and TF_VAR_service_images.
