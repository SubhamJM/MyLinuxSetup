#!/bin/bash

# The theme name is now passed as the first argument ($1)
TARGET_THEME=$1
THEMES_DIR="$HOME/.config/themes"
ACTIVE_DIR="$HOME/.config/active-theme"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/$TARGET_THEME"

# Ensure target active directory exists
mkdir -p "$ACTIVE_DIR"

if [[ -d "$THEMES_DIR/$TARGET_THEME" ]]; then
    # Update symlinks
    ln -sf "$THEMES_DIR/$TARGET_THEME/hyprland-colors.conf" "$ACTIVE_DIR/hyprland-colors.conf"
    ln -sf "$THEMES_DIR/$TARGET_THEME/kitty-colors.conf" "$ACTIVE_DIR/kitty-colors.conf"
    ln -sf "$THEMES_DIR/$TARGET_THEME/quickshell-colors.json" "$ACTIVE_DIR/quickshell-colors.json"
    ln -sf "$THEMES_DIR/$TARGET_THEME/theme-name.txt" "$ACTIVE_DIR/theme-name.txt"

    # Reload components
    hyprctl reload
    killall -SIGUSR1 kitty 2>/dev/null

    # Read active transition (fallback to "simple" if file doesn't exist)
    TRANSITION="simple"
    if [[ -f "$ACTIVE_DIR/wallpaper-transition.txt" ]]; then
        TRANSITION=$(cat "$ACTIVE_DIR/wallpaper-transition.txt" | tr -d '\n')
    fi

    # Handle "random" transition mode
    if [[ "$TRANSITION" == "random" ]]; then
        TRANSITIONS=("simple" "fade" "left" "right" "top" "bottom" "wipe" "wave" "outer")
        TRANSITION=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}
    fi

    # Apply a random wallpaper from the active theme folder using awww
    if [[ -d "$WALLPAPER_DIR" ]]; then
        # Find images, pick one at random safely
        RANDOM_WALLPAPER=$(find "$WALLPAPER_DIR" -maxdepth 2 -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | shuf -n 1)

        if [[ -n "$RANDOM_WALLPAPER" ]]; then
            awww img "$RANDOM_WALLPAPER" \
                --transition-type "$TRANSITION" \
                --transition-fps 144 \
                --transition-step 240 \
                --transition-bezier "0.25,0.1,0.25,1.0"
        fi
    fi
    
    notify-send "Theme Applied" "Activated $TARGET_THEME"
else
    notify-send "Error" "Theme $TARGET_THEME does not exist."
fi
