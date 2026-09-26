#!/usr/bin/env bash
# =============================================================================
#  scripts/70-server.sh — GrgOS server enablement (Security/terminal edition)
#  SSH server, Docker, and persistent terminal sessions (tmux) — the essentials
#  for running GrgOS headless as a server.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"
require_user "$@"

echo "== GrgOS server enablement =="
pac openssh docker docker-compose tmux htop 2>/dev/null || \
  pac openssh docker tmux || warn "some packages missing (continuing)"

# ---- SSH server -------------------------------------------------------------
log "Enabling SSH server"
sudo systemctl enable --now sshd || warn "sshd not enabled"

# ---- Docker -----------------------------------------------------------------
log "Enabling Docker"
sudo systemctl enable --now docker.service || warn "docker not enabled"
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  warn "Added $USER to the 'docker' group — log out/in (or reboot) for it to apply."
fi

# ---- journald: cap log size (server-friendly) -------------------------------
sudo install -d /etc/systemd/journald.conf.d
printf '[Journal]\nSystemMaxUse=500M\nMaxRetentionSec=1month\n' | \
  sudo tee /etc/systemd/journald.conf.d/grgos.conf >/dev/null

cat <<'NOTE'

  Server ready:
    • SSH:     connect with   ssh <user>@<this-host-IP>     (find IP: ip a)
    • Docker:  docker run hello-world   (after a re-login for group perms)
    • tmux:    keep sessions alive across disconnects:
                 tmux new -s work      (detach: Ctrl+b d ; reattach: tmux a -t work)
    • To expose a service port, add it to /etc/nftables.conf (e.g. tcp dport {80,443}).
NOTE
ok "Server enablement complete"
