#!/usr/bin/env python3

import subprocess
import sys
import json
import re

# Configuration
STEP = 5
VCP = "0x10"
BUS = "dev:/dev/i2c-4"  # Fix 1: full bus path, not bare "4"
BASE_CMD = ["ddccontrol", "-r", VCP, BUS]  # Fix 2: bus comes before -w

def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.STDOUT).decode()
    except Exception:
        return ""

def get_monitor_name():
    try:
        hypr_out = run(["hyprctl", "-j", "monitors"])
        monitors = json.loads(hypr_out)
        for m in monitors:
            if m.get("focused"):
                return m.get("model", "Monitor")
        return "Monitor"
    except:
        return "Monitor"

def get_brightness():
    out = run(BASE_CMD)
    match = re.search(r"\+/(\d+)/\d+", out)
    if match:
        return int(match.group(1))
    return 50

def set_brightness(value):
    value = max(0, min(100, value))
    # Fix 2: -w value comes after the bus
    subprocess.call(
        ["ddccontrol", "-r", VCP, BUS, "-w", str(value)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )

try:
    if len(sys.argv) > 1:
        action = sys.argv[1]
        current = get_brightness()

        if action == "up":   set_brightness(current + STEP)
        elif action == "down": set_brightness(current - STEP)
        elif action == "max":  set_brightness(100)
        elif action == "min":  set_brightness(5)

    current = get_brightness()
    monitor_name = get_monitor_name()

    if current <= 20:
        icon, level = "󰃚 ", "level-1"
    elif current <= 40:
        icon, level = "󰃞 ", "level-2"
    elif current <= 60:
        icon, level = "󰃟 ", "level-3"
    elif current <= 80:
        icon, level = "󰃝 ", "level-4"
    else:
        icon, level = "󰃠 ", "level-5"

    print(json.dumps({
        "text": f"{icon} {current}%",
        "tooltip": monitor_name,
        "class": level
    }, ensure_ascii=False))

except Exception:
    print(json.dumps({"text": "󰃚 ", "tooltip": "Error", "class": "error"}, ensure_ascii=False))