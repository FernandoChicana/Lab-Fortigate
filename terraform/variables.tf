# ---------------------------------------------------------------------------
# Root inputs. Copy terraform.tfvars.example -> terraform.tfvars and fill in.
# Secrets (passwords, PSK, FortiEDR keys) should come from TF_VAR_* env vars,
# not the committed tfvars.
# ---------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  description = "GCP region."
  default     = "us-east1"
}

variable "zone" {
  type        = string
  description = "GCP zone."
  default     = "us-east1-b"
}

variable "prefix" {
  type        = string
  description = "Name prefix for all lab resources."
  default     = "fortilab"
}

variable "admin_source_cidrs" {
  type        = list(string)
  description = "Your workstation public IP(s) as /32, allowed to reach the appliance management surfaces. e.g. [\"203.0.113.7/32\"]. Do NOT use 0.0.0.0/0."
}

# --- network -----------------------------------------------------------------
variable "wan_cidr" {
  type        = string
  default     = "10.10.0.0/24"
  description = "WAN/edge subnet CIDR."
}

variable "lan_cidr" {
  type        = string
  default     = "10.10.10.0/24"
  description = "Isolated lab (detonation) subnet CIDR."
}

variable "fortigate_lan_ip" {
  type        = string
  default     = "10.10.10.1"
  description = "FortiGate port2 IP = lab default gateway."
}

variable "dhcp_start" {
  type        = string
  default     = "10.10.10.100"
  description = "FortiGate DHCP pool start on the LAN."
}

variable "dhcp_end" {
  type        = string
  default     = "10.10.10.200"
  description = "FortiGate DHCP pool end on the LAN."
}

# --- FortiGate ---------------------------------------------------------------
variable "fortigate_image" {
  type        = string
  default     = "projects/fortigcp-project-001/global/images/family/fortigate-76-payg"
  description = "FortiGate-VM image. PAYG family (hourly license) by default; switch to a BYOL image + fortigate_license_file for the free 15-day eval."
}

variable "fortigate_machine_type" {
  type        = string
  default     = "n1-standard-1"
  description = "FortiGate machine type (n1/n2/c-family; NOT e2)."
}

variable "fortigate_license_file" {
  type        = string
  default     = ""
  description = "Path to a FortiGate BYOL .lic (leave empty for PAYG)."
}

variable "fortigate_admin_pw" {
  type        = string
  sensitive   = true
  description = "FortiGate admin password. Set via TF_VAR_fortigate_admin_pw."
}

variable "fabric_psk" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Security Fabric pre-shared key. Set via TF_VAR_fabric_psk."
}

# --- FortiAnalyzer -----------------------------------------------------------
variable "deploy_fortianalyzer" {
  type        = bool
  default     = true
  description = "Whether to deploy the FortiAnalyzer VM (BYOL — needs an eval license). Set false to run FortiGate-only first."
}

variable "fortianalyzer_image" {
  type        = string
  default     = "projects/fortigcp-project-001/global/images/family/fortianalyzer-76"
  description = "FortiAnalyzer-VM image (BYOL). VERIFY the exact name with: gcloud compute images list --project fortigcp-project-001 --filter='name~faz OR name~analyzer'."
}

variable "fortianalyzer_machine_type" {
  type        = string
  default     = "e2-standard-2"
  description = "FortiAnalyzer machine type (min 2 vCPU / 7.5 GB)."
}

variable "fortianalyzer_data_disk_size" {
  type        = number
  default     = 100
  description = "FAZ log disk size (GB)."
}

variable "fortianalyzer_admin_pw" {
  type        = string
  sensitive   = true
  default     = ""
  description = "FAZ admin password (best-effort via cloud-init). Set via TF_VAR_fortianalyzer_admin_pw."
}

# --- Lab endpoints (victim / attacker) --------------------------------------
variable "deploy_lab_hosts" {
  type        = bool
  default     = true
  description = "Whether to deploy the victim + attacker VMs on the LAN."
}

variable "victim_machine_type" {
  type        = string
  default     = "e2-medium"
  description = "Victim VM machine type. Windows Server 2019 needs ~2 vCPU / 4 GB minimum — e2-medium is the cheapest comfortable shape."
}

variable "attacker_machine_type" {
  type        = string
  default     = "e2-medium"
  description = "Attacker VM machine type. Metasploit/Caldera are heavy; e2-medium is comfortable, e2-small works for light use."
}

variable "victim_image" {
  type        = string
  default     = "projects/windows-cloud/global/images/family/windows-2019"
  description = "Victim VM base image. Default: Windows Server 2019 (deliberately weakened by scripts/victim-vulnerable.ps1). GCP does not offer truly old Windows (2003/2008); 2019 is the oldest current family."
}

variable "victim_lab_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for the victim's 'labadmin' local admin account (RDP over IAP). Deliberately weak for the lab. Set via TF_VAR_victim_lab_password; if empty the script uses a weak fallback."
}

variable "attacker_image" {
  type        = string
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
  description = "Attacker VM base image. Default: Ubuntu 22.04; scripts/attacker-provision.sh installs the pentest + adversary-emulation toolkit (no malware/exploit payloads committed)."
}

variable "ssh_pub_key" {
  type        = string
  description = "SSH public key (format: 'user:ssh-ed25519 AAAA... comment') injected into the attacker VM. Set via TF_VAR_ssh_pub_key."
}

# --- FortiEDR collector (installed on the victim via startup script) ---------
variable "fortiedr_collector_installer_url" {
  type        = string
  default     = ""
  description = "URL (e.g. a private GCS signed URL) to the FortiEDR WINDOWS Collector installer (.exe). Leave empty to install the collector manually on the victim. FortiEDR's management is a cloud-hosted console (trial, ~30 days) — there is no FortiEDR VM in this stack."
}

variable "fortiedr_aggregator" {
  type        = string
  default     = ""
  description = "FortiEDR Aggregator address (from your FortiEDR cloud console) the collector registers to. Referenced in docs; collector flags are set in scripts/victim-vulnerable.ps1."
}

variable "fortiedr_registration_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "FortiEDR collector registration/installation key (from the console). Set via TF_VAR_fortiedr_registration_key."
}

variable "labels" {
  type        = map(string)
  default     = { app = "fortilab", lifecycle = "ephemeral" }
  description = "Resource labels."
}
