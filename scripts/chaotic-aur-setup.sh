#!/usr/bin/env bash

#    ░█▀▀░█░█░█▀█░█▀█░▀█▀░▀█▀░█▀▀░░░░░█▀█░█░█░█▀▄░░░█▀▀░█▀▀░▀█▀░█░█░█▀█
#    ░█░░░█▀█░█▀█░█░█░░█░░░█░░█░░░▄▄▄░█▀█░█░█░█▀▄░░░▀▀█░█▀▀░░█░░█░█░█▀▀
#    ░▀▀▀░▀░▀░▀░▀░▀▀▀░░▀░░▀▀▀░▀▀▀░░░░░▀░▀░▀▀▀░▀░▀░░░▀▀▀░▀▀▀░░▀░░▀▀▀░▀░░
# ----------------------------------------------------------------------

set -e

CHAOTIC_KEY="3056513887B78AEB"
PACMAN_CONF="/etc/pacman.conf"

# 1. Ensure Chaotic GPG key
if ! sudo pacman-key --list-keys "$CHAOTIC_KEY" &>/dev/null; then
    sudo pacman-key --recv-key "$CHAOTIC_KEY" --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key "$CHAOTIC_KEY"
fi

# 2. Ensure keyring
if ! pacman -Q chaotic-keyring &>/dev/null; then
    sudo pacman -U https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst
fi

# 3. Ensure mirrorlist
if ! pacman -Q chaotic-mirrorlist &>/dev/null; then
    sudo pacman -U https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst
fi

# 4. Ensure repo is correctly configured
if ! awk '
    /^\[chaotic-aur\]/      { in_section=1; found_section=1; next }
    /^\[/ && in_section     { in_section=0 }
    in_section && $0=="Include = /etc/pacman.d/chaotic-mirrorlist" { found_include=1 }
    END { exit !(found_section && found_include) }
' "$PACMAN_CONF"; then
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' \
        | sudo tee -a "$PACMAN_CONF" > /dev/null
fi

# 5. Sync databases
sudo pacman -Syyu --needed --noconfirm
