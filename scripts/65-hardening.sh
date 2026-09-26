#!/usr/bin/env bash
# =============================================================================
#  scripts/65-hardening.sh — GrgOS privacy & hardening (Security edition)
#  Firewall, kernel/network sysctl hardening, MAC randomization, encrypted DNS,
#  SSH hardening, fail2ban, no core dumps. Sane defaults that won't lock you out.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"
require_user "$@"
ROOT="$(grgos_root)"

echo "== GrgOS hardening & privacy =="
pac nftables fail2ban tor torsocks openresolv 2>/dev/null || \
  pac nftables fail2ban tor torsocks || warn "some packages missing (continuing)"

# ---- firewall (nftables) ----------------------------------------------------
log "Firewall: deny inbound (allow SSH + established/outbound)"
sudo install -Dm0644 "$ROOT/config/system/nftables.conf" /etc/nftables.conf
sudo systemctl enable --now nftables || warn "nftables not enabled"

# ---- kernel / network hardening (sysctl) ------------------------------------
log "Applying kernel & network hardening (sysctl)"
sudo install -Dm0644 "$ROOT/config/system/sysctl-hardening.conf" /etc/sysctl.d/99-grgos-hardening.conf
sudo sysctl --system >/dev/null 2>&1 || true

# ---- MAC randomization + privacy DNS routing (NetworkManager) ---------------
log "Privacy: MAC randomization + DNS via systemd-resolved"
sudo install -Dm0644 "$ROOT/config/system/nm-privacy.conf" /etc/NetworkManager/conf.d/00-grgos-privacy.conf
sudo install -Dm0644 "$ROOT/config/system/resolved-privacy.conf" /etc/systemd/resolved.conf.d/00-grgos-privacy.conf
sudo systemctl enable --now systemd-resolved || warn "systemd-resolved not enabled"
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
sudo systemctl reload NetworkManager 2>/dev/null || sudo systemctl restart NetworkManager 2>/dev/null || true

# ---- SSH hardening ----------------------------------------------------------
log "Hardening sshd (no root login, limited auth tries)"
sudo install -Dm0644 "$ROOT/config/system/sshd-hardening.conf" /etc/ssh/sshd_config.d/99-grgos.conf
sudo systemctl reload sshd 2>/dev/null || true

# ---- fail2ban (SSH brute-force protection) ----------------------------------
log "Enabling fail2ban for SSH"
sudo install -d /etc/fail2ban/jail.d
sudo tee /etc/fail2ban/jail.d/grgos-sshd.local >/dev/null <<'EOF'
[DEFAULT]
backend = systemd
bantime = 1h
findtime = 10m
maxretry = 4

[sshd]
enabled = true
EOF
sudo systemctl enable --now fail2ban 2>/dev/null || warn "fail2ban not enabled"

# ---- no core dumps ----------------------------------------------------------
sudo install -d /etc/systemd/coredump.conf.d
printf '[Coredump]\nStorage=none\nProcessSizeMax=0\n' | \
  sudo tee /etc/systemd/coredump.conf.d/grgos.conf >/dev/null
echo '* hard core 0' | sudo tee /etc/security/limits.d/99-grgos-nocore.conf >/dev/null

cat <<'NOTE'

  Privacy & hardening applied:
    • Firewall on (inbound denied except SSH).  Edit /etc/nftables.conf to open ports.
    • MAC randomization on Wi-Fi/Ethernet; encrypted DNS (DNS-over-TLS).
    • Kernel/network sysctl hardening; SSH hardened; fail2ban guarding SSH.
    • Anonymize traffic on demand:  torsocks <command>   (e.g. torsocks curl ...)
NOTE
ok "Hardening complete"
