#!/usr/bin/env bash

# --- EDIT THESE VARIABLES ONLY ---
APP_EXEC="blueman-manager"       # The command used to launch the app
MATCH_CLASS="blueman-manager"   # The window class (get from 'hyprctl clients')
# Use the executable name for pgrep; if it's a python app, pgrep -f is safer
PROC_PATTERN="blueman-manager"  

# window size
S_X=700
S_Y=450

# mouse leave position
M=30

# ---------------------------------

# 0. Toggle: Kill if already running
if pgrep -f "$PROC_PATTERN" > /dev/null; then
    pkill -f "$PROC_PATTERN"
    exit 0
fi

# 1. Launch with specific Hyprland rules
hyprctl dispatch exec "[float;size $S_X $S_Y;move cursor -50% 12;stayfocused] $APP_EXEC"

# 2. Wait for Window & Warp Cursor
for i in {1..20}; do
    WINDOW_DATA=$(hyprctl activewindow -j)
    if [ "$(echo "$WINDOW_DATA" | jq -r '.class')" == "$MATCH_CLASS" ]; then
        # Geometry capture
        W_X=$(echo "$WINDOW_DATA" | jq -r '.at[0]')
        W_Y=$(echo "$WINDOW_DATA" | jq -r '.at[1]')
        W_W=$(echo "$WINDOW_DATA" | jq -r '.size[0]')
        W_H=$(echo "$WINDOW_DATA" | jq -r '.size[1]')
        
        MAX_X=$((W_X + W_W))
        MAX_Y=$((W_Y + W_H))

        # Center Warp
        CX=$((W_X + (W_W / 2)))
        CY=$((W_Y + (W_H / 2)))
        hyprctl dispatch movecursor $CX $CY
        break
    fi
    sleep 0.05
done

# 3. Monitor Loop (Process + Mouse Boundary)
while pgrep -f "$PROC_PATTERN" > /dev/null; do
    CPOS=$(hyprctl cursorpos | tr -d ' ')
    MX=${CPOS%,*}
    MY=${CPOS#*,}

    # Exit if mouse leaves window (with buffer)
    if (( MX < (W_X - $M) || MX > (MAX_X + $M) || MY < (W_Y - $M) || MY > (MAX_Y + $M) )); then
        break
    fi
    sleep 0.05
done

# 4. Cleanup
pkill -f "$PROC_PATTERN"