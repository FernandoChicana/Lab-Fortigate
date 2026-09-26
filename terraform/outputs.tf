output "fortigate_admin_url" {
  value       = module.fortigate.admin_url
  description = "FortiGate GUI (user: admin)."
}

output "fortigate_public_ip" {
  value       = module.fortigate.wan_public_ip
  description = "FortiGate WAN public IP."
}

output "fortigate_lan_gateway" {
  value       = module.fortigate.lan_ip
  description = "FortiGate LAN IP = lab default gateway."
}

output "fortianalyzer_admin_url" {
  value       = var.deploy_fortianalyzer ? module.fortianalyzer[0].admin_url : "not deployed"
  description = "FortiAnalyzer GUI (user: admin). Upload the eval license on first login."
}

output "fortianalyzer_internal_ip" {
  value       = var.deploy_fortianalyzer ? module.fortianalyzer[0].internal_ip : "not deployed"
  description = "FAZ internal IP (FortiGate log target)."
}

output "victim_name" {
  value       = var.deploy_lab_hosts ? google_compute_instance.victim[0].name : "not deployed"
  description = "Victim VM (reach via: gcloud compute ssh <name> --tunnel-through-iap)."
}

output "attacker_name" {
  value       = var.deploy_lab_hosts ? google_compute_instance.attacker[0].name : "not deployed"
  description = "Attacker VM (reach via: gcloud compute ssh <name> --tunnel-through-iap)."
}

output "next_steps" {
  value       = <<-EOT
    1. FortiGate GUI: ${module.fortigate.admin_url}  (admin / <TF_VAR_fortigate_admin_pw>)
    2. FortiAnalyzer: ${var.deploy_fortianalyzer ? module.fortianalyzer[0].admin_url : "n/a"} — upload eval .lic, then authorize the FortiGate under Device Manager.
    3. On FortiGate, confirm logs reaching FAZ: Log & Report -> Log Settings -> FortiAnalyzer = Connected.
    4. FortiEDR: create the collector group in your FortiEDR cloud console, then install the collector on the victim (auto if fortiedr_collector_installer_url set).
    5. See docs/lab-guide.md for the malware/intrusion exercises.
  EOT
  description = "Post-apply checklist."
}
