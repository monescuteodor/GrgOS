# 03 · Install GrgOS & customize

You've booted the GrgOS medium (on hardware or in a VM). GrgOS ships in two editions,
chosen during install:

- **Desktop** — the Hyprland GUI with AI, productivity and trading apps.
- **Security** — a **terminal-only** environment (no GUI) that greets you with the
  GrgOS ASCII banner and carries the **BlackArch** ethical-hacking arsenal
  (2800+ tools — more than Kali). *For authorized testing only.*

Install is two stages: the GrgOS installer lays down the branded base system, then
`grgos-setup` pulls the network-heavy extras on first boot. **Nothing ever shows
"Arch"** — GrgOS has its own installer (not archinstall) and its own identity.

---

## 1. (Optional) Preview first

At the live prompt:

```bash
grgos-preview
```

This starts the Hyprland desktop so you can look around. `Super+M` exits.

## 2. Install to disk

```bash
grgos-install
```

The GrgOS installer walks you through:

- **Edition** – Desktop or Security
- **Target disk** – it lists them; you confirm by typing `YES` (the disk is erased)
- **Hostname / user / passwords / timezone**

It detects UEFI vs BIOS, partitions (ext4 root), installs the base system, sets up
**GRUB titled "GrgOS"**, creates your sudo user, writes the GrgOS identity, and copies
the GrgOS payload. Then `reboot` and remove the USB.

> Networking is required. On Wi-Fi, connect first with `iwctl` (`station wlan0 connect <SSID>`).

## 3. First login → finish provisioning

You're logged in automatically. Finish setup with:

```bash
grgos-setup
```

- **Desktop**: installs AUR apps (Chrome, Cursor, Slack), web-app shortcuts, trading
  widget and the dark theme, then boots into Hyprland.
- **Security**: enables BlackArch and installs the full ethical-hacking toolset.

Useful flags:

```bash
grgos-setup --desktop        # force the desktop edition
grgos-setup --security       # force the security (terminal) edition
grgos-setup --minimal        # (desktop) skip AUR apps
grgos-setup --no-autologin   # keep a plain console login
grgos-setup --yes            # no prompts
```

Reboot and you're in GrgOS. 🎉  (Desktop → Hyprland; Security → GrgOS terminal.)

**Key bindings**

| Keys | Action |
|---|---|
| `Super`+`Return` | Terminal (Kitty) |
| `Super`+`Space` / `Super`+`D` | App launcher (Wofi) |
| `Super`+`B` | Browser (Chrome/Chromium) |
| `Super`+`E` | Files (Thunar) |
| `Super`+`L` | Lock screen |
| `Super`+`T` | Pomodoro start/pause |
| `Print` / `Shift`+`Print` | Screenshot region / full |
| `Super`+`Shift`+`V` | Clipboard history |
| `Super`+`1..0` | Workspaces |
| `Super`+`Q` / `Super`+`Shift`+`Q` | Close window / exit Hyprland |

---

## 4. Customize

Everything lives in `~/.config`. Edit, then reload Hyprland with `Super`+`Shift`+`Q`
→ log back in, or `hyprctl reload` for most changes.

**Monitors** — `~/.config/hypr/hyprland.conf`, the `monitor =` line. Run `hyprctl monitors`
to see names, e.g. `monitor = DP-1, 2560x1440@144, 0x0, 1`.

**Add a web app** — copy any launcher and change `Name` + the URL:

```bash
cp ~/.local/share/applications/grgos-chatgpt.desktop \
   ~/.local/share/applications/grgos-mybroker.desktop
sed -i 's|Name=.*|Name=My Broker|; s|https://chatgpt.com|https://broker.example.com|' \
   ~/.local/share/applications/grgos-mybroker.desktop
update-desktop-database ~/.local/share/applications
```

Or just re-run `scripts/30-webapps.sh` after editing its `APPS=()` list.

**Trading widget symbols** — edit `~/.config/grgos/widgets/trading.html` (the
`symbols` / `tabs` arrays), then restart it:

```bash
pkill -f grgos-trading; hyprctl dispatch exec "grgos-webapp --class grgos-trading file://$HOME/.config/grgos/widgets/trading.html"
```

Reposition/resize it via the `windowrulev2 ... class:^(grgos-trading)$` lines in
`hyprland.conf`.

**Wallpaper** — replace `/usr/share/grgos/wallpaper.png` (any image), then
`hyprctl hyprpaper reload ,/usr/share/grgos/wallpaper.png`.

**Waybar** — modules in `~/.config/waybar/config.jsonc`, colors in `style.css`.
Reload: `killall -SIGUSR2 waybar`.

**Pomodoro lengths** — edit the `WORK/SHORT/LONG` values at the top of
`/usr/local/bin/grgos-pomodoro`.

**True on-desktop widgets (behind windows)** — the trading panel here is a *pinned
floating* Chromium window (it can't sit on the wallpaper layer). For widgets that
render on the desktop background layer, add **eww** (`aur eww`) or **ags** and build
a layer-shell widget; keep this HTML as the data source. That's the recommended
upgrade path if you want conky-style desktop embedding.

---

## 5. Updating

```bash
sudo pacman -Syu          # system + repo apps
yay -Syu                  # + AUR apps (chrome, cursor, slack)
```

To pull GrgOS config changes: edit files in the repo, re-run
`scripts/install.sh` (it backs up your current dotfiles under
`~/.config/grgos-backup-*` first), or rebuild the ISO for a fresh image.
