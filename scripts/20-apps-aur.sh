#!/usr/bin/env bash
# scripts/20-apps-aur.sh — apps that live in the AUR (built on the target).
#   google-chrome   (the requested browser)
#   cursor-bin      (Cursor AI editor)
#   slack-desktop   (native Slack; optional — set GRGOS_SLACK_NATIVE=0 to skip
#                    and use the Slack web app instead)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${HERE}/lib.sh"
require_user "$@"

ensure_yay

log "Installing Google Chrome (AUR)"
aur google-chrome || warn "google-chrome failed (web apps will fall back to chromium)"

log "Installing Cursor editor (AUR)"
aur cursor-bin || warn "cursor-bin failed — get it from https://cursor.com if needed"

if [[ "${GRGOS_SLACK_NATIVE:-1}" == "1" ]]; then
  log "Installing native Slack (AUR)"
  aur slack-desktop || warn "slack-desktop failed — the Slack web app still works"
fi

# nwg-look: GTK theme GUI for wlroots (nice-to-have)
aur nwg-look 2>/dev/null || true

ok "AUR apps done"
