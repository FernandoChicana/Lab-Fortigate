variable "name" {
  type        = string
  description = "Compute instance name (e.g. fortilab-fgt)."
}

variable "hostname" {
  type        = string
  description = "FortiOS hostname set by cloud-init."
  default     = "fortilab-fgt"
}

variable "machine_type" {
  type        = string
  description = "GCP machine type. Must be a Fortinet-supported x86 shape (n1/n2/c-family). e2 is rejected — FortiGate-VM does not boot on e2 (UEFI can't load FortiOS)."
  default     = "n1-standard-1"

  validation {
    condition     = !startswith(var.machine_type, "e2")
    error_message = "FortiGate-VM does not boot on e2 platforms; use an n1/n2/c-family shape (n1-standard-1 is the cheapest supported)."
  }
}

variable "zone" {
  type        = string
  description = "GCP zone for the instance and log disk."
}

variable "image" {
  type        = string
  description = "FortiGate-VM image. Default is the 7.6 PAYG family (license billed hourly by GCP)."
  default     = "projects/fortigcp-project-001/global/images/family/fortigate-76-payg"
}

variable "license_file" {
  type        = string
  description = "Path to a BYOL .lic file to inject as `license` metadata. Leave empty (\"\") for PAYG images. For a free 15-day eval, register a FGVMEV trial on support.fortinet.com, use a BYOL image, and point this at the .lic."
  default     = ""
}

variable "wan_subnet_id" {
  type        = string
  description = "WAN subnet self link for port1."
}

variable "lan_subnet_id" {
  type        = string
  description = "LAN subnet self link for port2."
}

variable "lan_ip" {
  type        = string
  description = "Fixed internal IP for port2 (the LAN default gateway / route next-hop)."
}

variable "lan_mask" {
  type        = string
  description = "Netmask for the LAN interface (e.g. 255.255.255.0)."
  default     = "255.255.255.0"
}

variable "lan_cidr" {
  type        = string
  description = "LAN subnet CIDR (used for policy/DHCP scoping)."
}

variable "dhcp_start" {
  type        = string
  description = "First address of the FortiGate DHCP pool served on port2 (lab hosts can auto-configure)."
}

variable "dhcp_end" {
  type        = string
  description = "Last address of the FortiGate DHCP pool served on port2."
}

variable "admin_pw" {
  type        = string
  description = "Password for the FortiOS 'admin' user, set inside cloud-init so the forced first-login change does not fire."
  sensitive   = true
}

variable "admin_sport" {
  type        = string
  description = "HTTPS admin GUI port (default 10443 to keep 443 free)."
  default     = "10443"
}

variable "faz_ip" {
  type        = string
  description = "FortiAnalyzer internal/WAN IP the FortiGate ships logs to (OFTP 514)."
  default     = ""
}

variable "faz_serial" {
  type        = string
  description = "FortiAnalyzer serial number, if pre-authorizing the device on the FAZ side. Optional; leave empty to authorize manually in the FAZ GUI on first contact."
  default     = ""
}

variable "fabric_group_name" {
  type        = string
  description = "Security Fabric group name (this FortiGate is the Fabric root; FortiEDR and FAZ join it)."
  default     = "fortilab-fabric"
}

variable "fabric_psk" {
  type        = string
  description = "Security Fabric pre-shared key for downstream/fabric device authorization."
  sensitive   = true
  default     = ""
}

variable "service_account_email" {
  type        = string
  description = "Service account email. PAYG MUST run with an SA + cloud-platform scope; pass the default compute SA."
}

variable "labels" {
  type        = map(string)
  description = "Resource labels."
  default     = { app = "fortilab", lifecycle = "ephemeral" }
}

variable "cloudinit_path" {
  type        = string
  description = "Path to the FortiGate cloud-init template."
}
