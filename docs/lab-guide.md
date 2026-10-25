# FortiLab guide — deploy, license, interconnect, exercise

This guide covers standing up the lab, licensing each product, wiring the three
Fortinet products together, and running malware / intrusion exercises so the
detections land in FortiGate → FortiAnalyzer and FortiEDR.

---

## 1. Prerequisites

- A GCP project with billing enabled (this is **not** free — see the README).
- `gcloud` + `terraform >= 1.5` installed and authenticated
  (`gcloud auth application-default login`).
- Compute Engine API enabled: `gcloud services enable compute.googleapis.com`.
- **Accept the Marketplace terms once** for each PAYG image, or the deploy fails:
  visit the FortiGate VM listing in GCP Marketplace and click through the terms.
- A Fortinet support account (free) for the eval licenses.

### Verify the FortiAnalyzer image name

FAZ image names change; confirm the current BYOL image for your region and set
`fortianalyzer_image` accordingly:

```bash
gcloud compute images list --project fortigcp-project-001 \
  --filter='name~faz OR name~analyzer' --format='value(name,family)'
```

---

## 2. Licensing (the part that decides your cost)

| Product | Option | How |
|---|---|---|
| FortiGate | **PAYG** (default) | Uses `fortigate-76-payg` — GCP bills the license hourly. Nothing to upload. |
| FortiGate | **BYOL eval** (cheaper) | Register a **FortiGate VM eval (15 days)** at support.fortinet.com → Asset → register a `FGVMEV` trial. Switch `fortigate_image` to a BYOL image and set `fortigate_license_file = "fgt.lic"`. |
| FortiAnalyzer | **BYOL only** | Register a **FortiAnalyzer VM eval** (support.fortinet.com). Upload the `.lic` on first GUI login (System Settings → License). There is no PAYG FAZ. |
| FortiEDR | **Cloud trial** | Request a **30-day FortiEDR trial** → you get a cloud console + Aggregator address + a collector installation key. No GCP VM. |

---

## 3. Deploy

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit: project_id, region/zone, admin_source_cidrs (YOUR /32), images

export TF_VAR_fortigate_admin_pw='...'
export TF_VAR_fortianalyzer_admin_pw='...'
export TF_VAR_fabric_psk='...'
export TF_VAR_ssh_pub_key='labadmin:ssh-ed25519 AAAA... you@host'

terraform init
terraform apply
```

**Phased/cheaper bring-up:** set `deploy_fortianalyzer = false` and
`deploy_lab_hosts = false` first to validate the FortiGate alone, then flip them
on with another `apply`.

Grab the URLs:

```bash
terraform output
```

---

## 4. What the FortiGate already has (no manual config to start)

`cloudinit/fortigate-lab.conf` is applied at first boot and configures:

- **port1** = WAN (DHCP, public), **port2** = LAN `10.10.10.1` with a **DHCP pool**.
- Default route out port1; NAT on the LAN→WAN policy.
- Security profiles: **`lab-av`** (block+scan http/ftp/smtp/pop3/imap),
  **`lab-ips`** (block high/critical, log all, packet logging), **`lab-appctrl`**
  (monitor+log).
- **Firewall policy `lan-to-internet-inspected`**: LAN→WAN, `utm-status enable`,
  `certificate-inspection` SSL profile, AV+IPS+AppCtrl attached, `logtraffic all`.
- **Logging to FortiAnalyzer** (`config log fortianalyzer setting`, realtime,
  reliable) pointed at the FAZ internal IP that Terraform injects.
- **Security Fabric root** (`config system csf`, group name + PSK).
- An **automation stitch** `ips-quarantine`: IPS event → quarantine source IP.

> Swap `certificate-inspection` for a `deep-inspection` profile (and push the
> FortiGate CA to the victim) if you want to catch malware inside TLS. Deep
> inspection needs the CA trusted on the endpoint or you'll get cert errors.

---

## 5. Interconnect the three products

### 5a. FortiGate ↔ FortiAnalyzer
1. FAZ GUI (`https://<faz-ip>`) → upload the eval `.lic` → reboot if prompted.
2. FAZ → **Device Manager** → the FortiGate appears as *Unregistered* → **Authorize**.
   (Terraform already pointed the FortiGate at the FAZ IP.)
3. FortiGate GUI → **Log & Report → Log Settings** → FortiAnalyzer shows
   **Connected / Storage OK**. Generate traffic and confirm logs in
   FAZ **FortiView**.

### 5b. FortiGate ↔ FortiEDR (Security Fabric)
1. In the **FortiEDR cloud console**, create a **Collector Group** for the lab and
   note the **Aggregator** address + **installation key**.
2. On the FortiGate: **Security Fabric → Fabric Connectors → FortiEDR** (or use the
   FortiEDR connector) so the FortiGate can receive endpoint context and trigger
   quarantine. The `ips-quarantine` stitch from cloud-init gives you the firewall
   side; extend it in **Security Fabric → Automation** to call FortiEDR isolation.
