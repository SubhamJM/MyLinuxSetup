#!/usr/bin/env bash
# Robust Cava runner for Quickshell
# Supports variable bar counts and dynamic pipewire audio streams

BARS="${1:-12}"
CONF_FILE="/tmp/cava_${BARS}_$$.conf"

cleanup() {
    rm -f "$CONF_FILE" 2>/dev/null
    exit 0
}

trap cleanup EXIT INT TERM

cat > "$CONF_FILE" << CAVA_EOF
[general]
framerate = 30
bars = ${BARS}
autosens = 1
sensitivity = 100
lower_cutoff_freq = 50
higher_cutoff_freq = 12000

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
bar_delimiter = 59
channels = mono
mono_option = average

[smoothing]
noise_reduction = 25
integral = 80
gravity = 90
monstercat = 1.2
CAVA_EOF

exec cava -p "$CONF_FILE" < /dev/null
