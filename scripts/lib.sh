#!/usr/bin/env bash
# scripts/lib.sh — shared helpers for GrgOS provisioning scripts.
# Source this; do not execute directly.

# ---- logging ----------------------------------------------------------------
c_reset=$'\e[0m'; c_blue=$'\e[1;34m'; c_grn=$'\e[1;32m'; c_ylw=$'\e[1;33m'; c_red=$'\e[1;31m'
log()  { printf '%s==>%s %s\n' "$c_blue" "$c_reset" "$*"; }
ok()   { printf '%s ✓ %s%s\n'  "$c_grn"  "$*" "$c_reset"; }
warn() { printf '%s!!%s %s\n'  "$c_ylw"  "$c_reset" "$*" >&2; }
die()  { printf '%serror%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

# ---- repo root (dir that contains scripts/, config/, bin/) -------------------
grgos_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "$d"
}

# ---- privilege --------------------------------------------------------------
# Provisioning must run as the *normal* user (dotfiles land in that user's
# $HOME) and escalate with sudo for system changes.
require_user() {
  if [[ $EUID -eq 0 ]]; then
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
      warn "Re-running as '$SUDO_USER' (provisioning must run as your normal user)…"
      exec sudo -u "$SUDO_USER" -H bash "$0" "$@"
    fi
    die "Run this as your normal user (it uses sudo where needed), not as root."
  fi
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
}

# ---- pacman -----------------------------------------------------------------
pac() {
  sudo pacman -S --needed --noconfirm "$@"
}

# ---- AUR helper (yay) -------------------------------------------------------
ensure_yay() {
  command -v yay >/dev/null 2>&1 && { ok "yay present"; return 0; }
  log "Bootstrapping the yay AUR helper"
  pac git base-devel
  local tmp; tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  ( cd "$tmp/yay-bin" && makepkg -si --noconfirm )
  rm -rf "$tmp"
  command -v yay >/dev/null 2>&1 || die "yay installation failed."
  ok "yay installed"
}

aur() {
  ensure_yay
  yay -S --needed --noconfirm "$@"
}

# ---- misc -------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
