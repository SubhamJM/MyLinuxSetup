#!/usr/bin/env bash
# Inir Cava runner: connects to default PipeWire sink monitor
DEFAULT_SINK=$(pactl get-default-sink 2>/dev/null)
if [ -n "$DEFAULT_SINK" ]; then
    MONITOR="${DEFAULT_SINK}.monitor"
else
    MONITOR="auto"
fi

CONFIG_FILE="/tmp/cava_notch.conf"
cat > "$CONFIG_FILE" << CAVA_EOF
[general]
framerate = 60
bars = 5
autosens = 1
sensitivity = 100

[input]
method = pipewire
source = ${MONITOR}

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
channels = mono
mono_option = average

[smoothing]
noise_reduction = 20
CAVA_EOF

exec cava -p "$CONFIG_FILE"
