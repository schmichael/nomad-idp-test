job "gcs" {
  type = "batch"

  group "gcs" {
    task "gcs" {
      driver = "docker"

      config {
        command        = "/bin/sh"
        args           = ["-c", "echo running && gcloud auth login --cred-file=/local/cred.json && gcloud storage cp /local/test.txt gs://hcfb0499cb13846868d0ad659"]
        image          = "google/cloud-sdk:latest"
        auth_soft_fail = true
      }

      identity {
        env  = true
        file = true
      }

      identity {
        name = "test"
        aud  = ["gcp"]
        ttl  = "1h"
        file = true
      }

      template {
        destination = "local/test.txt"
        data = <<EOF
Job:   {{ env "NOMAD_JOB_NAME" }}
Alloc: {{ env "NOMAD_ALLOC_ID" }}
EOF
      }

      template {
        destination = "local/cred.json"
        data = <<EOF
{
  "type": "external_account",
  "audience": "//iam.googleapis.com/projects/960872035951/locations/global/workloadIdentityPools/nomad-pool-9/providers/nomad-provider",
  "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
  "token_url": "https://sts.googleapis.com/v1/token",
  "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/manual-nomad-test@hc-4ce4645b798f4ced93ce1f8aed2.iam.gserviceaccount.com:generateAccessToken",
  "credential_source": {
    "file": "/secrets/nomad_test.jwt",
    "format": {
      "type": "text"
    }
  }
}
EOF
      }

      resources {
        cpu    = 500
        memory = 600
      }
    }
  }
}
