#!/usr/bin/env bash
# scripts/50-theming.sh — native dark mode across GTK/Qt, icons, fonts, wallpaper.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${HERE}/lib.sh"
require_user "$@"

# ---- packages that back the theme (safe no-ops if already installed) --------
pac papirus-icon-theme gnome-themes-extra kvantum qt5ct qt6ct \
    ttf-jetbrains-mono-nerd inter-font imagemagick 2>/dev/null || true

# ---- wallpaper (absolute, user-agnostic path used by hyprpaper/hyprlock) ----
WP=/usr/share/grgos/wallpaper.png
if [[ ! -f "$WP" ]]; then
  log "Generating wallpaper -> $WP"
  sudo install -d /usr/share/grgos
  if have magick; then
    sudo magick -size 2560x1440 gradient:'#0b0f1e'-'#241b3a' -blur 0x8 "$WP" || warn "wallpaper gen failed"
  elif have convert; then
    sudo convert -size 2560x1440 gradient:'#0b0f1e'-'#241b3a' -blur 0x8 "$WP" || warn "wallpaper gen failed"
  else
    warn "imagemagick missing; hyprpaper will show a solid color."
  fi
fi

# ---- GTK dark (in addition to ~/.config/gtk-3.0/settings.ini) ---------------
if have gsettings; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface font-name 'Inter 10' 2>/dev/null || true
fi

# GTK4 dark (some apps read this)
mkdir -p "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=true
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 10
EOF

# ---- Qt dark (qt5ct / qt6ct via Fusion + Papirus-Dark) ----------------------
for q in qt5ct qt6ct; do
  mkdir -p "$HOME/.config/$q"
  cat > "$HOME/.config/$q/$q.conf" <<EOF
[Appearance]
style=Fusion
icon_theme=Papirus-Dark
standard_dialogs=default

[Fonts]
general="Inter,10,-1,5,50,0,0,0,0,0"
fixed="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
EOF
done

# Make Qt apps use qt6ct (also set in ~/.bashrc / hyprland env)
if ! grep -q QT_QPA_PLATFORMTHEME /etc/environment 2>/dev/null; then
  echo 'QT_QPA_PLATFORMTHEME=qt6ct' | sudo tee -a /etc/environment >/dev/null || true
fi

# ---- font cache -------------------------------------------------------------
fc-cache -f >/dev/null 2>&1 || true

ok "Theming applied (dark GTK/Qt, Papirus-Dark, Inter + JetBrainsMono Nerd Font)"
