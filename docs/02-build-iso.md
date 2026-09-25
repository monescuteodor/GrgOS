# 02 · Build the GrgOS ISO

Prerequisite: you finished **[01-wsl-arch-setup.md](01-wsl-arch-setup.md)** — Arch-on-WSL
with `archiso`, systemd, and ~15 GB free.

---

## 1. Copy the repo into the Linux filesystem

The repo lives on Windows at `C:\Users\teodo\OneDrive\Desktop\GrgOS`, which WSL sees
as `/mnt/c/Users/teodo/OneDrive/Desktop/GrgOS`. Copy it to your Linux home so the
build runs on ext4:

```bash
cp -r /mnt/c/Users/teodo/OneDrive/Desktop/GrgOS ~/GrgOS
cd ~/GrgOS
```

> Re-copy this whenever you edit files on the Windows side. (Or, if you prefer,
> `git clone https://github.com/monescuteodor/GrgOS ~/GrgOS`.)

## 2. Normalize line endings (safety)

Windows editors can introduce CRLF, which breaks shell scripts. Fix in one line:

```bash
find ~/GrgOS -type f \( -name '*.sh' -o -name 'grgos-*' -o -path '*/bin/*' \) \
  -exec sed -i 's/\r$//' {} +
```

## 3. Build

```bash
sudo bash build/build-iso.sh
```

What the script does:

1. copies the pristine `releng` profile,
2. overlays GrgOS files, merges the extra package list,
3. installs dotfiles into `/etc/skel`, helper commands into `/usr/local/bin`,
4. generates the web-app launchers and the wallpaper,
5. runs `mkarchiso` in `~/grgos-build/` (Linux fs),
6. copies the finished ISO **back to the Windows side**.

It downloads a few GB of packages the first time — grab a coffee.

## 4. Find your ISO

```
~/grgos-build/out/grgos-YYYY.MM.DD-x86_64.iso          # Linux side (fast disk)
```
and, because the repo is on `/mnt/c`, also copied to:
```
C:\Users\teodo\OneDrive\Desktop\GrgOS\out\grgos-*.iso  # Windows side
```

---

## 5. Test it (before touching real hardware)

**In a VM (recommended first):**

```bash
# inside WSL, quick UEFI boot test with QEMU (install: sudo pacman -S qemu-desktop edk2-ovmf)
qemu-system-x86_64 -enable-kvm -m 4096 -smp 4 \
  -bios /usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -cdrom ~/grgos-build/out/grgos-*.iso
```

> KVM acceleration may be unavailable inside WSL; drop `-enable-kvm` if it errors
> (slower). Or just test the ISO in **VirtualBox/VMware on Windows** — create a VM,
> set it to **EFI**, attach the ISO, boot.

**To real USB (from Windows):** use **Rufus**, **Ventoy**, or **balenaEtcher** to
write the `.iso` to a USB stick, then boot it from your BIOS/UEFI menu.

At the boot menu pick *Arch Linux install medium (GrgOS)*. You'll land at a root
prompt with the GrgOS MOTD. Continue to
**[03-post-install-and-customize.md](03-post-install-and-customize.md)**.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `mkarchiso: command not found` | `sudo pacman -S archiso` (you're not on Arch otherwise) |
| `mount: ... permission denied` / loop errors | Enable systemd (`/etc/wsl.conf`, then `wsl --shutdown`); make sure you're on `~`, not `/mnt/c` |
| `error: GPGME error` / keyring | `sudo pacman-key --init && sudo pacman-key --populate archlinux` |
| Runs out of space | Free ≥15 GB on the Linux drive; `rm -rf ~/grgos-build/work` between attempts |
| `bad interpreter: /bin/bash^M` | Re-run the CRLF normalize command in step 2 |
| Very slow / hangs on squashfs | You're building on `/mnt/c`. Copy the repo to `~` and rebuild |
| `cp: Cannot allocate memory` at the final copy step | Known WSL 9p bug copying multi-GB files onto `/mnt/c`. The ISO is fine in `~/grgos-build/out/`; the script retries with chunked `dd`. If it still fails, pull it from **Windows PowerShell**: `Copy-Item '\\wsl.localhost\archlinux\root\grgos-build\out\grgos-*.iso' -Destination C:\GrgOS-ISO\` |
