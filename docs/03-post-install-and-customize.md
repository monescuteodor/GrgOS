# 03 · Install GrgOS & customize

You've booted the GrgOS ISO (on hardware or in a VM). This is a two-stage install:
lay down a minimal Arch base, then let GrgOS provision the desktop and apps.

---

## 1. (Optional) Preview first

At the live root prompt:

```bash
grgos-preview
```

This starts the Hyprland desktop so you can look around. It runs as root (fine for
a preview only). `Super+M` exits back to the prompt.

## 2. Install to disk

```bash
grgos-install
```

This launches **archinstall**. Suggested answers:

- **Mirror region** – your country (faster downloads)
- **Disk** – select the target; *Best-effort partition* is easiest
- **Bootloader** – systemd-boot (or GRUB)
- **Profile** – **Minimal** (GrgOS brings its own desktop — do **not** pick a DE)
- **Audio** – Pipewire
- **Network** – **NetworkManager** ← important, you need this for the apps
- **Additional packages** – leave empty (already baked into the ISO)
- **Users** – create a normal user, give it **sudo**

When archinstall finishes, `grgos-install` seeds the GrgOS provisioning payload onto
the new system. Reboot and remove the USB.

> If archinstall unmounts the target before seeding, mount your new root at `/mnt`
> and run `grgos-install --seed-only`.

## 3. First login → finish provisioning

Log in as your user on the console. Then:

```bash
bash /usr/local/share/grgos/scripts/install.sh
```

This installs the dev stack, AI/work/trading apps and web-app shortcuts, applies the
dark theme, enables NetworkManager/Bluetooth, and sets up autologin into Hyprland.

Useful flags:

```bash
install.sh --minimal        # skip AUR apps (no chrome/cursor/slack build)
install.sh --no-autologin   # keep a normal console login
install.sh --yes            # no prompts
```

Reboot (or `Super+M` then log in) and you're in GrgOS. 🎉

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
