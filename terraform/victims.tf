# Lab endpoints on the isolated LAN. No public IPs — all their traffic is forced
# through the FortiGate (custom default route), which is exactly what makes the
# lab useful: every packet is inspected and logged to FortiAnalyzer.
#
# Reach them for hands-on work via GCP IAP:
#   gcloud compute ssh fortilab-victim --tunnel-through-iap --zone <zone>
# (or pivot from the attacker box once you are on the LAN).
#
# NOTE ON SCOPE: the attacker VM ships with NO offensive tooling baked in.
# Install your own testing tools on it manually, and only ever run
# malware / exploits against the victim VM inside this isolated network, with
# authorization. This stack deliberately contains no payloads or exploit code.

locals {
  # FortiEDR Linux collector auto-install (only if an installer URL is provided).
  # FortiEDR is a cloud-hosted console (30-day trial); the collector registers
  # to your Aggregator with the installation key. Everything is parameterized —
  # no keys or installers are committed.
  victim_startup = var.fortiedr_collector_installer_url == "" ? "#!/bin/bash\ntrue\n" : <<-EOT
    #!/bin/bash
    set -euxo pipefail
    cd /tmp
    curl -fsSL "${var.fortiedr_collector_installer_url}" -o fortiedr-collector-installer
    chmod +x fortiedr-collector-installer
    # Adjust flags to match your collector package (.deb/.rpm/.run). Example:
    ./fortiedr-collector-installer --aggregator "${var.fortiedr_aggregator}" \
      --registration-password "${var.fortiedr_registration_key}" || \
      echo "collector install returned non-zero — finish registration manually"
  EOT
}

resource "google_compute_instance" "victim" {
  count        = var.deploy_lab_hosts ? 1 : 0
  name         = "${var.prefix}-victim"
  machine_type = var.victim_machine_type
  zone         = var.zone
  labels       = var.labels
  tags         = ["fortilab", "lab-host", "victim"]

  boot_disk {
    initialize_params {
      image = var.victim_image
      size  = 20
    }
  }

  network_interface {
    subnetwork = module.network.lan_subnet_id
    # no access_config -> no public IP; egress via FortiGate only
  }

  metadata = {
    ssh-keys       = var.ssh_pub_key
    startup-script = local.victim_startup
  }

  # FortiGate must be up to provide the LAN's egress path used by the startup
  # script (collector download).
  depends_on = [module.fortigate]
}

resource "google_compute_instance" "attacker" {
  count        = var.deploy_lab_hosts ? 1 : 0
  name         = "${var.prefix}-attacker"
  machine_type = var.attacker_machine_type
  zone         = var.zone
  labels       = var.labels
  tags         = ["fortilab", "lab-host", "attacker"]

  boot_disk {
    initialize_params {
      image = var.attacker_image
      size  = 20
    }
  }

  network_interface {
    subnetwork = module.network.lan_subnet_id
  }

  metadata = {
    ssh-keys = var.ssh_pub_key
  }

  depends_on = [module.fortigate]
}
