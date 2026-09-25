#!/usr/bin/env bash
# =============================================================================
#  GrgOS ISO builder
# -----------------------------------------------------------------------------
#  Assembles a customized archiso profile (based on the official "releng"
#  profile) and runs mkarchiso to produce a bootable GrgOS .iso.
#
#  RUN THIS INSIDE ARCH-ON-WSL (or a real Arch box), AS ROOT, ON THE LINUX
#  FILESYSTEM. Do NOT run it from /mnt/c — squashfs + loop devices are slow or
#  broken on the 9p Windows mount.
#
#  Usage:
#     sudo bash build/build-iso.sh
#
#  Result:
#     ~/grgos-build/out/GrgOS-YYYY.MM.DD-x86_64.iso   (Linux fs, fast)
#     <repo>/out/GrgOS-YYYY.MM.DD-x86_64.iso          (copied back for Windows)
# =============================================================================
set -euo pipefail

# ---- resolve paths ----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Build strictly on the Linux filesystem. Never under /mnt/*.
BUILD_ROOT="${GRGOS_BUILD_ROOT:-${HOME}/grgos-build}"
PROFILE_DIR="${BUILD_ROOT}/profile"
WORK_DIR="${BUILD_ROOT}/work"
OUT_DIR="${BUILD_ROOT}/out"
RELENG_SRC="/usr/share/archiso/configs/releng"

ISO_LABEL="GRGOS"
ISO_PUBLISHER="GrgOS <https://github.com/monescuteodor/GrgOS>"
ISO_APPLICATION="GrgOS Live/Install"

