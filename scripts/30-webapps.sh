#!/usr/bin/env bash
# scripts/30-webapps.sh — generate .desktop launchers that open each service as
# a standalone Chrome/Chromium app window (via the grgos-webapp wrapper).
#
# Dual use:
#   * during ISO build:  --apps-dir <skel>/.local/share/applications --no-bin --no-db
#   * post-install:      --apps-dir $HOME/.local/share/applications
#
# This script only WRITES files (no sudo, no network) so it is safe to run as
# root during the build and as the user afterwards.
set -euo pipefail

APPS_DIR="${HOME:-/root}/.local/share/applications"
UPDATE_DB=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apps-dir) APPS_DIR="$2"; shift 2 ;;
    --no-db)    UPDATE_DB=0; shift ;;
    --no-bin)   shift ;;            # accepted no-op (wrapper is shipped separately)
    *) echo "30-webapps: ignoring arg $1" >&2; shift ;;
  esac
done
mkdir -p "$APPS_DIR"

# name|url|icon|categories|comment
APPS=(
  # --- AI ---
  "Z.ai|https://chat.z.ai|applications-internet|Development;Utility;|GrgOS AI web app"
  "Qwen|https://chat.qwen.ai|applications-internet|Development;Utility;|GrgOS AI web app"
  "ChatGPT|https://chatgpt.com|applications-internet|Development;Utility;|GrgOS AI web app"
  "Kimi|https://www.kimi.com|applications-internet|Development;Utility;|GrgOS AI web app"
  "Claude|https://claude.ai|applications-internet|Development;Utility;|GrgOS AI web app"
  # --- Work / productivity ---
  "Gmail|https://mail.google.com|internet-mail|Network;Office;|GrgOS work web app"
  "Google Drive|https://drive.google.com|folder-cloud|Network;Office;|GrgOS work web app"
  "Google Docs|https://docs.google.com/document/|x-office-document|Office;|GrgOS work web app"
  "Google Translate|https://translate.google.com|accessories-dictionary|Utility;Office;|GrgOS work web app"
  "Canva|https://www.canva.com|applications-graphics|Graphics;|GrgOS work web app"
  "Photopea|https://www.photopea.com|applications-graphics|Graphics;|GrgOS work web app"
  "Slack|https://app.slack.com/client|slack|Network;Chat;|GrgOS work web app"
  # --- Trading ---
  "TradingView|https://www.tradingview.com/chart/|applications-office|Finance;Office;|GrgOS trading web app"
)

emit() {
  local name="$1" url="$2" icon="$3" cats="$4" comment="$5"
  local slug; slug="$(echo "$name" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
  local file="${APPS_DIR}/grgos-${slug}.desktop"
  cat > "$file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${name}
GenericName=Web App
Comment=${comment}
Exec=grgos-webapp --class grgos-${slug} ${url}
Icon=${icon}
Terminal=false
Categories=${cats}
StartupNotify=true
StartupWMClass=grgos-${slug}
Keywords=GrgOS;webapp;
EOF
}

count=0
for row in "${APPS[@]}"; do
  IFS='|' read -r name url icon cats comment <<< "$row"
  emit "$name" "$url" "$icon" "$cats" "$comment"
  count=$((count+1))
done

# A launcher for the desktop trading widget too.
cat > "${APPS_DIR}/grgos-trading-widget.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GrgOS Trading Widget
Comment=Pinned live TradingView charts on the desktop
Exec=sh -c 'grgos-webapp --class grgos-trading file://$HOME/.config/grgos/widgets/trading.html'
Icon=applications-office
Terminal=false
Categories=Finance;Office;
StartupWMClass=grgos-trading
EOF
count=$((count+1))

echo "30-webapps: wrote ${count} launchers to ${APPS_DIR}"

if [[ "$UPDATE_DB" == "1" ]] && command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi
