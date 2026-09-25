# 01 · Prepare the build environment (Arch-on-WSL)

`mkarchiso` (the tool that builds the GrgOS ISO) only runs on **Arch Linux**. Your
Ubuntu/Debian WSL cannot build it. So the first step is to get an **Arch WSL**
distro and install the build tools there.

> You author/edit files on the Windows side (this repo). You **build** inside
> Arch-on-WSL, on the Linux filesystem. The finished ISO is copied back to Windows.

---

## 1. Install the Arch WSL distribution

In **Windows PowerShell** (Arch is an official WSL distro since 2024):

```powershell
wsl --version              # make sure WSL is up to date first
wsl --update
wsl --install archlinux
```

Launch it:

```powershell
wsl -d archlinux
```

> **If `archlinux` isn't listed** by `wsl --list --online`, update WSL (`wsl --update`)
> or use the community image **ArchWSL** (https://github.com/yuk7/ArchWSL) — download
> `Arch.zip`, extract, run `Arch.exe`. Everything below is identical afterwards.

---

## 2. Initialize pacman & update the system

Inside Arch-on-WSL (you'll likely be `root` on first launch):

```bash
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm
```

Create a normal user (recommended — building AUR/makepkg later refuses root):

```bash
pacman -S --needed --noconfirm sudo
useradd -m -G wheel -s /bin/bash grg
passwd grg
# allow wheel to sudo:
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
```

Optionally make it the default WSL user:

```bash
printf '[user]\ndefault=grg\n' >> /etc/wsl.conf
```

---

## 3. Enable systemd in WSL

`mkarchiso` is happiest with systemd available. Edit `/etc/wsl.conf`:

```bash
printf '[boot]\nsystemd=true\n' >> /etc/wsl.conf
```

Then, back in **PowerShell**, restart the distro:

```powershell
wsl --shutdown
```

Re-open it (`wsl -d archlinux`) and confirm:

```bash
systemctl is-system-running    # "running" or "degraded" is fine under WSL
```

---

## 4. Install the build tools

```bash
sudo pacman -S --needed --noconfirm archiso git rsync imagemagick
```

`archiso` provides `mkarchiso` and the base **releng** profile that GrgOS builds on.

---

## 5. Disk space & filesystem — the two rules that matter

1. **Build only on the Linux filesystem** (`~`, i.e. `/home/grg/...`).
   Never build under `/mnt/c/...` — squashfs and loop devices are broken/slow on
   the 9p Windows mount, and OneDrive would try to sync a ~10 GB work directory.
2. **Have ~15 GB free.** Check with `df -h ~`.

You're ready. Continue to **[02-build-iso.md](02-build-iso.md)**.
