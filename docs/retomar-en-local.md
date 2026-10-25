# Retomar el lab en tu PC local — resumen y handoff

Resumen de todo lo avanzado y cómo continuar el despliegue desde tu PC.

## Dónde está todo
- **Repo:** https://github.com/FernandoChicana/Lab-Fortigate
- **Rama:** `claude/fortinet-gcp-lab-terraform-apb6q4`
- **Estado:** todo commiteado y pusheado (nada queda solo en la sesión cloud).

Clonar en tu PC:
```powershell
git clone -b claude/fortinet-gcp-lab-terraform-apb6q4 https://github.com/FernandoChicana/Lab-Fortigate.git
cd Lab-Fortigate
```

## Qué se construyó
Laboratorio GCP con Terraform que interconecta **FortiGate + FortiAnalyzer + FortiEDR**
para demos en vivo de malware / intrusión. El FortiGate va inline: la LAN es una
red aislada cuyo tráfico se fuerza por el firewall (IPS/AV/App-Control + logging a
FortiAnalyzer), con el atacante exento de inspección y la víctima inspeccionada.

```
Internet
   │
 FortiGate (n1-standard-1, PAYG)  ── logs OFTP 514 ──►  FortiAnalyzer (e2-standard-2, BYOL)
   │  port2 = 10.10.10.1 (gateway + DHCP)
 LAN aislada 10.10.10.0/24
   ├─ atacante Ubuntu  10.10.10.10  (toolkit; egress SIN inspección)
   └─ víctima Windows  10.10.10.20  (vulnerable; egress inspeccionado + colector FortiEDR)
```

## Estructura del repo
| Ruta | Contenido |
|---|---|
| `terraform/modules/lab-vpc` | Red WAN + LAN aislada, firewalls, ruta 0.0.0.0/0 → FortiGate |
| `terraform/modules/fortigate-vm` + `cloudinit/fortigate-lab.conf` | FortiGate preconfigurado (IPS/AV/AppCtrl, SSL, logging a FAZ, Security Fabric raíz, cuarentena, excepción atacante) |
| `terraform/modules/fortianalyzer-vm` | FortiAnalyzer (logging/FortiView, BYOL) |
| `terraform/victims.tf` + `terraform/scripts/` | Víctima Windows 2019 vulnerable + atacante Ubuntu con toolkit |
| `terraform/variables.tf`, `terraform.tfvars.example`, `outputs.tf` | Variables y salidas |
| `docs/lab-guide.md` | Despliegue, licencias, interconexión y ejercicios de demo |
| `docs/arquitectura-y-costos.md` | Arquitectura, costos y análisis de capa gratuita |

## Decisiones tomadas
- **Licencia: PAYG** (rápido; lo paga el crédito de $300). Uso por horas + `terraform destroy` al terminar.
- **Despliegue: en tu PC** (gcloud + terraform ya instalados).
- **FortiEDR:** consola cloud (trial ~30 días) + colector en la víctima (no es VM en GCP).
- **Capa gratuita:** no cabe en Always Free; se financia con el **crédito de prueba de $300**.
- Costos aprox.: PAYG ~$14–18/día (24h) · BYOL ~$4.5/día. Apaga/destruye entre sesiones.

## Pendientes antes de `terraform apply`
1. **Vincular facturación** al proyecto y **habilitar Compute Engine API**.
2. **Aceptar términos del Marketplace** de FortiGate (un clic en la consola).
3. Confirmar el **PROJECT_ID exacto**: `gcloud projects list`.
4. Llenar `terraform.tfvars` y exportar los `TF_VAR_*`.
5. `terraform init && terraform apply`.
6. Post-deploy: subir `.lic` eval de FortiAnalyzer, autorizar el FortiGate en Device Manager, instalar colector FortiEDR cuando tengas el trial.

## Comandos (Windows / PowerShell)
```powershell
# proyecto + API + auth
gcloud config set project TU_PROJECT_ID
gcloud services enable compute.googleapis.com
gcloud auth application-default login

# configurar
cd Lab-Fortigate\terraform
copy terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars    # project_id = "TU_PROJECT_ID"; admin_source_cidrs = ["TU_IP/32"]
# tu IP:  (Invoke-RestMethod ifconfig.me)

# llave ssh (si no tienes)
ssh-keygen -t ed25519

# secretos (misma ventana PowerShell)
$env:TF_VAR_fortigate_admin_pw     = 'UnaClaveFuerte1!'
$env:TF_VAR_fortianalyzer_admin_pw = 'OtraClaveFuerte1!'
$env:TF_VAR_fabric_psk             = 'fabric-psk-lab'
$env:TF_VAR_victim_lab_password    = 'P@ssw0rd123!'
$env:TF_VAR_ssh_pub_key            = "labadmin:$(Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub)"

# desplegar
terraform init
terraform apply
terraform output      # URLs / IPs

# al terminar la demo (importante: PAYG por horas)
terraform destroy
```

## Acceso a las VMs (por IAP, sin IP pública)
```powershell
# atacante Ubuntu (SSH)
gcloud compute ssh fortilab-attacker --tunnel-through-iap --zone ZONA

# víctima Windows (RDP): abre el túnel y conéctate a localhost:3389 como labadmin
gcloud compute start-iap-tunnel fortilab-victim 3389 --local-host-port=localhost:3389 --zone ZONA
```

## Demo (ver detalle en `docs/lab-guide.md` §6)
1. **EICAR** (prueba de AV, segura) → bloqueo Virus en FortiGate → FAZ.
2. **nmap** recon/`smb-vuln-ms17-010` → firmas IPS/recon.
3. **Atomic Red Team / Caldera** (en `/opt/adversary-emulation/` del atacante) → detecciones FortiEDR.
4. **Cuarentena** (automation stitch) → aislamiento en FortiGate/FortiEDR.

## Prompt para una nueva sesión de Claude en tu PC
Abre Claude Code en la carpeta `Lab-Fortigate` y pega:

> Este repo tiene un lab de GCP con Terraform (FortiGate + FortiAnalyzer + FortiEDR)
> en la rama `claude/fortinet-gcp-lab-terraform-apb6q4`. Modo PAYG, despliegue local.
> Ayúdame a correr `terraform apply` contra mi proyecto GCP `<PROJECT_ID>`, resolver
> errores del plan y seguir los ejercicios de `docs/lab-guide.md`. Pendientes:
> vincular billing, habilitar Compute API y aceptar términos del Marketplace de FortiGate.
