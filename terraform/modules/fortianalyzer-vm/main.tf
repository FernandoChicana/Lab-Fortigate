# FortiAnalyzer-VM for the lab — central logging / analytics / FortiView for the
# FortiGate (and syslog target for FortiEDR events).
#
# IMPORTANT constraints (Fortinet GCP Admin Guide):
#   - FortiAnalyzer-VM is BYOL ONLY. There is no PAYG image. You MUST supply a
#     license: register a free FAZ-VM eval (FAZ-VM-GB1 evaluation, ~1 GB/day,
#     time-limited) on support.fortinet.com and upload the .lic in the GUI on
#     first login. GCP metadata license injection is not reliable for FAZ, so
#     license upload is a manual first-login step (documented in docs/lab-guide.md).
#   - Minimum sizing is 2 vCPU / 7.5 GB RAM. FAZ is a Linux appliance and DOES
#     boot on e2, so e2-standard-2 (2 vCPU / 8 GB) is the cheapest viable shape.
#   - Fortinet recommends >=500 GB of log storage; for a short-lived lab a
#     smaller data disk is fine (default 100 GB) — raise data_disk_size for
#     longer retention.

resource "google_compute_disk" "data" {
  name   = "${var.name}-data"
  type   = "pd-balanced"
  zone   = var.zone
  size   = var.data_disk_size
  labels = var.labels
}

resource "google_compute_instance" "this" {
  name                      = var.name
  machine_type              = var.machine_type
  zone                      = var.zone
  labels                    = var.labels
  tags                      = ["fortilab", "fortianalyzer"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.image
      size  = 20
      type  = "pd-ssd"
    }
  }

  # FAZ data/log disk (mounted for the log DB).
  attached_disk {
    source = google_compute_disk.data.id
  }

  network_interface {
    subnetwork = var.wan_subnet_id
    access_config {} # public IP for the admin GUI (restricted by firewall)
  }

  service_account {
    email = var.service_account_email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
  }

  metadata = {
    user-data          = replace(templatefile(var.cloudinit_path, { admin_pw = var.admin_pw }), "\n", "\r\n")
    serial-port-enable = "true"
  }

  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
}
