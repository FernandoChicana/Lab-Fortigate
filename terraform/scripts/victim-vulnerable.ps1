# Victim VM provisioning (Windows Server 2019) — intentionally weakened target
# for THIS isolated malware/intrusion lab only.
#
# Scope: this makes a lab target deliberately vulnerable (legacy SMBv1, a weak
# local account, open host firewall) so IPS/AV/EDR detections have something to
# fire on. It installs NO malware. Only detonate authorized samples against this
# box, inside the isolated LAN. NEVER expose this VM to the internet.
#
# Delivered via the windows-startup-script-ps1 metadata key (runs on boot).

$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\fortilab-provision.log" -Append

Write-Output "== victim provisioning start: $(Get-Date) =="

# --- Weak local admin account for the lab (credentials come from metadata) ---
$labUser = "labadmin"
$labPass = (Invoke-RestMethod -Headers @{"Metadata-Flavor"="Google"} `
  -Uri "http://metadata.google.internal/computeMetadata/v1/instance/attributes/lab-password" `
  -ErrorAction SilentlyContinue)
if ([string]::IsNullOrEmpty($labPass)) { $labPass = "P@ssw0rd123!" }  # fallback (weak on purpose)
$sec = ConvertTo-SecureString $labPass -AsPlainText -Force
if (-not (Get-LocalUser -Name $labUser -ErrorAction SilentlyContinue)) {
  New-LocalUser -Name $labUser -Password $sec -PasswordNeverExpires -AccountNeverExpires
  Add-LocalGroupMember -Group "Administrators" -Member $labUser
}

# --- Legacy / vulnerable services -------------------------------------------
# Enable SMBv1 (classic EternalBlue-era attack surface for the lab).
Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -All -NoRestart -ErrorAction SilentlyContinue
Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force -ErrorAction SilentlyContinue

# Enable RDP with NLA off (weaker, easier to fingerprint in the lab).
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 0 -ErrorAction SilentlyContinue

# Open the host firewall inside the isolated LAN (the FortiGate is the real
# control point; this lets the attacker reach the target).
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# A simple SMB share to give lateral-movement / ransomware-sim something to hit.
New-Item -Path "C:\Share" -ItemType Directory -Force | Out-Null
"lab file" | Out-File "C:\Share\readme.txt"
New-SmbShare -Name "Share" -Path "C:\Share" -FullAccess "Everyone" -ErrorAction SilentlyContinue

# --- OPTIONAL: FortiEDR collector (Windows) ---------------------------------
# If a collector installer URL + registration key are provided via metadata,
# download and install silently. Otherwise this is a manual step.
$edrUrl = (Invoke-RestMethod -Headers @{"Metadata-Flavor"="Google"} `
  -Uri "http://metadata.google.internal/computeMetadata/v1/instance/attributes/fortiedr-installer-url" `
  -ErrorAction SilentlyContinue)
$edrKey = (Invoke-RestMethod -Headers @{"Metadata-Flavor"="Google"} `
  -Uri "http://metadata.google.internal/computeMetadata/v1/instance/attributes/fortiedr-reg-key" `
  -ErrorAction SilentlyContinue)
if (-not [string]::IsNullOrEmpty($edrUrl)) {
  try {
    Invoke-WebRequest -Uri $edrUrl -OutFile "C:\FortiEDRCollectorInstaller.exe"
    # Flags vary by version; typical silent form (adjust to your package):
    Start-Process "C:\FortiEDRCollectorInstaller.exe" -ArgumentList "/S /reg-password $edrKey" -Wait
  } catch { Write-Output "FortiEDR collector install failed: $_" }
}

# NOTE: Windows Defender is left ENABLED by default. If you want FortiEDR to be
# the sole EDR for a cleaner demo, disable Defender real-time protection here
# (uncomment), understanding this weakens the host:
# Set-MpPreference -DisableRealtimeMonitoring $true

Write-Output "== victim provisioning done: $(Get-Date) =="
Stop-Transcript
