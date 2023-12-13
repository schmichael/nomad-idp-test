# Workload Identity Pool
resource "google_iam_workload_identity_pool" "nomad" {
  # GCP seems to dislike reusing workload identity pool names, so use a random
  # name every time.
  workload_identity_pool_id = "nomad-pool-${random_pet.main.id}"
}

# Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "nomad_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.nomad.workload_identity_pool_id
  workload_identity_pool_provider_id = "nomad-provider"
  display_name                       = "Nomad Provider"
  description                        = "OIDC identity pool provider"
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }
  oidc {
    allowed_audiences = ["gcp"]
    issuer_uri        = local.issuer_uri
  }
}

# Service Account which Nomad Workload Identities will map to.
resource "google_service_account" "nomad" {
  account_id   = "nomad-wid"
  display_name = "Nomad Workload Identity Service Account"
}

resource "google_service_account_iam_binding" "nomad" {
  service_account_id = google_service_account.nomad.name

  role = "roles/iam.workloadIdentityUser"

  members = [
    #FIXME google_workload_identity_pool seems to lack an attribute for the
    #      principal, so string format it manually to look like:
    #principal://iam.googleapis.com/projects/PROJECT_NUM/locations/global/workloadIdentityPools/POOL_NAME/subject/SUBJECT_MAPPING
    "principal://iam.googleapis.com/${google_iam_workload_identity_pool.nomad.name}/subject/global:default:gcs:gcs:gcs:test"
  ]

  depends_on = [
    google_iam_workload_identity_pool.nomad
  ]
}
