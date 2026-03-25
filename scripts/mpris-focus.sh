#!/usr/bin/env bash

# Get the currently playing player (fallback to first available)
player=$(playerctl -a status 2>/dev/null | awk '$2=="Playing"{print $1; exit}')
[ -z "$player" ] && player=$(playerctl -l 2>/dev/null | head -n1)
[ -z "$player" ] && exit 0

# Normalize player name to lowercase
player_lc=$(echo "$player" | tr '[:upper:]' '[:lower:]')

# Find matching Hyprland window by class (case-insensitive)
addr=$(hyprctl clients -j | jq -r --arg p "$player_lc" '
  .[] | select(.class != null) |
  select((.class | ascii_downcase) | contains($p)) |
  .address
' | head -n1)

[ -z "$addr" ] && exit 0

# Focus the window
hyprctl dispatch focuswindow "address:$addr"
