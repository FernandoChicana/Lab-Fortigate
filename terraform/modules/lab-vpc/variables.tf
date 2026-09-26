variable "prefix" {
  type        = string
  description = "Name prefix for all network resources (e.g. fortilab)."
}

variable "region" {
  type        = string
  description = "GCP region for the subnetworks."
}

variable "wan_cidr" {
  type        = string
  description = "CIDR for the public/edge (WAN) subnet where FortiGate port1 and FortiAnalyzer live."
  default     = "10.10.0.0/24"
}

variable "lan_cidr" {
  type        = string
  description = "CIDR for the isolated lab (LAN) subnet where victim/attacker VMs live behind the FortiGate."
  default     = "10.10.10.0/24"
}

variable "fortigate_lan_ip" {
  type        = string
  description = "FortiGate port2 (internal) IP — becomes the LAN default gateway / next hop for the 0.0.0.0/0 route."
}

variable "admin_source_cidrs" {
  type        = list(string)
  description = "Source CIDRs allowed to reach the appliance management surfaces (SSH/GUI). Set to your workstation's public IP/32. Never leave 0.0.0.0/0 on a long-lived box."
}
