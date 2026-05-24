#!/bin/bash
# Detect AMD GPU and output paths for monitoring
for card in /sys/class/drm/card*; do
    gpufile="$card/device/gpu_busy_percent"
    if [ -f "$gpufile" ]; then
        echo "BUSY:$gpufile"
        memused="$card/device/mem_info_vram_used"
        memtotal="$card/device/mem_info_vram_total"
        if [ -f "$memused" ]; then echo "MEMUSED:$memused"; fi
        if [ -f "$memtotal" ]; then echo "MEMTOTAL:$memtotal"; fi
        if [ -f "$card/device/vendor" ] && [ -f "$card/device/device" ]; then
            vendor=$(cat "$card/device/vendor")
            device=$(cat "$card/device/device")
            gpuname=$(lspci -d "${vendor#0x}:${device#0x}" 2>/dev/null | head -1 | cut -d':' -f3- | sed 's/^ *//')
            if [ -n "$gpuname" ]; then
                shortname=$(echo "$gpuname" | grep -oP '\[\K[^\]]+' | tail -n 1)
                if [ -n "$shortname" ]; then
                    if [[ "$shortname" == *"RX 6600"* ]]; then
                        shortname="RX 6600 XT"
                    fi
                    gpuname="$shortname"
                fi
                echo "NAME:$gpuname"
            fi
        fi
        break
    fi
done
