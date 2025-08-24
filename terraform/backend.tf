# Copy this file to backend.tf and set the bucket name to the GCS bucket
# created by terraform/bootstrap. You may also adjust the prefix if desired.

terraform {
  backend "gcs" {
    # REQUIRED: update with your actual bucket name
    bucket = "tfstate-mis-cloud-native-research-ac98"

    # Optional path/prefix where state files will live in the bucket
    prefix = "mis-cloud-native/terraform/state"
  }
}
