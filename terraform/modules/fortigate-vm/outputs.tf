output "name" {
  value       = google_compute_instance.this.name
  description = "FortiGate instance name."
}

output "wan_public_ip" {
  value       = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
  description = "FortiGate port1 public IP (GUI: https://<ip>:<admin_sport>)."
}

output "wan_internal_ip" {
  value       = google_compute_instance.this.network_interface[0].network_ip
  description = "FortiGate port1 internal (WAN subnet) IP."
}

output "lan_ip" {
  value       = google_compute_instance.this.network_interface[1].network_ip
  description = "FortiGate port2 LAN IP (the lab default gateway)."
}

output "admin_url" {
  value       = "https://${google_compute_instance.this.network_interface[0].access_config[0].nat_ip}:${var.admin_sport}"
  description = "FortiGate admin GUI URL."
}
