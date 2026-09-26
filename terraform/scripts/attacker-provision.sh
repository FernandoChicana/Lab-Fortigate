#!/bin/bash
# Attacker VM provisioning (Ubuntu) — installs a standard, authorized pentest /
# adversary-emulation toolkit for THIS isolated lab only.
#
# Scope: this script installs well-known dual-use security TOOLS and open-source
# adversary-EMULATION frameworks. It deliberately contains NO malware, no live
# exploit payloads, and runs no attacks on its own. Use it only against the lab
# victim, inside the isolated LAN, with authorization.
set -uxo pipefail
export DEBIAN_FRONTEND=noninteractive
LOG=/var/log/attacker-provision.log
exec > >(tee -a "$LOG") 2>&1
echo "== attacker provisioning start: $(date) =="

apt-get update -y
apt-get install -y --no-install-recommends \
  git curl wget ca-certificates gnupg \
  python3 python3-pip python3-venv pipx \
  nmap ncat tcpdump netcat-openbsd dnsutils \
  masscan hydra nikto sqlmap john hashcat gobuster \
  smbclient ldap-utils

pipx ensurepath || true

# Impacket + netexec (CrackMapExec successor) — AD/SMB tradecraft.
pipx install impacket || pip3 install impacket
pipx install netexec  || true

# Metasploit Framework (official Rapid7 installer).
if ! command -v msfconsole >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
    -o /tmp/msfinstall && chmod +x /tmp/msfinstall && /tmp/msfinstall || \
    echo "metasploit install failed — install manually"
fi

# Adversary-emulation frameworks (safe, MITRE ATT&CK-mapped simulation).
mkdir -p /opt/adversary-emulation
git clone --depth 1 https://github.com/redcanaryco/atomic-red-team.git \
  /opt/adversary-emulation/atomic-red-team || true
git clone --depth 1 https://github.com/mitre/caldera.git \
  /opt/adversary-emulation/caldera || true

cat >/etc/motd <<'EOF'
========================================================================
 FORTILAB ATTACKER — authorized testing only, against the lab victim,
 inside the isolated LAN. No live malware is preinstalled.
 Tools: nmap, metasploit (msfconsole), impacket, netexec, hydra, sqlmap...
 Emulation: /opt/adversary-emulation/{atomic-red-team,caldera}
 To build Caldera: cd /opt/adversary-emulation/caldera && see README.
========================================================================
EOF

echo "== attacker provisioning done: $(date) =="
