#!/usr/bin/env bash
# ╭──────────────────────────────────────────────────────────────────╮
# │             Yozakura · Waybar Theme Installer                    │
# │          sakura petals drift through the status bar              │
# ╰──────────────────────────────────────────────────────────────────╯

set -euo pipefail

# ── constants ─────────────────────────────────────────────────────────
REPO="shunsui18/waybar"
BRANCH="main"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
DEST="${HOME}/.config/waybar"

PACMAN_PKGS=(
  waybar hyprland rofi wlogout playerctl swaync
  blueman bluez pulseaudio pwvucontrol ddccontrol
  nvidia-utils jq rfkill
)
AUR_PKGS=(wttrbar waybar-module-pacman-updates)

# ── terminal colours (tput, guarded) ──────────────────────────────────
if [[ -t 2 ]] && command -v tput &>/dev/null && tput colors &>/dev/null; then
  _r=$(tput setaf 1)
  _y=$(tput setaf 3)
  _g=$(tput setaf 2)
  _b=$(tput setaf 4)
  _m=$(tput setaf 5)
  _c=$(tput setaf 6)
  _w=$(tput bold)
  _0=$(tput sgr0)
else
  _r='' _y='' _g='' _b='' _m='' _c='' _w='' _0=''
fi

# ── helpers ───────────────────────────────────────────────────────────
info()    { printf '  %s❀%s  %s\n'        "${_b}" "${_0}" "$*"           >&2; }
warn()    { printf '  %s⚠%s  %s%s%s\n'   "${_y}" "${_0}" "${_y}" "$*" "${_0}" >&2; }
success() { printf '  %s✓%s  %s%s%s\n'   "${_g}" "${_0}" "${_g}" "$*" "${_0}" >&2; }
error()   { printf '  %s✗%s  %s%s%s\n'   "${_r}" "${_0}" "${_r}" "$*" "${_0}" >&2; }
section() {
  printf '\n  %s✦%s  %s%s%s\n\n' "${_m}" "${_0}" "${_w}" "$*" "${_0}" >&2
}
die() { error "$*"; exit 1; }

# ── remote / local mode detection ─────────────────────────────────────
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ "$SCRIPT_PATH" =~ ^/proc/self/fd/ ]] || [[ -z "$SCRIPT_PATH" ]]; then
  REMOTE=true
  THEMES_SRC=""
else
  REMOTE=false
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  THEMES_SRC="$SCRIPT_DIR"
fi

# ── fetch remote files ────────────────────────────────────────────────
fetch_remote() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  THEMES_SRC="$tmp"

  info "Fetching Yozakura Waybar files from GitHub…"

  # Declare remote file list
  local files=(
    "config.jsonc"
    "modules.jsonc"
    "style.css"
    "styles/color-map-yoru.css"
    "styles/color-map-hiru.css"
    "styles/yozakura-yoru.css"
    "styles/yozakura-hiru.css"
    "calander-module/clock-date-module-yoru.jsonc"
    "calander-module/clock-date-module-hiru.jsonc"
    "scripts/bluetooth-popup.sh"
    "scripts/bt-toggle.sh"
    "scripts/chaotic-aur-setup.sh"
    "scripts/ddc-brightness.py"
    "scripts/ddc-setup.sh"
    "scripts/gpu-temp.sh"
    "scripts/mpris-focus.sh"
    "scripts/volume-popup.sh"
    "scripts/waybar-module-pacman-updates.sh"
  )

  for f in "${files[@]}"; do
    mkdir -p "$tmp/$(dirname "$f")"
    if ! curl -fsSL "${RAW}/${f}" -o "$tmp/$f"; then
      warn "Could not fetch: $f"
    fi
  done

  success "Theme files downloaded."
}

# ── dependency installation ───────────────────────────────────────────
detect_aur_helper() {
  if command -v paru &>/dev/null; then printf 'paru'
  elif command -v yay &>/dev/null; then printf 'yay'
  else printf ''
  fi
}

