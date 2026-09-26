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

## 6. Exercises (authorized testing only)

Reach the hosts over IAP (no public IPs on the LAN):

```bash
gcloud compute ssh fortilab-attacker --tunnel-through-iap --zone <zone>
gcloud compute ssh fortilab-victim  --tunnel-through-iap --zone <zone>
```

### 6a. IPS / intrusion — safe signature test
From the attacker, generate traffic that trips IPS without real exploitation:
- Port/vuln scanning of the victim (e.g. `nmap -sV --script vuln`) → expect IPS
  reconnaissance/probe signatures.
- Fetch the **EICAR** test string over HTTP through the FortiGate → the `lab-av`
  profile blocks it (AntiVirus, not real malware):
  ```
  curl http://www.eicar.org/download/eicar.com.txt
  ```
  Confirm the **Virus** log in FortiGate → forwarded to FAZ FortiView.

### 6b. Malware behavior — detonation
- Run authorized samples **only on the victim**, inside the isolated LAN.
- Watch three places light up:
  - **FortiGate** FortiView (IPS/AV/AppCtrl, C2 callbacks blocked at egress),
  - **FortiAnalyzer** (correlated timeline, reports),
  - **FortiEDR** (process/behavioral detection + isolation on the endpoint).
- Trigger the **quarantine** automation and confirm the victim's source IP is
  blocked at the FortiGate and/or isolated by FortiEDR.

### 6c. Verify the full pipeline
1. Detonate/scan → 2. FortiGate blocks+logs → 3. FAZ shows the event →
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
