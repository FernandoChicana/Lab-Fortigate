# Lab VPC — two networks, mirroring the classic "FortiGate inline" topology
# (same pattern as Fortinet's official gcp/7.6/single deploy):
#
#   - vpc_wan  : public/edge network. FortiGate port1 lives here with a public
#                IP; management + internet egress. FortiAnalyzer also attaches
#                here so it is reachable for the admin GUI.
#   - vpc_lan  : isolated lab network. FortiGate port2 is the default gateway.
#                Victim / attacker VMs live here so ALL their traffic is forced
#                through the FortiGate and gets IPS / AV / app-control applied.
#
# A route in vpc_lan sends 0.0.0.0/0 to the FortiGate's internal NIC, so the
# lab hosts have no direct internet path — every packet is inspected. This is
# what makes "live malware / intrusion" traffic show up in FortiGate + FAZ.

resource "google_compute_network" "wan" {
  name                    = "${var.prefix}-wan"
  auto_create_subnetworks = false
}

resource "google_compute_network" "lan" {
  name                    = "${var.prefix}-lan"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "wan" {
  name          = "${var.prefix}-wan-subnet"
  region        = var.region
  network       = google_compute_network.wan.id
  ip_cidr_range = var.wan_cidr
}

resource "google_compute_subnetwork" "lan" {
  name          = "${var.prefix}-lan-subnet"
  region        = var.region
  network       = google_compute_network.lan.id
  ip_cidr_range = var.lan_cidr
}

# --- WAN firewall -----------------------------------------------------------
# Restricted to the operator's own IP for the management surfaces (SSH 22,
# FortiGate GUI 10443, FAZ GUI 443). ICMP open for reachability checks.
# NOTE: never widen admin_source_cidr to 0.0.0.0/0 for a box you leave running.
resource "google_compute_firewall" "wan_mgmt" {
  name          = "${var.prefix}-wan-mgmt"
  network       = google_compute_network.wan.name
  direction     = "INGRESS"
  source_ranges = var.admin_source_cidrs
  target_tags   = ["fortilab"]

  allow {
    protocol = "tcp"
    ports    = ["22", "443", "541", "514", "10443", "8080", "8443"]
  }
  allow { protocol = "icmp" }
}

# Fabric / logging between appliances (FGT<->FAZ OFTP 514, FortiGate mgmt) and
# whatever the lab hosts dial out to. Kept inside the WAN net.
resource "google_compute_firewall" "wan_internal" {
  name          = "${var.prefix}-wan-internal"
  network       = google_compute_network.wan.name
  direction     = "INGRESS"
  source_ranges = [var.wan_cidr]

  allow { protocol = "all" }
}

# --- LAN firewall -----------------------------------------------------------
# Wide open WITHIN the lab net on purpose: this is the detonation/attack range.
# It is isolated from the internet except through the FortiGate (the LAN default
# route below), so "open" here means "attacker and victim can talk freely and
# the FortiGate sees all of it", not "exposed to the world".
resource "google_compute_firewall" "lan_all" {
  name          = "${var.prefix}-lan-all"
  network       = google_compute_network.lan.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow { protocol = "all" }
}

# Force all lab egress through the FortiGate internal NIC. next_hop_ip is the
# FortiGate's port2 address (passed in), so the lab hosts inherit the firewall
# as their gateway. Lower priority than the auto default route to the internet
# gateway, which we also delete-shadow by giving this a better priority.
resource "google_compute_route" "lan_default_via_fgt" {
  name        = "${var.prefix}-lan-default"
  network     = google_compute_network.lan.name
  dest_range  = "0.0.0.0/0"
  next_hop_ip = var.fortigate_lan_ip
  priority    = 100
}
