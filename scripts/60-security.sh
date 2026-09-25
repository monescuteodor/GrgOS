#!/usr/bin/env bash
# =============================================================================
#  scripts/60-security.sh — GrgOS Security edition (Kali-like, powered by BlackArch)
# -----------------------------------------------------------------------------
#  Adds the BlackArch repository (2800+ security tools — far more than Kali's
#  default set) and installs a curated pentest/CTF toolkit on top of the GrgOS
#  Hyprland desktop.
#
#  LEGAL / ETHICAL NOTICE
#  These are dual-use security tools. Use them ONLY against systems you own or
#  are explicitly authorized IN WRITING to test (pentest engagements, CTFs,
#  labs, your own machines). Unauthorized access or interception is illegal in
#  most jurisdictions. You are solely responsible for how you use them.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"
require_user "$@"

echo "============================================================"
echo "  GrgOS Security edition — BlackArch"
echo "------------------------------------------------------------"
warn "For AUTHORIZED testing only (systems you own / written permission)."
echo "============================================================"

# ---- 1) add the BlackArch repository ----------------------------------------
add_blackarch_repo() {
  if grep -q '^\[blackarch\]' /etc/pacman.conf; then
    ok "BlackArch repository already configured"; return 0
  fi
  log "Adding the BlackArch repository via the official strap.sh"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL https://blackarch.org/strap.sh -o "${tmp}/strap.sh" \
    || die "Could not download strap.sh (check your network)"
  echo "  strap.sh SHA256: $(sha256sum "${tmp}/strap.sh" | cut -d' ' -f1)"
  echo "  (You can verify this against https://blackarch.org/downloads.html)"
  chmod +x "${tmp}/strap.sh"
  sudo "${tmp}/strap.sh" || die "strap.sh failed"
  rm -rf "${tmp}"
  sudo pacman -Syu --noconfirm
  ok "BlackArch repository ready"
}

# ---- 2) curated Kali-parity toolkit (Arch + BlackArch repos) ----------------
# Installed one-by-one so a missing/renamed package never aborts the whole run.
CORE_TOOLS=(
  # recon / scanning
  nmap masscan rustscan dnsenum dnsrecon whatweb netdiscover fierce
  # web app testing
  sqlmap nikto gobuster ffuf wfuzz dirb wpscan
  # exploitation
  metasploit exploitdb
  # password attacks
  john hashcat hydra medusa hashid hashcat-utils
  # wireless
  aircrack-ng wifite reaver bettercap hcxtools hcxdumptool
  # sniffing / MITM
  wireshark-qt tcpdump ettercap responder mitmproxy
  # forensics / reversing
  binwalk foremost sleuthkit radare2
  # utilities / anonymity
  proxychains-ng tor macchanger whois net-tools socat
  # wordlists
  seclists
)

add_blackarch_repo

log "Installing the curated security toolkit (${#CORE_TOOLS[@]} packages)"
installed=0; skipped=()
for t in "${CORE_TOOLS[@]}"; do
  if sudo pacman -S --needed --noconfirm "$t" >/dev/null 2>&1; then
    installed=$((installed+1)); printf '  + %s\n' "$t"
  else
    skipped+=("$t")
  fi
done
ok "Installed ${installed} tools"
if [[ ${#skipped[@]} -gt 0 ]]; then
  warn "Skipped (not in current repos / need AUR): ${skipped[*]}"
fi

# ---- 3) mark the system as the Security edition -----------------------------
sudo sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="GrgOS Security"/' /etc/os-release 2>/dev/null || true

cat <<'NOTE'

  GrgOS Security is ready (BlackArch enabled).

  Install more tools by category (BlackArch groups):
    sudo pacman -S blackarch-scanner blackarch-webapp blackarch-exploitation \
                   blackarch-wireless blackarch-forensic blackarch-cracker \
                   blackarch-recon blackarch-sniffer
    # list every group:   pacman -Sg | grep blackarch
    # install EVERYTHING (very large): sudo pacman -S blackarch

  Reminder: authorized testing only.
NOTE
ok "Security edition provisioning complete"
