# GrgOS

> A lightweight, fluid **Arch Linux + Hyprland** respin built for **productivity, AI workflows, and trading**.

GrgOS is a custom Arch Linux distribution profile. It produces a bootable `.iso` with a
smooth Wayland desktop (Hyprland), a preconfigured dev stack (Python, C/C++, Git, Node),
web-app shortcuts for AI/work/trading tools, desktop trading widgets, and a modern native
dark theme — no bloatware.

```
   ____              ___  ____
  / ___|_ __ __ _   / _ \/ ___|
 | |  _| '__/ _` | | | | \___ \
 | |_| | | | (_| | | |_| |___) |
  \____|_|  \__, |  \___/|____/
            |___/   productivity · AI · trading
```

---

## What you get

| Area | Included |
|------|----------|
| **Base** | Arch Linux (minimal), Hyprland (Wayland), PipeWire audio, NetworkManager |
| **Shell/UI** | Waybar, Wofi launcher, Mako notifications, Hyprlock, Hypridle, Hyprpaper, Kitty terminal, Thunar file manager |
| **Dev stack** | `base-devel`, GCC, Clang, CMake, GDB, Git, Python + pipx, Node + npm, Claude Code CLI |
| **AI web apps** | Z.ai, Qwen, ChatGPT, Kimi, Claude — plus **Cursor** editor (native) |
| **Work web apps** | Gmail, Google Drive, Google Docs, Google Translate, Canva, Photopea, Slack |
| **Comms** | Discord (native) |
| **Trading** | TradingView web app + a pinned **desktop chart widget** (live tickers & mini-charts) |
| **Utilities** | Google Chrome, Pomodoro timer (Waybar module), themed Kitty terminal, screenshots (grim/slurp), clipboard history |
| **Theme** | Native dark mode across GTK/Qt, Papirus-Dark icons, JetBrainsMono Nerd Font, generated gradient wallpaper |

---

## Repository layout

```
GrgOS/
├── README.md                     # you are here
├── docs/
│   ├── 01-wsl-arch-setup.md       # prepare Arch-on-WSL (the build environment)
│   ├── 02-build-iso.md            # build the GrgOS .iso
│   └── 03-post-install-and-customize.md
├── build/
│   ├── build-iso.sh               # assembles the archiso profile + runs mkarchiso
│   ├── packages.grgos.x86_64      # extra packages baked into the ISO (official repos)
│   └── overlay/                   # files layered onto the archiso releng profile
│       └── airootfs/etc/motd
├── bin/                           # helper commands -> /usr/local/bin on the ISO & installed system
│   ├── grgos-webapp               # open a URL as a standalone app window
│   ├── grgos-screenshot           # region screenshot -> clipboard + file
│   ├── grgos-pomodoro             # Pomodoro timer (drives the Waybar module)
│   ├── grgos-preview              # preview Hyprland from the live ISO
│   └── grgos-install              # launch archinstall + seed GrgOS onto the target
├── config/
│   └── home/                      # dotfiles copied to /etc/skel (ISO) and $HOME (post-install)
│       ├── .bashrc / .bash_profile
│       └── .config/{hypr,waybar,kitty,wofi,mako,gtk-3.0,starship.toml,grgos}
└── scripts/
    ├── install.sh                 # master post-install orchestrator (run on the installed system)
    ├── lib.sh
    ├── 10-dev-stack.sh
    ├── 20-apps-aur.sh
    ├── 30-webapps.sh
    ├── 40-trading.sh
    └── 50-theming.sh
```

---

## Quick start (TL;DR)

The full, careful walkthrough is in [`docs/`](docs/). The short version:

```bash
# 1) In Windows PowerShell — install the Arch WSL distro (one time)
wsl --install archlinux

# 2) Inside Arch-on-WSL — install build deps and enable systemd (see docs/01)
sudo pacman -Syu --needed archiso git

# 3) Copy this repo into the Linux filesystem (NOT /mnt/c) and build
cp -r /mnt/c/Users/teodo/OneDrive/Desktop/GrgOS ~/GrgOS
cd ~/GrgOS
sudo bash build/build-iso.sh

# 4) The finished ISO is copied back to Windows at:
#    C:\Users\teodo\OneDrive\Desktop\GrgOS\out\GrgOS-*.iso
```

Then flash the ISO to a USB (Rufus/Ventoy/balenaEtcher), boot it, run `grgos-install`, and
after the first login run `scripts/install.sh` to pull in the AI/work/trading apps.

> ⚠️ **Build only inside Arch-on-WSL and only on the Linux filesystem (`~`).** `mkarchiso`
> uses loop devices and squashfs, which fail or crawl on the Windows-mounted `/mnt/c` path.

See [docs/01-wsl-arch-setup.md](docs/01-wsl-arch-setup.md) to begin.

---

## License

MIT — see [LICENSE](LICENSE).
