# Arquitectura, costos estimados y análisis de capa gratuita

> **Resumen ejecutivo:** El laboratorio **no cabe en la capa gratuita (Always Free)** de
> GCP. El coste está dominado por la **licencia PAYG del FortiGate** (~$263–394/mes si
> corre 24/7) y por el **cómputo del FortiAnalyzer**. La forma realista y barata de
> operarlo es: **licencias de evaluación (BYOL) + encender por ráfagas + `terraform destroy`
> al terminar**, lo que baja el coste a **unos pocos dólares por sesión**.

Las cifras son **estimaciones** (región `us-east1`, precios on-demand a 2026) para
dimensionar. Verifica siempre con la [Calculadora de precios de GCP](https://cloud.google.com/products/calculator)
y la ficha del Marketplace de FortiGate antes de desplegar, y configura una
**alerta de presupuesto**.

---

## 1. Arquitectura actual

```
                                   Internet
                                      │
        ┌───────────────── VPC WAN  10.10.0.0/24 ──────────────────┐
        │                                                           │
        │   FortiGate-VM (n1-standard-1)          FortiAnalyzer-VM  │
        │   port1 = IP pública, GUI :10443        (e2-standard-2)   │
        │   • Fabric ROOT                          IP pública :443  │
        │   • IPS / AV / App-Control / SSL         • FortiView      │
        │   • política LAN→WAN, logtraffic all     • reportes       │
        │            │        └──── OFTP 514 (logs realtime) ──────►│
        │   port2 = 10.10.10.1 (gateway + DHCP)                     │
        └────────────┼─────────────────────────────────────────────┘
                     │  ruta 0.0.0.0/0 → FortiGate (todo se inspecciona)
        ┌────────────┴──── VPC LAN 10.10.10.0/24 (aislada) ─────────┐
        │                                                            │
        │      víctima (e2-small)  ◄────────►  atacante (e2-small)   │
        │      • colector FortiEDR              • sin herramientas    │
        │        → consola cloud FortiEDR         ofensivas incluidas │
        │      (sin IP pública; acceso por IAP)                       │
        └────────────────────────────────────────────────────────────┘

   FortiEDR = consola SaaS (trial 30 días) + colector en la víctima.
              NO es una VM en GCP.
```

**Principio de diseño:** la LAN no tiene salida directa a Internet; una ruta
`0.0.0.0/0` la fuerza a través del FortiGate, de modo que **todo el tráfico
atacante↔víctima y cualquier callback de malware se inspecciona, se bloquea/registra
y se envía a FortiAnalyzer**. FortiEDR aporta la telemetría y respuesta en el endpoint,
integrado vía Security Fabric.

### Inventario de recursos (lo que crea Terraform)

| Componente | Recurso GCP | Módulo / archivo | Notas |
|---|---|---|---|
| Red WAN | 1 network + 1 subnet | `modules/lab-vpc` | Edge público |
| Red LAN | 1 network + 1 subnet | `modules/lab-vpc` | Aislada (detonación) |
| Firewalls | 3 reglas (`wan-mgmt`, `wan-internal`, `lan-all`) | `modules/lab-vpc` | Mgmt limitado a `admin_source_cidrs` |
| Ruta LAN | 1 route `0.0.0.0/0` → FortiGate | `modules/lab-vpc` | Fuerza inspección |
| FortiGate | 1 VM `n1-standard-1` + disco boot 15 GB pd-ssd + disco log 30 GB pd-ssd + IP pública | `modules/fortigate-vm` + `cloudinit/fortigate-lab.conf` | NGFW inline, Fabric root |
| FortiAnalyzer | 1 VM `e2-standard-2` + boot 20 GB pd-ssd + datos 100 GB pd-balanced + IP pública | `modules/fortianalyzer-vm` | BYOL, logging central |
| Víctima | 1 VM `e2-small` + 20 GB, sin IP pública | `victims.tf` | Colector FortiEDR |
| Atacante | 1 VM `e2-small` + 20 GB, sin IP pública | `victims.tf` | Acceso por IAP |

---

## 2. Costos estimados

**Anclas de precio (us-east1, on-demand, aprox. 2026; 1 mes ≈ 730 h):**

| Ítem | Precio unitario | ~ $/mes (24/7) |
|---|---|---|
| `n1-standard-1` (1 vCPU / 3.75 GB) | ~$0.0475/h | ~$34.67 |
| `e2-standard-2` (2 vCPU / 8 GB) | ~$0.067/h | ~$48.92 |
| `e2-small` (2 vCPU comp. / 2 GB) | ~$0.01675/h | ~$12.23 |
| `e2-micro` (2 vCPU comp. / 1 GB) | ~$0.008376/h | ~$6.11 *(1 gratis/mes)* |
| Disco **pd-ssd** | ~$0.17/GB-mes | — |
| Disco **pd-balanced** | ~$0.10/GB-mes | — |
| IP externa (en uso) | ~$0.005/h | ~$3.65 |
| **Licencia FortiGate PAYG (software)** | **$0.36–0.54/h** | **~$263–394** |
| Licencia FortiAnalyzer (BYOL eval) | $0 | $0 |
| Licencia FortiGate (BYOL eval 15 días) | $0 | $0 |

> La licencia PAYG del FortiGate cubre **solo el software Fortinet**; el cómputo GCP
> por debajo se paga **aparte y en paralelo**.

### Escenario A — PAYG, encendido 24/7

| Concepto | ~ $/mes |
|---|---|
| FortiGate: cómputo `n1-standard-1` | 34.67 |
| FortiGate: **licencia PAYG** | 263 – 394 |
| FortiGate: discos (15 + 30 GB pd-ssd) | 7.65 |
| FortiAnalyzer: cómputo `e2-standard-2` | 48.92 |
| FortiAnalyzer: discos (20 GB pd-ssd + 100 GB pd-balanced) | 13.40 |
| Víctima + Atacante (`e2-small` ×2 + discos) | 28.46 |
| 2 IP públicas | 7.30 |
| **Total** | **≈ $403 – 534 / mes** (típico ~$450) |

### Escenario B — FortiGate con BYOL eval (15 días), 24/7

Igual que A pero **sin** la licencia PAYG → **≈ $140 / mes** mientras dure la eval.

### Escenario C — Uso por ráfagas + `destroy` (recomendado)

Ejemplo: **6 sesiones de 4 h/mes = 24 h de cómputo**, destruyendo todo entre sesiones
(los discos casi no se cobran porque existen solo unas horas):

| Concepto (24 h) | PAYG | BYOL eval |
|---|---|---|
| FortiGate cómputo + licencia | ~$9.7 – 14 | ~$1.1 |
| FortiAnalyzer cómputo | ~$1.6 | ~$1.6 |
| Víctima + atacante | ~$0.8 | ~$0.8 |
| IPs + discos (horas) | ~$0.5 | ~$0.5 |
| **Total por mes** | **≈ $12 – 17** | **≈ $4** |

> Con `terraform destroy` entre sesiones pierdes el histórico del FortiAnalyzer
> (licencia eval + datos efímeros). Si necesitas conservar evidencia, haz un
> **snapshot** del disco de datos del FAZ antes de destruir.

---

## 3. ¿Cabe en la capa gratuita?

**No.** La *Always Free* de GCP ofrece **una** instancia `e2-micro/mes** en
`us-west1`, `us-central1` o `us-east1`, además de 30 GB de disco estándar. Ningún
componente principal encaja:

| Producto | ¿Gratis? | Motivo |
|---|---|---|
| **FortiGate-VM** | ❌ | No arranca en `e2` (el UEFI no carga FortiOS) → mínimo `n1-standard-1`, fuera de Always Free. Además la licencia (PAYG o BYOL) no es gratuita salvo la eval de 15 días. |
| **FortiAnalyzer-VM** | ❌ | Mínimo **2 vCPU / 7.5 GB** (`e2-standard-2`), muy por encima de `e2-micro`. Es **solo BYOL** (hay eval gratuita, pero el cómputo se paga). |
| **FortiEDR** | ❌ (pero sin coste GCP) | No es una VM en GCP: consola **SaaS** (trial 30 días) + colector en el endpoint. No consume capa gratuita, pero tampoco es "gratis" salvo el trial. |
| **Víctima / Atacante** | ⚠️ parcial | Puedes poner **una** de ellas en `e2-micro` para aprovechar la unidad gratuita; la segunda se paga. |

**Lo más cerca de "gratis" posible:**
1. FortiGate y FortiAnalyzer con **licencias de evaluación (BYOL)** → $0 de licencia.
2. **Encender solo durante la práctica** y `terraform destroy` al terminar.
3. Usar **una** VM de laboratorio en `e2-micro` (unidad Always Free).
4. Reducir el disco de datos del FAZ (`fortianalyzer_data_disk_size`) a lo mínimo.

Aun así, el **cómputo** del FortiGate (`n1-standard-1`) y del FortiAnalyzer
(`e2-standard-2`) se cobra mientras estén encendidos. El piso realista es
**≈ $4/mes** con evals + ráfagas cortas (Escenario C, BYOL).

---

## 4. Palancas para bajar el costo (ya soportadas por el Terraform)

| Palanca | Variable / acción | Ahorro |
|---|---|---|
| Evitar licencia PAYG | `fortigate_image` = imagen BYOL + `fortigate_license_file` (eval 15 días) | ~$263–394/mes |
| Levantar por fases | `deploy_fortianalyzer=false`, `deploy_lab_hosts=false` | Enciende solo lo que uses |
| Apagar sin destruir | `gcloud compute instances stop ...` | Ahorra cómputo+licencia; sigues pagando discos |
| Destruir entre sesiones | `terraform destroy` | Ahorra casi todo (Escenario C) |
| Disco FAZ mínimo | `fortianalyzer_data_disk_size=100` (o menos) | ~$0.10/GB-mes |
| VM de lab gratuita | poner víctima/atacante en `e2-micro` | ~$6/mes/VM |
| Presupuesto | Budget alert en GCP Billing | Evita sorpresas |

---

## Fuentes

- [Calculadora de precios de Google Cloud](https://cloud.google.com/products/calculator)
- [Precio e2-standard-2 (Economize)](https://www.economize.cloud/resources/gcp/pricing/compute-engine/e2-standard-2/) · [e2-small (CloudPrice)](https://cloudprice.net/gcp/compute/instances/e2-small)
- [FortiGate NGFW (PAYG) — GCP Marketplace](https://console.cloud.google.com/marketplace/product/fortigcp-project-001/fortigate-payg)
- [Ficha FortiGate-VM en Google Cloud (Fortinet)](https://www.fortinet.com/content/dam/fortinet/assets/data-sheets/FortiGate_VM_GCP.pdf)
- [FortiAnalyzer — tipos de máquina soportados (GCP)](https://docs.fortinet.com/document/fortianalyzer-public-cloud/7.2.0/gcp-administration-guide/369910/machine-type-support)
- [Compute Engine — Always Free / SUD/CUD (usage.ai)](https://www.usage.ai/blogs/gcp/compute-engine/)
