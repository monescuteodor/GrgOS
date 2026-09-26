#!/usr/bin/env bash
# =============================================================================
#  GrgOS — post-install provisioner  (a.k.a. `grgos-setup`)
#  Run on the INSTALLED system, as your normal user (it uses sudo internally):
#
#      grgos-setup            # or: bash /usr/local/share/grgos/scripts/install.sh
#
#  Editions:
#      Desktop   Hyprland GUI + AI/productivity/trading (+ AUR apps)
#      Security  terminal-only, GrgOS ASCII, BlackArch ethical-hacking arsenal
#
#  Flags:
#      --edition=desktop|security   pick edition non-interactively
#      --security | --hacking       shortcut for the Security edition
#      --desktop                    shortcut for the Desktop edition
#      --minimal | --no-aur         (desktop) skip AUR apps
#      --no-autologin               don't set up TTY autologin
#      --yes                        don't pause for confirmation
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(grgos_root)"
DO_AUR=1; DO_AUTOLOGIN=1; ASSUME_YES=0; EDITION=""; DO_AI=1
for a in "$@"; do
  case "$a" in
    --minimal) DO_AUR=0; DO_AI=0 ;;
    --no-aur) DO_AUR=0 ;;
    --no-ai) DO_AI=0 ;;
    --no-autologin) DO_AUTOLOGIN=0 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --security|--hacking) EDITION=security ;;
    --desktop) EDITION=desktop ;;
    --edition=*) EDITION="${a#*=}" ;;
    *) warn "unknown flag: $a" ;;
  esac
done
[[ "$EDITION" == hacking ]] && EDITION=security

require_user "$@"

# Resolve edition: explicit flag > /etc/grgos-edition (set by installer) > prompt.
if [[ -z "$EDITION" && -r /etc/grgos-edition ]]; then
  EDITION="$(tr -d '[:space:]' < /etc/grgos-edition)"
fi
if [[ "$EDITION" != desktop && "$EDITION" != security ]]; then
  if [[ $ASSUME_YES == 1 ]]; then
    EDITION=desktop
  else
    echo "Choose GrgOS edition:"
    echo "  1) Desktop   — Hyprland GUI, AI + productivity + trading"
    echo "  2) Security  — terminal only, GrgOS ASCII, BlackArch ethical-hacking arsenal"
    read -r -p "Edition [1/2] (default 1): " _ed
    case "$_ed" in 2|s|S|sec|security|hack|hacking) EDITION=security ;; *) EDITION=desktop ;; esac
  fi
fi

cat <<BANNER
============================================================
  GrgOS provisioning
------------------------------------------------------------
  User:        $USER
  Edition:     $EDITION
  Repo:        $ROOT
  AUR apps:    $([[ $EDITION == desktop && $DO_AUR == 1 ]] && echo yes || echo no)
  Autologin:   $([[ $DO_AUTOLOGIN == 1 ]] && echo yes || echo no)
============================================================
BANNER
if [[ $ASSUME_YES != 1 ]]; then
  read -r -p "Proceed? [Y/n] " ans; [[ "${ans:-Y}" =~ ^[Yy]?$ ]] || { echo "Aborted."; exit 0; }
fi

# ---- helper: install a single dotfile from the repo -------------------------
put() {  # put <relpath under config/home>
  local rel="$1" src="$ROOT/config/home/$1" dst="$HOME/$1"
  [[ -e "$src" ]] || return 0
  mkdir -p "$(dirname "$dst")"
  install -m0644 "$src" "$dst"
}

# ---- 1) dotfiles ------------------------------------------------------------
if [[ "$EDITION" == desktop ]]; then
  log "Installing desktop dotfiles into \$HOME"
  backup="$HOME/.config/grgos-backup-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$backup"
  while IFS= read -r -d '' src; do
    rel="${src#"$ROOT"/config/home/}"; dst="$HOME/$rel"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      mkdir -p "$backup/$(dirname "$rel")"; cp -a "$dst" "$backup/$rel" 2>/dev/null || true
    fi
    mkdir -p "$(dirname "$dst")"; install -m0644 "$src" "$dst"
  done < <(find "$ROOT/config/home" -type f -print0)
  chmod +x "$HOME/.bash_profile" 2>/dev/null || true
  ok "Desktop dotfiles installed (backup: $backup)"
else
  log "Installing terminal dotfiles (Security edition — no desktop autostart)"
  put ".bashrc"
  put ".tmux.conf"
  put ".config/starship.toml"
  put ".config/fastfetch/config.jsonc"
  put ".config/fastfetch/grgos.txt"
  # console login only — do NOT start Hyprland
  printf '%s\n' '[[ -f ~/.bashrc ]] && . ~/.bashrc' > "$HOME/.bash_profile"
  ok "Terminal dotfiles installed"