# ---- pretty logging ---------------------------------------------------------
c_reset=$'\e[0m'; c_blue=$'\e[1;34m'; c_grn=$'\e[1;32m'; c_ylw=$'\e[1;33m'; c_red=$'\e[1;31m'
log()  { printf '%s==>%s %s\n' "$c_blue" "$c_reset" "$*"; }
ok()   { printf '%s ok%s %s\n' "$c_grn"  "$c_reset" "$*"; }
warn() { printf '%s!!%s %s\n'  "$c_ylw"  "$c_reset" "$*" >&2; }
die()  { printf '%serror%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

# ---- preflight checks -------------------------------------------------------
preflight() {
  log "Preflight checks"

  [[ $EUID -eq 0 ]] || die "Run as root:  sudo bash build/build-iso.sh"

  command -v pacman >/dev/null 2>&1 || \
    die "pacman not found. This build MUST run inside Arch Linux (Arch-on-WSL). See docs/01-wsl-arch-setup.md"

  # Refuse to build on the Windows mount — it will be painfully slow or fail.
  case "$REPO_ROOT" in
    /mnt/*) warn "Repo is on the Windows mount ($REPO_ROOT)."
            warn "That's fine to READ from, but the build itself runs in $BUILD_ROOT (Linux fs).";;
  esac
  case "$BUILD_ROOT" in
    /mnt/*) die  "GRGOS_BUILD_ROOT points at the Windows mount ($BUILD_ROOT). Use a path under \$HOME.";;
  esac

  # archiso provides mkarchiso + the releng profile.
  if ! command -v mkarchiso >/dev/null 2>&1; then
    warn "mkarchiso not found — installing 'archiso'..."
    pacman -Sy --needed --noconfirm archiso || die "Failed to install archiso"
  fi
  [[ -d "$RELENG_SRC" ]] || die "releng profile missing at $RELENG_SRC (reinstall 'archiso')"

  # imagemagick is used to generate the wallpaper baked into the ISO.
  if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
    warn "imagemagick not found — installing it (used to generate the wallpaper)..."
    pacman -Sy --needed --noconfirm imagemagick || warn "Could not install imagemagick; will fall back to a plain wallpaper."
  fi

  # rsync is used to overlay files.
  command -v rsync >/dev/null 2>&1 || pacman -Sy --needed --noconfirm rsync

  # Free space sanity check (need ~15 GB for work + iso).
  local avail_kb
  avail_kb="$(df -Pk "$(dirname "$BUILD_ROOT")" | awk 'NR==2{print $4}')"
  if [[ -n "$avail_kb" && "$avail_kb" -lt 15000000 ]]; then
    warn "Less than ~15 GB free where the build runs. mkarchiso may run out of space."
  fi

  ok "Preflight passed"
}

# ---- assemble the profile ---------------------------------------------------
assemble_profile() {
  log "Assembling archiso profile in $PROFILE_DIR"
  rm -rf "$PROFILE_DIR"
  mkdir -p "$BUILD_ROOT"

  # 1) Start from the pristine official releng profile.
  cp -a "$RELENG_SRC" "$PROFILE_DIR"

  # 2) Overlay our static files (motd, etc.) on top of the releng airootfs.
  if [[ -d "${REPO_ROOT}/build/overlay" ]]; then
    rsync -a "${REPO_ROOT}/build/overlay/" "${PROFILE_DIR}/"
  fi

  # 3) Merge our extra packages into packages.x86_64 (deduplicated, comments stripped).
  log "Merging package list"
  {
    grep -vE '^\s*(#|$)' "${PROFILE_DIR}/packages.x86_64"
    grep -vE '^\s*(#|$)' "${REPO_ROOT}/build/packages.grgos.x86_64"
  } | sort -u > "${PROFILE_DIR}/packages.x86_64.new"
  mv "${PROFILE_DIR}/packages.x86_64.new" "${PROFILE_DIR}/packages.x86_64"
  ok "$(wc -l < "${PROFILE_DIR}/packages.x86_64") packages queued"

  # 4) Copy dotfiles into /etc/skel so every new user inherits the GrgOS desktop.
  log "Installing dotfiles into /etc/skel"
  mkdir -p "${PROFILE_DIR}/airootfs/etc/skel"
  rsync -a "${REPO_ROOT}/config/home/" "${PROFILE_DIR}/airootfs/etc/skel/"

  # 4b) Brand the system identity (hostname / issue) as GrgOS.
  #     os-release is NOT shipped as a file here: the 'filesystem' package owns
  #     /usr/lib/os-release, so pre-placing it aborts pacstrap with a file
  #     conflict (and NoExtract does not suppress that check). Instead, a pacman
  #     hook (build/overlay/.../00-grgos-osrelease.hook) rewrites os-release to
  #     the GrgOS version right after 'filesystem' installs, from the payload.
  log "Installing GrgOS system identity (hostname, issue)"
  install -Dm0644 "${REPO_ROOT}/config/system/hostname" "${PROFILE_DIR}/airootfs/etc/hostname"
  install -Dm0644 "${REPO_ROOT}/config/system/issue"    "${PROFILE_DIR}/airootfs/etc/issue"

  # 5) Copy helper commands into /usr/local/bin.
  log "Installing helper commands into /usr/local/bin"
  mkdir -p "${PROFILE_DIR}/airootfs/usr/local/bin"
  install -m0755 "${REPO_ROOT}"/bin/* "${PROFILE_DIR}/airootfs/usr/local/bin/"

  # 6) Ship the repo's scripts + config on the ISO so the installed system can
  #    finish provisioning (AI/work/trading apps) without cloning anything.
  log "Bundling GrgOS provisioning payload into /usr/local/share/grgos"
  local payload="${PROFILE_DIR}/airootfs/usr/local/share/grgos"
  mkdir -p "$payload"
  rsync -a --exclude out --exclude work "${REPO_ROOT}/scripts" "$payload/"
  rsync -a "${REPO_ROOT}/config"  "$payload/"
  rsync -a "${REPO_ROOT}/bin"     "$payload/"

  # 7) Generate the web-app .desktop launchers straight into skel.
  log "Generating web-app launchers"
  bash "${REPO_ROOT}/scripts/30-webapps.sh" \
       --apps-dir "${PROFILE_DIR}/airootfs/etc/skel/.local/share/applications" \
       --no-bin --no-db || warn "web-app generation reported a problem (continuing)"

  # 8) Generate the desktop wallpaper into /usr/share/grgos (absolute path, no username needed).
  generate_wallpaper "${PROFILE_DIR}/airootfs/usr/share/grgos/wallpaper.png"

  # 9) Normalize line endings on every shell script we ship (defends against
  #    CRLF sneaking in from Windows editors).
  log "Normalizing line endings (CRLF -> LF)"
  find "${PROFILE_DIR}/airootfs/usr/local/bin" \
       "${PROFILE_DIR}/airootfs/usr/local/share/grgos" \
       "${PROFILE_DIR}/airootfs/etc/skel" -type f 2>/dev/null \
    | while read -r f; do sed -i 's/\r$//' "$f" 2>/dev/null || true; done

  # 10) Brand the profile + boot menus + register file permissions.
  brand_profile
  brand_bootloaders
  register_permissions

  ok "Profile assembled"
}

generate_wallpaper() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  local mk=""
  command -v magick  >/dev/null 2>&1 && mk="magick"
  command -v convert >/dev/null 2>&1 && [[ -z "$mk" ]] && mk="convert"
  if [[ -n "$mk" ]]; then
    log "Generating wallpaper -> $dest"
    "$mk" -size 2560x1440 \
      gradient:'#0b0f1e'-'#241b3a' \
      -blur 0x8 "$dest" 2>/dev/null || warn "Wallpaper generation failed (non-fatal)."
  else
    warn "No imagemagick; skipping wallpaper (Hyprland will fall back to a solid color)."
  fi
}

brand_profile() {
  local pd="${PROFILE_DIR}/profiledef.sh"
  # iso_name / iso_label / publisher / application drive the volume metadata.
  sed -i \
    -e "s/^iso_name=.*/iso_name=\"grgos\"/" \
    -e "s/^iso_label=.*/iso_label=\"${ISO_LABEL}_$(date +%Y%m)\"/" \
    -e "s|^iso_publisher=.*|iso_publisher=\"${ISO_PUBLISHER}\"|" \
    -e "s|^iso_application=.*|iso_application=\"${ISO_APPLICATION}\"|" \
    "$pd"
}

brand_bootloaders() {
  # Rewrite the visible boot-menu titles from "Arch Linux" to "GrgOS".
  # Only display strings are touched; the %ARCHISO_LABEL% boot params that
  # mkarchiso substitutes are left intact, so booting is unaffected.
  log "Rebranding boot menus (Arch Linux -> GrgOS)"
  shopt -s nullglob
  local files=(
    "${PROFILE_DIR}"/syslinux/*.cfg
    "${PROFILE_DIR}"/efiboot/loader/entries/*.conf
    "${PROFILE_DIR}"/grub/*.cfg
  )
  shopt -u nullglob
  local f
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    sed -i \
      -e 's/Arch Linux install medium/GrgOS/g' \
      -e 's/Arch Linux/GrgOS/g' \
      "$f"
  done
}

register_permissions() {
  # Ensure our helper commands are 0:0:755 in the built image.
  local pd="${PROFILE_DIR}/profiledef.sh"
  local inject=""
  for f in "${REPO_ROOT}"/bin/*; do
    local base; base="$(basename "$f")"
    inject+="  [\"/usr/local/bin/${base}\"]=\"0:0:755\"\n"
  done
  # Insert our entries right before the closing ')' of the file_permissions array.
  awk -v ins="$inject" '
    /file_permissions=\(/ { infp=1; print; next }
    infp && /^\)/ { printf "%s", ins; infp=0; print; next }
    { print }
  ' "$pd" > "${pd}.tmp" && mv "${pd}.tmp" "$pd"
}

# ---- run mkarchiso ----------------------------------------------------------
run_mkarchiso() {
  log "Running mkarchiso (this takes a while and downloads packages)"
  rm -rf "$WORK_DIR"
  mkdir -p "$WORK_DIR" "$OUT_DIR"
  mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
  ok "mkarchiso finished"
}

# ---- copy the ISO back to the Windows side ----------------------------------
copy_back() {
  local iso; iso="$(ls -t "${OUT_DIR}"/*.iso 2>/dev/null | head -1 || true)"
  [[ -n "$iso" ]] || die "No ISO produced in $OUT_DIR"

  log "Built: $iso ($(du -h "$iso" | cut -f1))"
  if [[ -d "${REPO_ROOT}" && "${REPO_ROOT}" == /mnt/* ]]; then
    mkdir -p "${REPO_ROOT}/out"
    local target="${REPO_ROOT}/out/$(basename "$iso")"
    log "Copying ISO to the Windows side (chunked, to dodge the WSL 9p ENOMEM bug)"
    # A plain cp/rsync of a multi-GB file onto the DrvFs/9p Windows mount can
    # fail with "cp: Cannot allocate memory". dd with small blocks avoids it.
    if dd if="$iso" of="$target" bs=4M conv=fsync 2>/dev/null; then
      ok "Copied ISO to Windows side: $target"
    else
      rm -f "$target" 2>/dev/null || true
      warn "Direct copy onto the Windows mount failed (known WSL limitation)."
      warn "Pull it from Windows PowerShell instead (reliable direction):"
      warn "  Copy-Item '\\\\wsl.localhost\\${WSL_DISTRO_NAME:-archlinux}\\root\\grgos-build\\out\\$(basename "$iso")' -Destination C:\\GrgOS-ISO\\"
    fi
  else
    warn "Repo is not on /mnt/c; leaving ISO in $OUT_DIR"
  fi
  printf '\n%s==>%s GrgOS ISO ready: %s\n' "$c_grn" "$c_reset" "$(basename "$iso")"
}

main() {
  preflight
  assemble_profile
  run_mkarchiso
  copy_back
}
main "$@"
