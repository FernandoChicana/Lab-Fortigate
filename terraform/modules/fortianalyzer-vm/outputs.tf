output "name" {
  value       = google_compute_instance.this.name
  description = "FortiAnalyzer instance name."
}

output "public_ip" {
  value       = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
  description = "FortiAnalyzer public IP (GUI: https://<ip>)."
}

output "internal_ip" {
  value       = google_compute_instance.this.network_interface[0].network_ip
  description = "FortiAnalyzer WAN-subnet internal IP (FortiGate ships logs here over OFTP 514)."
}

output "admin_url" {
  value       = "https://${google_compute_instance.this.network_interface[0].access_config[0].nat_ip}"
  description = "FortiAnalyzer admin GUI URL."
}