# Run chaotic-aur-setup.sh to add the Chaotic-AUR repo, then install paru.
# Uses THEMES_SRC so it works before install_files copies scripts to $DEST.
bootstrap_aur_helper() {
  section "Bootstrapping AUR helper via Chaotic-AUR"

  local setup_script="$THEMES_SRC/scripts/chaotic-aur-setup.sh"

  if [[ ! -f "$setup_script" ]]; then
    warn "chaotic-aur-setup.sh not found at $setup_script"
    warn "Cannot bootstrap AUR helper — AUR packages will be skipped."
    return 1
  fi

  chmod +x "$setup_script"
  info "Running chaotic-aur-setup.sh…"
  if ! bash "$setup_script"; then
    warn "chaotic-aur-setup.sh exited with errors — AUR helper bootstrap may be incomplete."
    return 1
  fi

  # Chaotic-AUR ships paru; try it first, fall back to yay
  info "Installing paru from Chaotic-AUR…"
  if sudo pacman -S --needed --noconfirm paru 2>/dev/null; then
    success "paru installed."
  else
    warn "paru not found in repos — trying yay…"
    if sudo pacman -S --needed --noconfirm yay 2>/dev/null; then
      success "yay installed."
    else
      warn "Neither paru nor yay could be installed from Chaotic-AUR."
      return 1
    fi
  fi

  return 0
}

