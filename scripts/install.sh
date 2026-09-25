#!/usr/bin/env bash
# =============================================================================
#  GrgOS — master post-install provisioner
#  Run on the INSTALLED system, as your normal user (it uses sudo internally):
#
#      bash /usr/local/share/grgos/scripts/install.sh
#
#  Flags:
#      --minimal     dotfiles + dev stack + web apps only (skip AUR apps)
#      --no-aur      skip AUR apps (google-chrome, cursor, slack)
#      --no-autologin  don't set up TTY autologin -> Hyprland
#      --yes         don't pause for confirmation
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(grgos_root)"
DO_AUR=1; DO_AUTOLOGIN=1; ASSUME_YES=0
for a in "$@"; do
  case "$a" in
    --minimal|--no-aur) DO_AUR=0 ;;
    --no-autologin) DO_AUTOLOGIN=0 ;;
    --yes|-y) ASSUME_YES=1 ;;
    *) warn "unknown flag: $a" ;;
  esac
done

require_user "$@"

cat <<BANNER
============================================================
  GrgOS provisioning
------------------------------------------------------------
  User:        $USER
  Repo:        $ROOT
  AUR apps:    $([[ $DO_AUR == 1 ]] && echo yes || echo no)
  Autologin:   $([[ $DO_AUTOLOGIN == 1 ]] && echo yes || echo no)
============================================================
BANNER
if [[ $ASSUME_YES != 1 ]]; then
  read -r -p "Proceed? [Y/n] " ans; [[ "${ans:-Y}" =~ ^[Yy]?$ ]] || { echo "Aborted."; exit 0; }
fi

# ---- 1) dotfiles ------------------------------------------------------------
log "Installing dotfiles into \$HOME"
backup="$HOME/.config/grgos-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
while IFS= read -r -d '' src; do
  rel="${src#"$ROOT"/config/home/}"
  dst="$HOME/$rel"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mkdir -p "$backup/$(dirname "$rel")"; cp -a "$dst" "$backup/$rel" 2>/dev/null || true
  fi
  mkdir -p "$(dirname "$dst")"
  install -m0644 "$src" "$dst"
done < <(find "$ROOT/config/home" -type f -print0)
# executables keep their bit
chmod +x "$HOME/.bash_profile" 2>/dev/null || true
ok "Dotfiles installed (backup: $backup)"

# ---- 2) helper commands into /usr/local/bin ---------------------------------
log "Installing helper commands into /usr/local/bin"
sudo install -d /usr/local/bin
sudo install -m0755 "$ROOT"/bin/* /usr/local/bin/
ok "grgos-* commands installed"

# ---- 3) enable core services ------------------------------------------------
log "Enabling core services (NetworkManager, Bluetooth)"
sudo systemctl enable --now NetworkManager.service 2>/dev/null || warn "NetworkManager not enabled"
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

# ---- 4) sub-provisioners ----------------------------------------------------
bash "${HERE}/10-dev-stack.sh"
if [[ $DO_AUR == 1 ]]; then bash "${HERE}/20-apps-aur.sh"; else warn "Skipping AUR apps"; fi
bash "${HERE}/30-webapps.sh" --apps-dir "$HOME/.local/share/applications"
bash "${HERE}/40-trading.sh"
bash "${HERE}/50-theming.sh"

# ---- 5) autologin -> Hyprland ----------------------------------------------
if [[ $DO_AUTOLOGIN == 1 ]]; then
  log "Configuring TTY1 autologin for $USER (Hyprland starts from ~/.bash_profile)"
  sudo install -d /etc/systemd/system/getty@tty1.service.d
  sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${USER} --noclear %I \$TERM
EOF
  sudo systemctl daemon-reload
  ok "Autologin configured"
fi

# ---- 6) set Chrome/Chromium as default browser ------------------------------
if have xdg-settings; then
  if have google-chrome-stable; then xdg-settings set default-web-browser google-chrome.desktop 2>/dev/null || true
  elif have chromium;          then xdg-settings set default-web-browser chromium.desktop 2>/dev/null || true; fi
fi

cat <<'DONE'

============================================================
  GrgOS is provisioned. 🎉
  Reboot (or log out) and you'll land in Hyprland.

  Handy keys:  Super+Return terminal · Super+Space launcher
               Super+B browser · Super+E files · Super+L lock
               Print screenshot · Super+T pomodoro
============================================================
DONE
