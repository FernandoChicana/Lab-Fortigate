# FortiGate-VM for the security lab. Two NICs:
#   port1 -> WAN subnet, ephemeral public IP (mgmt GUI + internet egress/NAT)
#   port2 -> LAN subnet, fixed internal IP (default gateway for lab hosts)
#
# The full FortiOS day-0 config (admin password, interfaces, security profiles,
# firewall policy with UTM, logging to FortiAnalyzer, Security Fabric root) is
# applied at first boot through the `user-data` cloud-init metadata, exactly as
# Fortinet's GCP Admin Guide prescribes. CRLF line endings are MANDATORY for a
# full FortiOS config block or cloud-init silently no-ops (replace() handles it).
#
# Machine type notes (learned the hard way in the reference project):
#   - FortiGate-VM does NOT boot on e2 (UEFI can't load FortiOS) -> validation
#     rejects e2.
#   - n1-standard-1 (1 vCPU / 3.75 GB) is the smallest Fortinet-supported x86
#     shape and is what the FG-VM01 tier expects. This is the cheapest option,
#     but it is NOT part of GCP "Always Free" (that is e2-micro only).

locals {
  user_data = replace(
    templatefile(var.cloudinit_path, {
      hostname          = var.hostname
      admin_pw          = var.admin_pw
      admin_sport       = var.admin_sport
      lan_ip            = var.lan_ip
      lan_mask          = var.lan_mask
      lan_cidr          = var.lan_cidr
      dhcp_start        = var.dhcp_start
      dhcp_end          = var.dhcp_end
      faz_ip            = var.faz_ip
      faz_serial        = var.faz_serial
      fabric_group_name = var.fabric_group_name
      fabric_psk        = var.fabric_psk
    }),
    "\n", "\r\n"
  )
}

resource "google_compute_disk" "log" {
  name                      = "${var.name}-log"
  type                      = "pd-ssd"
  zone                      = var.zone
  size                      = 30
  physical_block_size_bytes = 4096 # FortiGate-VM requires a 4096-block log disk
  labels                    = var.labels
}

resource "google_compute_instance" "this" {
  name                      = var.name
  machine_type              = var.machine_type
  zone                      = var.zone
  can_ip_forward            = true # REQUIRED: the FGT routes lab traffic
  labels                    = var.labels
  tags                      = ["fortilab", "fortigate"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.image
      size  = 15
      type  = "pd-ssd"
    }
  }

  attached_disk {
    source = google_compute_disk.log.id
  }

  # port1 = WAN (public)
  network_interface {
    subnetwork = var.wan_subnet_id
    access_config {} # ephemeral public IP
  }

  # port2 = LAN (internal, fixed IP so it can be the route next-hop / gateway)
  network_interface {
    subnetwork = var.lan_subnet_id
    network_ip = var.lan_ip
  }

  # PAYG images MUST run with a service account + these scopes or GCP kills the
  # instance ~2 min after boot (license metering / SDN connector can't init).
  service_account {
    email = var.service_account_email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
  }

  metadata = {
    user-data          = local.user_data
    license            = var.license_file == "" ? null : file(var.license_file)
    serial-port-enable = "true"
  }

  lifecycle {
    # Image families re-resolve to a dated image each apply; ignore to avoid a
    # needless recreate on every run.
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
}
