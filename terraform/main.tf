# ===========================================================================
# FortiLab — FortiGate + FortiAnalyzer + FortiEDR interconnect on GCP
#
# Topology:
#
#   Internet
#      |
#   [port1/WAN]  FortiGate-VM  [port2/LAN=10.10.10.1]
#      |   \ (Fabric root, IPS/AV/AppCtrl, logs->FAZ)   \
#      |    \                                             \-- DHCP + default GW
#   [FortiAnalyzer]                                   [ LAN 10.10.10.0/24 ]
#    logs/FortiView                                    victim <--> attacker
#                                                      (FortiEDR collector on victim)
#
# All LAN egress is routed through the FortiGate, so malware/intrusion traffic
# generated between attacker and victim is inspected, logged, and sent to FAZ.
# ===========================================================================

data "google_compute_default_service_account" "default" {}

module "network" {
  source             = "./modules/lab-vpc"
  prefix             = var.prefix
  region             = var.region
  wan_cidr           = var.wan_cidr
  lan_cidr           = var.lan_cidr
  fortigate_lan_ip   = var.fortigate_lan_ip
  admin_source_cidrs = var.admin_source_cidrs
}

module "fortigate" {
  source                = "./modules/fortigate-vm"
  name                  = "${var.prefix}-fgt"
  hostname              = "${var.prefix}-fgt"
  zone                  = var.zone
  machine_type          = var.fortigate_machine_type
  image                 = var.fortigate_image
  license_file          = var.fortigate_license_file
  wan_subnet_id         = module.network.wan_subnet_id
  lan_subnet_id         = module.network.lan_subnet_id
  lan_ip                = var.fortigate_lan_ip
  lan_cidr              = var.lan_cidr
  dhcp_start            = var.dhcp_start
  dhcp_end              = var.dhcp_end
  admin_pw              = var.fortigate_admin_pw
  faz_ip                = var.deploy_fortianalyzer ? module.fortianalyzer[0].internal_ip : ""
  fabric_psk            = var.fabric_psk
  service_account_email = data.google_compute_default_service_account.default.email
  cloudinit_path        = "${path.module}/cloudinit/fortigate-lab.conf"
  labels                = var.labels
}

module "fortianalyzer" {
  source                = "./modules/fortianalyzer-vm"
  count                 = var.deploy_fortianalyzer ? 1 : 0
  name                  = "${var.prefix}-faz"
  zone                  = var.zone
  machine_type          = var.fortianalyzer_machine_type
  image                 = var.fortianalyzer_image
  data_disk_size        = var.fortianalyzer_data_disk_size
  wan_subnet_id         = module.network.wan_subnet_id
  admin_pw              = var.fortianalyzer_admin_pw
  service_account_email = data.google_compute_default_service_account.default.email
  cloudinit_path        = "${path.module}/cloudinit/fortianalyzer-lab.conf"
  labels                = var.labels
}
