#!/usr/bin/env bash

# Get Temperature and GPU Name
TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits)

# Define thresholds
WARNING=60
CRITICAL=80

# Default (Normal)
CLASS="normal"
ICON=""

if [ "$TEMP" -ge "$CRITICAL" ]; then
    CLASS="critical"
    ICON=""
elif [ "$TEMP" -ge "$WARNING" ]; then
    CLASS="warning"
    ICON=""
fi

# Output JSON with the GPU name in the tooltip field
echo "{\"text\": \"$TEMP°C $ICON\", \"class\": \"$CLASS\", \"tooltip\": \"$GPU_NAME\"}"