install_deps() {
  section "Installing dependencies"

  if ! command -v pacman &>/dev/null; then
    warn "pacman not found — skipping automatic dependency installation."
    warn "Install manually: ${PACMAN_PKGS[*]} ${AUR_PKGS[*]}"
    return
  fi

  # ── pacman packages ───────────────────────────────────────────────
  local missing_pacman=()
  for pkg in "${PACMAN_PKGS[@]}"; do
    pacman -Qi "$pkg" &>/dev/null || missing_pacman+=("$pkg")
  done

  if [[ ${#missing_pacman[@]} -gt 0 ]]; then
    info "Installing via pacman: ${missing_pacman[*]}"
    sudo pacman -S --needed --noconfirm "${missing_pacman[@]}" \
      || warn "Some pacman packages may have failed."
  else
    info "All pacman packages already present."
  fi

  # ── AUR packages ──────────────────────────────────────────────────
  local aur
  aur="$(detect_aur_helper)"

  # No helper found: attempt bootstrap via chaotic-aur-setup.sh
  if [[ -z "$aur" ]]; then
    warn "No AUR helper (paru/yay) found."
    if bootstrap_aur_helper; then
      aur="$(detect_aur_helper)"
    fi
  fi

  # Still no helper after bootstrap attempt: skip AUR packages
  if [[ -z "$aur" ]]; then
    warn "AUR helper unavailable — skipping AUR packages: ${AUR_PKGS[*]}"
    warn "Install them manually once an AUR helper is set up."
  else
    local missing_aur=()
    for pkg in "${AUR_PKGS[@]}"; do
      pacman -Qi "$pkg" &>/dev/null || missing_aur+=("$pkg")
    done

    if [[ ${#missing_aur[@]} -gt 0 ]]; then
      info "Installing via ${aur}: ${missing_aur[*]}"
      "$aur" -S --needed --noconfirm "${missing_aur[@]}" \
        || warn "Some AUR packages may have failed."
    else
      info "All AUR packages already present."
    fi
  fi

  success "Dependencies ready."
}

# ── copy config tree ──────────────────────────────────────────────────
install_files() {
  section "Copying config to ${DEST}"

  mkdir -p \
    "$DEST/styles" \
    "$DEST/calander-module" \
    "$DEST/scripts"

  # Root-level configs
  for f in config.jsonc modules.jsonc style.css; do
    if [[ -f "$THEMES_SRC/$f" ]]; then
      cp "$THEMES_SRC/$f" "$DEST/$f"
      info "Copied  ·  $f"
    else
      warn "Not found, skipping: $f"
    fi
  done

  # styles/
  for f in color-map-yoru.css color-map-hiru.css yozakura-yoru.css yozakura-hiru.css; do
    if [[ -f "$THEMES_SRC/styles/$f" ]]; then
      cp "$THEMES_SRC/styles/$f" "$DEST/styles/$f"
      info "Copied  ·  styles/$f"
    fi
  done

  # calander-module/
  for f in clock-date-module-yoru.jsonc clock-date-module-hiru.jsonc; do
    if [[ -f "$THEMES_SRC/calander-module/$f" ]]; then
      cp "$THEMES_SRC/calander-module/$f" "$DEST/calander-module/$f"
      info "Copied  ·  calander-module/$f"
    fi
  done

  # scripts/ (set executable)
  local scripts=(
    bluetooth-popup.sh bt-toggle.sh chaotic-aur-setup.sh ddc-brightness.py ddc-setup.sh
    gpu-temp.sh mpris-focus.sh volume-popup.sh waybar-module-pacman-updates.sh
  )
  for f in "${scripts[@]}"; do
    if [[ -f "$THEMES_SRC/scripts/$f" ]]; then
      cp "$THEMES_SRC/scripts/$f" "$DEST/scripts/$f"
      chmod +x "$DEST/scripts/$f"
      info "Copied  ·  scripts/$f"
    fi
  done

  success "Config tree installed."
}

# ── symlink management ────────────────────────────────────────────────
apply_symlinks() {
  local flavour="$1"
  section "Applying symlinks  ·  ${flavour}"

  # $DEST/color-map.css → styles/color-map-<flavour>.css  (relative)
  ln -sfn "styles/color-map-${flavour}.css" "$DEST/color-map.css"
  info "Linked  ·  color-map.css  →  styles/color-map-${flavour}.css"

  # $DEST/calander-module/clock-date-module.jsonc → clock-date-module-<flavour>.jsonc  (relative, same dir)
  ln -sfn "clock-date-module-${flavour}.jsonc" \
    "$DEST/calander-module/clock-date-module.jsonc"
  info "Linked  ·  calander-module/clock-date-module.jsonc  →  clock-date-module-${flavour}.jsonc"

  success "Symlinks active."
}

# ── DDC brightness setup ──────────────────────────────────────────────
run_ddc_setup() {
  section "Running DDC brightness setup"

  local ddc="$DEST/scripts/ddc-setup.sh"
  if [[ ! -f "$ddc" ]]; then
    warn "ddc-setup.sh not found at $ddc — skipping."
    return
  fi

  chmod +x "$ddc"
  if bash "$ddc"; then
    success "ddc-setup.sh completed."
  else
    warn "ddc-setup.sh exited with errors (exit $?)."
  fi
}

# ── interactive menu ──────────────────────────────────────────────────
show_menu() {
  printf '\n' >&2
  printf '  %s╭─────────────────────────────────────────────────╮%s\n' "${_m}" "${_0}" >&2
  printf '  %s│%s  %s✦%s  Yozakura  %s·%s  Waybar Theme Installer         %s│%s\n' \
    "${_m}" "${_0}" "${_w}" "${_0}" "${_c}" "${_0}" "${_m}" "${_0}" >&2
  printf '  %s│%s     sakura petals drift through the status bar  %s│%s\n' \
    "${_m}" "${_0}" "${_m}" "${_0}" >&2
  printf '  %s╰─────────────────────────────────────────────────╯%s\n' "${_m}" "${_0}" >&2
  printf '\n' >&2
  printf '     Select a theme flavour:\n\n' >&2
  printf '     %s[1]%s  Yoru  %s·  夜  ·  dark%s\n'  "${_c}" "${_0}" "${_b}" "${_0}" >&2
  printf '     %s[2]%s  Hiru  %s·  昼  ·  light%s\n' "${_c}" "${_0}" "${_b}" "${_0}" >&2
  printf '\n' >&2
  printf '  %s❀  %sChoice: %s' "${_m}" "${_w}" "${_0}" >&2

  local choice
  read -r choice
  printf '\n' >&2

  case "$choice" in
    1) printf 'yoru' ;;
    2) printf 'hiru' ;;
    *) die "Invalid selection: '${choice}'" ;;
  esac
}

# ── completion banner ─────────────────────────────────────────────────
show_banner() {
  local flavour="$1"
  local label
  case "$flavour" in
    yoru) label="Yoru  ·  夜  ·  dark" ;;
    hiru) label="Hiru  ·  昼  ·  light" ;;
  esac

  printf '\n' >&2
  printf '  %s╭─────────────────────────────────────────────────────╮%s\n' "${_g}" "${_0}" >&2
  printf '  %s│%s  %s✓%s  Yozakura Waybar installed                       %s│%s\n' \
    "${_g}" "${_0}" "${_w}" "${_0}" "${_g}" "${_0}" >&2
  printf '  %s│%s     Flavour  :  %s%-33s%s      %s│%s\n' \
    "${_g}" "${_0}" "${_c}" "$label" "${_0}" "${_g}" "${_0}" >&2
  printf '  %s│%s     Config   :  %s%-33s%s%s  │%s\n' \
    "${_g}" "${_0}" "${_b}" "$DEST" "${_0}" "${_g}" "${_0}" >&2
  printf '  %s│%s                                                     %s│%s\n' \
    "${_g}" "${_0}" "${_g}" "${_0}" >&2
  printf '  %s│%s     Restart waybar to apply the theme.              %s│%s\n' \
    "${_g}" "${_0}" "${_g}" "${_0}" >&2
  printf '  %s╰─────────────────────────────────────────────────────╯%s\n' "${_g}" "${_0}" >&2
  printf '\n' >&2
}

# ── argument parsing ──────────────────────────────────────────────────
usage() {
  printf '\n  Usage: %s [OPTIONS]\n\n' "$(basename "$0")" >&2
  printf '  Options:\n' >&2
  printf '    --theme <flavour>   Apply theme without prompting  (yoru|hiru)\n' >&2
  printf '    --skip-deps         Skip dependency installation\n' >&2
  printf '    --skip-ddc          Skip ddc-setup.sh\n' >&2
  printf '    -h, --help          Show this help\n\n' >&2
  exit 0
}

FLAVOUR=""
SKIP_DEPS=false
SKIP_DDC=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)
      [[ -n "${2:-}" ]] || die "--theme requires an argument: yoru or hiru"
      FLAVOUR="${2,,}"
      shift 2
      ;;
    --skip-deps) SKIP_DEPS=true; shift ;;
    --skip-ddc)  SKIP_DDC=true;  shift ;;
    -h|--help)   usage ;;
    *) die "Unknown option: $1  (use --help for usage)" ;;
  esac
done

[[ -z "$FLAVOUR" || "$FLAVOUR" == "yoru" || "$FLAVOUR" == "hiru" ]] \
  || die "Invalid flavour '${FLAVOUR}' — must be yoru or hiru."

# ── main ──────────────────────────────────────────────────────────────
main() {
  # Remote mode: download files first, before any menu
  if $REMOTE; then
    fetch_remote
  fi

  # Prompt if no --theme flag
  if [[ -z "$FLAVOUR" ]]; then
    FLAVOUR="$(show_menu)"
  fi

  # Dependencies
  if ! $SKIP_DEPS; then
    install_deps
  fi

  # Copy config tree
  install_files

  # Symlinks for chosen flavour
  apply_symlinks "$FLAVOUR"

  # DDC monitor brightness setup
  if ! $SKIP_DDC; then
    run_ddc_setup
  fi

  show_banner "$FLAVOUR"
}

main