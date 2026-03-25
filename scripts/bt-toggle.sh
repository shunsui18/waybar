#!/usr/bin/env bash

POWERED=$(bluetoothctl show | grep -q 'Powered: yes' && echo "true" || echo "false")

rfkill unblock bluetooth

if [ "$POWERED" = "true" ]; then
    bluetoothctl power off
else
    bluetoothctl power on
fi

