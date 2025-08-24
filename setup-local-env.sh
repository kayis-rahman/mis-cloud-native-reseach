#!/usr/bin/env bash
# Quick setup for local infrastructure testing
# Edit the values below with your actual GCP project details

# REQUIRED: Replace with your actual GCP Project ID
export TF_VAR_gcp_project_id="my-gcp-project-123"

# OPTIONAL: Customize these if needed
export TF_VAR_gcp_region="us-central1"
export TF_VAR_gcp_zone="us-central1-a"

# For create_secrets.sh (if you run it)
export GHCR_OWNER="your-github-username"
export GHCR_TOKEN="your-github-pat"
export GHCR_TOKEN_SECRET_ID="ghcr-pat"

echo "✅ Environment variables set for infrastructure scripts"
echo "📝 Edit setup-local-env.sh to customize values"
echo ""
echo "Next steps:"
echo "  1. gcloud auth login                    # Authenticate with GCP"
echo "  2. gcloud auth application-default login # Set default credentials"
echo "  3. ./scripts/create_infra.sh            # Run infrastructure creation"
