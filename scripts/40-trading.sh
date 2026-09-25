#!/usr/bin/env bash
# scripts/40-trading.sh — trading tools & the desktop chart widget.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${HERE}/lib.sh"
require_user "$@"

WIDGET="$HOME/.config/grgos/widgets/trading.html"
ROOT="$(grgos_root)"

log "Setting up the desktop trading widget"
if [[ ! -f "$WIDGET" ]]; then
  mkdir -p "$(dirname "$WIDGET")"
  cp "$ROOT/config/home/.config/grgos/widgets/trading.html" "$WIDGET"
fi
ok "Trading widget at $WIDGET (autostarts via Hyprland; class grgos-trading)"

# Optional terminal ticker (AUR). Skip on failure — the widget is the main tool.
if [[ "${GRGOS_TICKER_CLI:-0}" == "1" ]]; then
  log "Installing 'ticker' terminal stock viewer (AUR, optional)"
  aur ticker-bin 2>/dev/null || aur ticker 2>/dev/null || warn "ticker not installed (optional)"
fi

cat <<'NOTE'
  Trading is set up:
    • Desktop widget: live TradingView ticker tape, chart & market overview,
      pinned to the right edge across all workspaces.
    • TradingView web app in the launcher (Super+Space -> "TradingView").
    • Add your broker as a web app: copy any launcher in
      ~/.local/share/applications/grgos-*.desktop and change Name + URL.
NOTE
ok "Trading ready"
