#!/usr/bin/env bash
# =============================================================================
# DDC setup script for Arch Linux + Hyprland
# Installs ddcutil and ddccontrol, configures kernel module and permissions
# so brightness can be controlled without sudo.
# Each step is checked before running — already-done steps are skipped.
# =============================================================================

set -e  # Exit immediately on any error

# Counters to summarise what was done at the end
SKIPPED=0
DONE=0

skip() { echo "   [SKIP] $1"; ((SKIPPED++)) || true; }
done_() { echo "   [DONE] $1"; ((DONE++)) || true; }

# -----------------------------------------------------------------------------
# 1. Detect available AUR helper (prefer paru > yay, fall back to pacman only)
# -----------------------------------------------------------------------------
echo ">> Detecting AUR helper..."
if command -v paru &>/dev/null; then
    AUR="paru"
    skip "paru found, will use it for AUR packages."
elif command -v yay &>/dev/null; then
    AUR="yay"
    skip "yay found, will use it for AUR packages."
else
    AUR=""
    skip "No AUR helper found. Only pacman (official repos) will be used."
fi

install_pkg() {
    local pkg="$1"
    # Check if already installed
    if pacman -Qi "$pkg" &>/dev/null; then
        skip "$pkg is already installed."
        return
    fi
    # Try official repos first, then AUR
    if pacman -Si "$pkg" &>/dev/null; then
        sudo pacman -S --needed --noconfirm "$pkg"
    elif [ -n "$AUR" ]; then
        $AUR -S --needed --noconfirm "$pkg"
    else
        echo "ERROR: $pkg not found in official repos and no AUR helper available."
        exit 1
    fi
    done_ "$pkg installed."
}

# -----------------------------------------------------------------------------
# 2. Install ddcutil (official repos) and ddccontrol (AUR)
# -----------------------------------------------------------------------------
echo ""
echo ">> Checking packages..."
install_pkg ddcutil
install_pkg ddccontrol
# ddccontrol-db provides the monitor XML database used by ddccontrol.
# Your LG monitor isn't in it, but it enables the generic fallback profile.
install_pkg ddccontrol-db

# -----------------------------------------------------------------------------
# 3. Load the i2c-dev kernel module (needed by both ddcutil and ddccontrol)
#    and make it persist across reboots.
# -----------------------------------------------------------------------------
echo ""
echo ">> Checking i2c-dev kernel module..."

# Check if module is currently loaded
if lsmod | grep -q "^i2c_dev"; then
    skip "i2c-dev module is already loaded."
else
    sudo modprobe i2c-dev
    done_ "i2c-dev module loaded."
fi

# Check if the persist config already exists with the right content
MODLOAD_FILE="/etc/modules-load.d/i2c-dev.conf"
if [ -f "$MODLOAD_FILE" ] && grep -q "^i2c-dev" "$MODLOAD_FILE"; then
    skip "i2c-dev already set to load on boot ($MODLOAD_FILE exists)."
else
    echo "i2c-dev" | sudo tee "$MODLOAD_FILE" > /dev/null
    done_ "i2c-dev will now load automatically on boot."
fi

# -----------------------------------------------------------------------------
# 4. Grant your user permission to access /dev/i2c-* without sudo.
#    ddcutil ships a udev rule file; we just need to add you to the i2c group.
# -----------------------------------------------------------------------------
echo ""
echo ">> Checking i2c group and permissions..."

# Check if i2c group exists
if getent group i2c &>/dev/null; then
    skip "i2c group already exists."
else
    sudo groupadd i2c
    done_ "i2c group created."
fi

# Check if current user is already in the i2c group
if id -nG "$USER" | grep -qw "i2c"; then
    skip "$USER is already in the i2c group."
else
    sudo usermod -aG i2c "$USER"
    done_ "$USER added to i2c group (re-login required)."
fi

# Check if our udev rule already exists with the right content
UDEV_RULE="/etc/udev/rules.d/99-i2c.rules"
UDEV_CONTENT='KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"'
if [ -f "$UDEV_RULE" ] && grep -qF "$UDEV_CONTENT" "$UDEV_RULE"; then
    skip "udev rule already exists ($UDEV_RULE)."
else
    echo "$UDEV_CONTENT" | sudo tee "$UDEV_RULE" > /dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    done_ "udev rule written and reloaded."
fi

# -----------------------------------------------------------------------------
# 5. Verify the setup — detect monitors via ddcutil
# -----------------------------------------------------------------------------
echo ""
echo ">> Verifying DDC detection..."
if ddcutil detect 2>/dev/null | grep -q "Display"; then
    skip "ddcutil already detects your monitor — no action needed."
    ddcutil detect
else
    echo "   WARNING: ddcutil could not detect a monitor yet."
    echo "   This is normal if the group change hasn't taken effect."
    echo "   Please log out and back in (or reboot), then run: ddcutil detect"
fi

# -----------------------------------------------------------------------------
# 6. Detect the correct i2c bus for your monitor and suggest script config
# -----------------------------------------------------------------------------
echo ""
echo ">> Detecting i2c bus for your monitor..."
BUS_LINE=$(ddcutil detect 2>/dev/null | grep "I2C bus" | head -1)
if [ -n "$BUS_LINE" ]; then
    BUS_NUM=$(echo "$BUS_LINE" | grep -oP '(?<=/dev/i2c-)\d+')
    skip "Bus already detected: dev:/dev/i2c-$BUS_NUM — no changes needed."
    echo ""
    echo "   Make sure your ddc-brightness.py has:"
    echo "       BUS = \"dev:/dev/i2c-$BUS_NUM\""
else
    echo "   Could not auto-detect bus. After rebooting, run:"
    echo "       ddcutil detect"
    echo "   and set BUS in ddc-brightness.py accordingly."
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "================================================================"
echo " Summary: $DONE step(s) performed, $SKIPPED step(s) skipped."
if [ "$DONE" -gt 0 ]; then
    echo " IMPORTANT: Log out and back in (or reboot) for any group"
    echo " changes to take effect, then test with:"
    echo "     ddcutil detect"
    [ -n "$BUS_NUM" ] && echo "     ddccontrol -r 0x10 dev:/dev/i2c-$BUS_NUM"
else
    echo " Everything was already configured. No changes were made."
fi
echo "================================================================"