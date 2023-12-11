resource "google_compute_managed_ssl_certificate" "nomad" {
  name = "nomad-ssl-cert"

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_target_https_proxy" "nomad" {
  name    = "nomad-https-proxy"
  url_map = google_compute_url_map.nomad.id

  ssl_certificates = [
    google_compute_managed_ssl_certificate.nomad.name
  ]

  depends_on = [
    google_compute_managed_ssl_certificate.nomad
  ]
}

resource "google_compute_instance_template" "nomad" {
  name   = "nomad-instance-template"
  region = var.region

  lifecycle {
    # Avoid errors where terraform tries to destroy/create the template on
    # subsequent runs and fails due to it being in use
    ignore_changes = [network_interface]
  }

  disk {
    auto_delete  = true
    boot         = true
    device_name  = "persistent-disk-0"
    mode         = "READ_WRITE"
    source_image = "projects/debian-cloud/global/images/family/debian-11"
    disk_size_gb = 40
    type         = "PERSISTENT"
  }

  machine_type = "n1-standard-1"

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }
    network    = "global/networks/default"
    subnetwork = "regions/${var.region}/subnetworks/default"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/pubsub", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  tags = ["allow-health-check"]
}

resource "google_compute_instance_group_manager" "nomad" {
  name = "nomad-igm"
  zone = var.zone

  named_port {
    name = "http"
    port = 80
  }

  version {
    instance_template = google_compute_instance_template.nomad.id
    name              = "primary"
  }

  base_instance_name = "vm"
  target_size        = 1
}

resource "google_compute_firewall" "nomad" {
  name          = "fw-allow-health-check"

  lifecycle {
    # Avoid always recreating the firewall rule because GCP dealiases the
    # network
    ignore_changes = [network]
  }

  direction     = "INGRESS"
  network       = "global/networks/default"
  priority      = 1000
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["allow-health-check"]
  allow {
    ports    = ["80"]
    protocol = "tcp"
  }
}

# External IP for accessing Nomad via the load balancer.
resource "google_compute_global_address" "nomad" {
  name       = "lb-ipv4-1"
  ip_version = "IPV4"
}

# Health check for load balancer backends.
resource "google_compute_health_check" "nomad" {
  name               = "http-basic-check"
  check_interval_sec = 5
  healthy_threshold  = 2
  http_health_check {
    port               = 80
    port_specification = "USE_FIXED_PORT"
    proxy_header       = "NONE"
    request_path       = "/.well-known/openid-configuration"
  }
  timeout_sec         = 5
  unhealthy_threshold = 2
}

# Load balancer backend.
resource "google_compute_backend_service" "nomad" {
  name                            = "nomad-backend-service"
  connection_draining_timeout_sec = 0
  health_checks                   = [google_compute_health_check.nomad.id]
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  port_name                       = "http"
  protocol                        = "HTTP"
  session_affinity                = "NONE"
  timeout_sec                     = 30
  backend {
    group           = google_compute_instance_group_manager.nomad.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

# Load balancer URL map.
resource "google_compute_url_map" "nomad" {
  name            = "nomad-map-http"
  default_service = google_compute_backend_service.nomad.id
}

# Forwarding rule.
##TODO Is this right?!
resource "google_compute_global_forwarding_rule" "nomad_http" {
  name                  = "http-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_https_proxy.nomad.id
  ip_address            = google_compute_global_address.nomad.id
}
resource "google_compute_global_forwarding_rule" "nomad_https" {
  name                  = "https-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.nomad.id
  ip_address            = google_compute_global_address.nomad.id
}

# Cloud DNS
### This created a managed *zone* when what we want is a record
### This is already created by doormat
#resource "google_dns_managed_zone" "parent_zone" {
#  name        = "nomad-zone"
#  dns_name    = var.parent_domain
#  description = "Test Description"
#}

resource "google_dns_record_set" "default" {
  managed_zone = var.parent_zone_name
  name         = "${var.domain}."
  type         = "A"
  rrdatas      = [google_compute_global_address.nomad.address]
  ttl          = 86400
}

# Workload Identity Pool
resource "google_iam_workload_identity_pool" "nomad" {
  workload_identity_pool_id = "nomad-pool-9" #lol the orig was deleted but would 409 if reused
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