3. Optional: forward FortiEDR events to **FortiAnalyzer** via the console's
   **Syslog** export (point it at the FAZ IP) so endpoint + network alerts sit in
   one timeline.

### 5c. Install the FortiEDR collector on the victim
- **Automatic:** set `fortiedr_collector_installer_url`, `fortiedr_aggregator`,
  and `TF_VAR_fortiedr_registration_key`; the victim's startup script installs it.
  (Host the installer in a private GCS bucket and pass a signed URL — don't commit
  it.)
- **Manual:** `gcloud compute ssh fortilab-victim --tunnel-through-iap`, copy the
  collector package, install, and register to the Aggregator with the key.
- Confirm the collector shows **Running/Connected** in the FortiEDR console.

---

## 6. Live demo — exercises (authorized testing only)

Fixed lab IPs (set by Terraform): **attacker `10.10.10.10`**, **victim `10.10.10.20`**,
gateway/FortiGate `10.10.10.1`.

Reach the hosts over IAP (no public IPs on the LAN):

```bash
# Attacker (Ubuntu) — SSH
gcloud compute ssh fortilab-attacker --tunnel-through-iap --zone <zone>

# Victim (Windows) — RDP tunnel, then connect an RDP client to localhost:3389 as labadmin
gcloud compute start-iap-tunnel fortilab-victim 3389 --local-host-port=localhost:3389 --zone <zone>
```

> The attacker has an **un-inspected** egress policy on the FortiGate, so its tool
> downloads (Metasploit, etc.) are not blocked. The **victim**'s traffic IS
> inspected — that is where detections come from. Give the attacker a couple of
> minutes after boot for `attacker-provision.sh` to finish (log:
> `/var/log/attacker-provision.log`).

### Demo 0 — confirm the pipeline is live
On the attacker, verify traffic reaches the victim and the FortiGate sees the LAN:
```bash
ping 10.10.10.20
nmap -Pn 10.10.10.20
```
In **FortiGate → Log & Report → Forward Traffic** and **FortiAnalyzer → FortiView**
you should see the sessions. If FAZ shows them, logging is wired.

### Demo 1 — AntiVirus (EICAR, 100% safe, not malware)
The **EICAR** string is an industry-standard AV test file — harmless. Fetch it so
it crosses the inspected path toward the victim, or download on the victim:
```bash
# from the victim (PowerShell) — through the inspected policy:
curl.exe https://secure.eicar.org/eicar.com.txt -o eicar.txt
```
Expect a **Virus/AV block** in FortiGate → FortiView → forwarded to FAZ. This is
the cleanest "it works" demo.

### Demo 2 — reconnaissance & IPS (intrusion)
From the attacker against the victim:
```bash
nmap -sV -O 10.10.10.20                      # service/OS fingerprinting
nmap --script smb-protocols,smb-os-discovery 10.10.10.20
nmap --script smb-vuln-ms17-010 10.10.10.20  # checks the SMBv1 weakness (no exploit)
```
Expect **IPS reconnaissance / scan** signatures and **Application Control** events
in FortiGate, visible in FAZ FortiView. (The victim has SMBv1 on by design.)

### Demo 3 — endpoint detection with safe adversary emulation (FortiEDR)
Use **Atomic Red Team** / **MITRE Caldera** (installed on the attacker under
`/opt/adversary-emulation/`) to run ATT&CK-mapped techniques **on the victim**.
These emulate malware behavior (persistence, credential-access, discovery) WITHOUT
real malware, so they are safe and repeatable. Examples of techniques to run on the
Windows victim: T1059 (command/scripting), T1053 (scheduled task), T1218 (LOLBins).
Watch **FortiEDR** flag the behavior and (with the quarantine automation) isolate
the host; the alert can also be forwarded to **FortiAnalyzer**.

> If you later detonate a real, authorized sample, do it **only on the victim**,
> inside this isolated LAN, and never expose the VM to the internet.

### Demo 4 — response / quarantine
Trigger the `ips-quarantine` automation stitch (from an IPS hit) and confirm the
offending source is **quarantined at the FortiGate** and/or **isolated by
FortiEDR** (Security Fabric → Automation shows the action firing).

### Verify the full pipeline
1. Scan/emulate → 2. FortiGate blocks+logs → 3. FAZ shows the correlated event →
4. FortiEDR shows the endpoint detection → 5. quarantine/isolation fires.

---

## 7. Tear down (do this — it's billing hourly)

```bash
terraform destroy
```

Release the eval licenses in the Fortinet support portal if you're done with them.

---

## 8. Hardening notes

- Keep `admin_source_cidrs` at your `/32`. Never `0.0.0.0/0` on a running box.
- The LAN firewall is intentionally wide **within** the isolated net; it has no
  internet path except through the FortiGate. Don't add public IPs to lab hosts.
- Rotate the admin passwords and Fabric PSK; keep them in `TF_VAR_*`, never in
  committed tfvars.
- This is a lab: images are ephemeral. Snapshot the FAZ data disk if you need to
  keep evidence between runs.
