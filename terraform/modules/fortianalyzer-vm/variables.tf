variable "name" {
  type        = string
  description = "Compute instance name (e.g. fortilab-faz)."
}

variable "machine_type" {
  type        = string
  description = "GCP machine type. FAZ minimum is 2 vCPU / 7.5 GB. e2-standard-2 is the cheapest viable shape (FAZ boots on e2, unlike FortiGate)."
  default     = "e2-standard-2"
}

variable "zone" {
  type        = string
  description = "GCP zone for the instance and data disk."
}

variable "image" {
  type        = string
  description = "FortiAnalyzer-VM image (BYOL only). Verify the exact name for your region with: gcloud compute images list --project fortigcp-project-001 --filter='name~faz OR name~analyzer'. Update this default to the current 7.6 BYOL image before applying."
  default     = "projects/fortigcp-project-001/global/images/family/fortianalyzer-76"
}

variable "data_disk_size" {
  type        = number
  description = "Size (GB) of the FAZ log/data disk. Fortinet recommends >=500 for production; 100 is fine for a short-lived lab."
  default     = 100
}

variable "wan_subnet_id" {
  type        = string
  description = "WAN subnet self link (FAZ shares the edge network with FortiGate port1)."
}

variable "admin_pw" {
  type        = string
  description = "Password for the FAZ 'admin' user (best-effort via cloud-init; if it does not take, the default password is the GCP instance ID — reset on first login)."
  sensitive   = true
}

variable "service_account_email" {
  type        = string
  description = "Service account email (default compute SA)."
}

variable "labels" {
  type        = map(string)
  description = "Resource labels."
  default     = { app = "fortilab", lifecycle = "ephemeral" }
}

variable "cloudinit_path" {
  type        = string
  description = "Path to the FortiAnalyzer cloud-init template."
}