fi

# ---- 2) helper commands -----------------------------------------------------
log "Installing helper commands into /usr/local/bin"
sudo install -d /usr/local/bin
sudo install -m0755 "$ROOT"/bin/* /usr/local/bin/
ok "grgos-* commands installed"

# ---- 2b) brand as GrgOS -----------------------------------------------------
log "Branding the system as GrgOS"
sudo install -Dm0644 "$ROOT/config/system/os-release" /etc/os-release
sudo install -Dm0644 "$ROOT/config/system/os-release" /usr/lib/os-release
sudo install -Dm0644 "$ROOT/config/system/issue" /etc/issue 2>/dev/null || true
if [[ "$EDITION" == security ]]; then
  sudo install -m0644 "$ROOT/config/system/motd.security" /etc/motd 2>/dev/null || true
  sudo sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="GrgOS Security"/' /etc/os-release /usr/lib/os-release 2>/dev/null || true
else
  sudo install -m0644 "$ROOT/config/system/motd" /etc/motd 2>/dev/null || true
fi
if [[ ! -s /etc/hostname ]] || grep -qx 'archlinux\|archiso\|localhost' /etc/hostname 2>/dev/null; then
  echo grgos | sudo tee /etc/hostname >/dev/null
fi
ok "System branded as GrgOS"

# ---- 3) core services -------------------------------------------------------
log "Enabling NetworkManager"
sudo systemctl enable --now NetworkManager.service 2>/dev/null || warn "NetworkManager not enabled"
if [[ "$EDITION" == desktop ]]; then
  sudo systemctl enable --now bluetooth.service 2>/dev/null || true
  systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
fi

# ---- 4) dev stack (both editions) -------------------------------------------
bash "${HERE}/10-dev-stack.sh"

# ---- 5) edition-specific provisioning ---------------------------------------
if [[ "$EDITION" == desktop ]]; then
  if [[ $DO_AUR == 1 ]]; then bash "${HERE}/20-apps-aur.sh"; else warn "Skipping AUR apps"; fi
  bash "${HERE}/30-webapps.sh" --apps-dir "$HOME/.local/share/applications"
  bash "${HERE}/40-trading.sh"
  bash "${HERE}/50-theming.sh"
  [[ $DO_AI == 1 ]] && { bash "${HERE}/75-ai.sh" || warn "AI setup had issues"; }
  if have xdg-settings; then
    if have google-chrome-stable; then xdg-settings set default-web-browser google-chrome.desktop 2>/dev/null || true
    elif have chromium;          then xdg-settings set default-web-browser chromium.desktop 2>/dev/null || true; fi
  fi
else
  # Security edition: tools + privacy hardening + server-ready + local AI
  bash "${HERE}/60-security.sh"  || warn "security tools had issues"
  bash "${HERE}/65-hardening.sh" || warn "hardening had issues"
  bash "${HERE}/70-server.sh"    || warn "server setup had issues"
  [[ $DO_AI == 1 ]] && { bash "${HERE}/75-ai.sh" || warn "AI setup had issues"; }
fi

# ---- 6) autologin -----------------------------------------------------------
if [[ $DO_AUTOLOGIN == 1 ]]; then
  log "Configuring TTY1 autologin for $USER"
  sudo install -d /etc/systemd/system/getty@tty1.service.d
  sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${USER} --noclear %I \$TERM
EOF
  sudo systemctl daemon-reload
  ok "Autologin configured"
fi

# ---- done -------------------------------------------------------------------
if [[ "$EDITION" == desktop ]]; then
  cat <<'DONE'

============================================================
  GrgOS Desktop is ready. 🎉  Reboot / log out -> Hyprland.

  Super+Return terminal · Super+Space launcher · Super+B browser
  Super+E files · Super+L lock · Print screenshot · Super+T pomodoro
============================================================
DONE
else
  cat <<'DONE'

============================================================
  GrgOS Security is ready. 🔓  Reboot -> GrgOS terminal.

  Tools:    BlackArch enabled ->  pacman -Sg | grep blackarch
  Private:  firewall on, MAC randomized, encrypted DNS, SSH hardened,
            fail2ban active.  Anonymize: torsocks <cmd>
  Server:   SSH + Docker enabled.  Persistent shells: tmux
  AI:       local & offline ->  ollama run llama3.2
  Reminder: AUTHORIZED testing only.
============================================================
DONE
fi
