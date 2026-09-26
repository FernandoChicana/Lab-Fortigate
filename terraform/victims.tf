# Lab endpoints on the isolated LAN. No public IPs — all their traffic is forced
# through the FortiGate (custom default route), so every packet is inspected and
# logged to FortiAnalyzer.
#
# Reach them via GCP IAP (no public IPs):
#   Windows victim (RDP):  gcloud compute start-iap-tunnel fortilab-victim 3389 --local-host-port=localhost:3389 --zone <zone>
#                          then RDP to localhost:3389 as labadmin
#   Ubuntu attacker (SSH): gcloud compute ssh fortilab-attacker --tunnel-through-iap --zone <zone>
#
# SCOPE / SAFETY: the attacker ships with authorized pentest + adversary-EMULATION
# tooling only (no malware, no live exploit payloads). The victim is deliberately
# weakened for the lab. Only run attacks against the victim, inside this isolated
# network, with authorization. Never expose these VMs to the internet.

# --- Victim: Windows Server 2019 (intentionally vulnerable) -----------------
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
      size  = 50 # Windows needs more room
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = module.network.lan_subnet_id
    # no access_config -> no public IP; egress via FortiGate only
  }

  metadata = {
    windows-startup-script-ps1 = file("${path.module}/scripts/victim-vulnerable.ps1")
    lab-password               = var.victim_lab_password
    # FortiEDR collector (Windows) — optional; leave empty to install manually.
    fortiedr-installer-url = var.fortiedr_collector_installer_url
    fortiedr-reg-key       = var.fortiedr_registration_key
  }

  # FortiGate must be up to provide the LAN egress used by provisioning.
  depends_on = [module.fortigate]
}

# --- Attacker: Ubuntu + pentest/emulation toolkit ---------------------------
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
      size  = 30
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = module.network.lan_subnet_id
  }

  metadata = {
    ssh-keys       = var.ssh_pub_key
    startup-script = file("${path.module}/scripts/attacker-provision.sh")
  }

  depends_on = [module.fortigate]
}
