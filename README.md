# FortiLab — FortiGate + FortiAnalyzer + FortiEDR on GCP

Terraform to stand up a **live malware / intrusion lab** on Google Cloud that
interconnects three Fortinet products:

| Product | Role in the lab | How it runs on GCP |
|---|---|---|
| **FortiGate-VM** | Inline NGFW — IPS, AntiVirus, Application Control, SSL inspection. Security Fabric **root**. Sends all logs to FortiAnalyzer. | Compute VM, PAYG image (or BYOL eval) |
| **FortiAnalyzer-VM** | Central logging, FortiView, reports, incident timeline for everything the FortiGate sees. | Compute VM, **BYOL only** (free eval license) |
| **FortiEDR** | Endpoint detection/response — Collector agent on the victim VM, reporting to the FortiEDR cloud console; integrates with the Fabric. | **Cloud-hosted console** (30-day trial) + collector agent — *not* a GCP VM |

```
 Internet
    │
 ┌──┴───────────── WAN 10.10.0.0/24 ──────────────┐
 │ FortiGate port1 (public IP, GUI :10443)         │  FortiAnalyzer (public IP, GUI :443)
 │ Fabric root · IPS/AV/AppCtrl · logs ──OFTP 514──┼─────────────►  FortiView / reports
 └──┬──────────────────────────────────────────────┘
    │ port2 = 10.10.10.1  (default gateway + DHCP)
 ┌──┴───────────── LAN 10.10.10.0/24 (isolated) ───┐
 │   victim  ◄──────────► attacker                  │   ← all traffic inspected by FortiGate
 │   (FortiEDR collector)                           │
 └─────────────────────────────────────────────────┘
```

The LAN has **no direct internet path** — a custom route sends `0.0.0.0/0` to the
FortiGate's internal NIC, so every packet between attacker and victim (and any
malware callback) is inspected, blocked/logged, and forwarded to FortiAnalyzer.

---

## ⚠️ Read first: "free tier" reality

A true GCP **Always Free** deployment of these three is **not possible** — that
tier is a single `e2-micro`, and:

- **FortiGate-VM does not boot on `e2`** (UEFI can't load FortiOS). The cheapest
  supported shape is `n1-standard-1`.
- **FortiAnalyzer-VM** needs **2 vCPU / 7.5 GB minimum** and is **BYOL only**.
- **FortiEDR** has no free GCP VM; it's a cloud console trial + agents.

What this stack gives you instead is the **lowest-cost** viable lab, designed to
run in short bursts and be destroyed:

- FortiGate on `n1-standard-1` + FortiOS **PAYG** (hourly license via GCP) —
  or use a **free 15-day FortiGate BYOL eval** (`.lic`) to drop the license cost.
- FortiAnalyzer on `e2-standard-2` with a **free FAZ-VM eval license** (~1 GB/day).
- Two small `e2-small` lab hosts (one can be `e2-micro` to use the free unit).

Rough cost if left running 24/7 is on the order of **a few USD/day** (mostly the
FortiGate PAYG license + the FAZ compute). **Run it, test, `terraform destroy`.**
Use the phasing knobs (`deploy_fortianalyzer`, `deploy_lab_hosts`) to bring parts
up only when needed, and set a **GCP budget alert**.

---

## Layout

```
terraform/
  versions.tf provider.tf variables.tf main.tf victims.tf outputs.tf
  terraform.tfvars.example
  modules/
    lab-vpc/            # WAN + isolated LAN, firewalls, LAN default route via FGT
    fortigate-vm/       # FGT-VM, 2 NICs, log disk, full day-0 cloud-init
    fortianalyzer-vm/   # FAZ-VM (BYOL), data disk
  cloudinit/
    fortigate-lab.conf      # ← the preconfigured FortiOS security build (IPS/AV/logging/Fabric)
    fortianalyzer-lab.conf  # minimal FAZ bootstrap
docs/
  lab-guide.md          # deploy steps, licensing, malware/intrusion exercises, FortiEDR wiring
```

The **`cloudinit/fortigate-lab.conf`** file is the answer to "how the FortiGate
comes up preconfigured": interfaces + DHCP, `lab-av` / `lab-ips` / `lab-appctrl`
profiles, a LAN→WAN policy with full UTM and `logtraffic all`, real-time logging
to FortiAnalyzer, Security Fabric as root, and an IPS→quarantine automation
stitch. It's applied at first boot — no manual FortiGate config needed to start.

---

## Quick start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars     # edit project_id, admin_source_cidrs, images

export TF_VAR_fortigate_admin_pw='<strong-pass>'
export TF_VAR_fortianalyzer_admin_pw='<strong-pass>'
export TF_VAR_fabric_psk='<fabric-psk>'
export TF_VAR_ssh_pub_key='labadmin:ssh-ed25519 AAAA... you@host'

terraform init
terraform apply
```

Then follow the `next_steps` output and **`docs/lab-guide.md`** for licensing,
FortiEDR onboarding, and the hands-on exercises.

> **Scope / safety:** the attacker VM ships with **no** offensive tooling and this
> repo contains **no** malware or exploit code. Only detonate samples you're
> authorized to use, against the victim VM, inside this isolated network.

See **[docs/lab-guide.md](docs/lab-guide.md)** for the full guide.
