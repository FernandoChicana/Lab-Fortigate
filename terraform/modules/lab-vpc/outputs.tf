output "wan_network_id" {
  value       = google_compute_network.wan.id
  description = "Self link of the WAN network."
}

output "lan_network_id" {
  value       = google_compute_network.lan.id
  description = "Self link of the LAN network."
}

output "wan_subnet_id" {
  value       = google_compute_subnetwork.wan.id
  description = "Self link of the WAN subnet."
}

output "lan_subnet_id" {
  value       = google_compute_subnetwork.lan.id
  description = "Self link of the LAN subnet."
}

output "wan_cidr" {
  value       = var.wan_cidr
  description = "WAN subnet CIDR."
}

output "lan_cidr" {
  value       = var.lan_cidr
  description = "LAN subnet CIDR."
}
