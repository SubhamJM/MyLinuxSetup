#!/usr/bin/env bash

# Freeze and select screen region with slurp (redirect stdin from /dev/null to avoid blocking on pipe)
GEOM=$(slurp < /dev/null 2>/dev/null)
if [ -z "$GEOM" ]; then
    exit 0
fi

# Tiny delay to ensure slurp selection overlay is completely cleared
sleep 0.1

# Capture screenshot of region with grim and run tesseract OCR
RAW_TEXT=$(grim -g "$GEOM" - | tesseract stdin stdout -l eng --psm 3 2>/dev/null)
if [ -z "$RAW_TEXT" ]; then
    RAW_TEXT=$(grim -g "$GEOM" - | tesseract stdin stdout -l eng --psm 6 2>/dev/null)
fi

# Clean up form feeds and trim leading/trailing whitespace
TEXT=$(printf "%s" "$RAW_TEXT" | tr -d '\f' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -n "$TEXT" ]; then
    # Copy to both system clipboard and primary selection
    printf "%s" "$TEXT" | wl-copy
    printf "%s" "$TEXT" | wl-copy --primary

    # Desktop notification via notify-send
    CHARS=${#TEXT}
    PREVIEW=$(printf "%s" "$TEXT" | tr '\n' ' ' | cut -c 1-100)
    notify-send -a "Screen OCR" -i edit-paste "Text Copied (${CHARS} chars)" "$PREVIEW"
else
    # Notify user that selection had no recognizable text
    notify-send -a "Screen OCR" -i dialog-warning "Screen OCR" "No text detected in selected region"
fi
