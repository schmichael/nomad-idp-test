resource "random_id" "bucket_suffix" {
  byte_length = 12
}

resource "google_storage_bucket" "nomad" {
  location                    = "US"
  name                        = "${random_pet.main.id}-${random_id.bucket_suffix.hex}"
  uniform_bucket_level_access = "true"
  public_access_prevention    = "enforced"


  # DO NOT USE THIS IN PRODUCTION
  # Deletes all bucket objects on `terraform destroy`. Good for demos, bad for
  # production.
  force_destroy = true
}

resource "google_storage_bucket_acl" "nomad" {
  bucket = google_storage_bucket.nomad.name
}

data "google_iam_policy" "nomad_gcs" {
  binding {
    role = "roles/storage.admin"

    members = [
      google_service_account.nomad.member
    ]
  }
}

resource "google_storage_bucket_iam_policy" "nomad" {
  bucket = google_storage_bucket.nomad.name

  policy_data = data.google_iam_policy.nomad_gcs.policy_data

  #  policy_data = <<POLICY
  #{
  #  "bindings": [
  #    {
  #      "members": [
  #        "serviceAccount:manual-nomad-test@hc-4ce4645b798f4ced93ce1f8aed2.iam.gserviceaccount.com"
  #      ],
  #      "role": "roles/storage.admin"
  #    },
  #    {
  #      "members": [
  #        "principal://iam.googleapis.com/projects/960872035951/locations/global/workloadIdentityPools/nomad-pool-9/subject/global:default:example:cache:redis:test",
  #        "principal://iam.googleapis.com/projects/960872035951/locations/global/workloadIdentityPools/nomad-pool-9/subject/global:default:gcs:gcs:gcs:test",
  #        "projectEditor:hc-4ce4645b798f4ced93ce1f8aed2",
  #        "projectOwner:hc-4ce4645b798f4ced93ce1f8aed2",
  #        "serviceAccount:manual-nomad-test@hc-4ce4645b798f4ced93ce1f8aed2.iam.gserviceaccount.com"
  #      ],
  #      "role": "roles/storage.legacyBucketOwner"
  #    },
  #    {
  #      "members": [
  #        "projectViewer:hc-4ce4645b798f4ced93ce1f8aed2"
  #      ],
  #      "role": "roles/storage.legacyBucketReader"
  #    },
  #    {
  #      "members": [
  #        "projectEditor:hc-4ce4645b798f4ced93ce1f8aed2",
  #        "projectOwner:hc-4ce4645b798f4ced93ce1f8aed2",
  #        "serviceAccount:manual-nomad-test@hc-4ce4645b798f4ced93ce1f8aed2.iam.gserviceaccount.com"
  #      ],
  #      "role": "roles/storage.legacyObjectOwner"
  #    },
  #    {
  #      "members": [
  #        "projectViewer:hc-4ce4645b798f4ced93ce1f8aed2"
  #      ],
  #      "role": "roles/storage.legacyObjectReader"
  #    },
  #    {
  #      "members": [
  #        "serviceAccount:manual-nomad-test@hc-4ce4645b798f4ced93ce1f8aed2.iam.gserviceaccount.com"
  #      ],
  #      "role": "roles/storage.objectCreator"
  #    }
  #  ]
  #}
  #POLICY
}
