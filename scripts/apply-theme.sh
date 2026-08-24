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
	ln -sf "$THEMES_DIR/$TARGET_THEME/starship-colors.toml" "$ACTIVE_DIR/starship-colors.toml"

	cp "$THEMES_DIR/$TARGET_THEME/gtk-colors.css" "$HOME/.config/gtk-3.0/gtk.css"
	cp "$THEMES_DIR/$TARGET_THEME/gtk-colors.css" "$HOME/.config/gtk-4.0/gtk.css"

	# --- 3. Update GSettings (for libadwaita & portal sync) ---
	gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
	gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

	# --- 4. Reload xsettingsd (if installed, for instant live GTK3 reloading) ---
	if command -v xsettingsd >/dev/null 2>&1; then
		killall -HUP xsettingsd 2>/dev/null
	fi

	# Update starship config by concatenating base and theme-specific configs

	cat "$HOME/.config/fish/base.toml" "$THEMES_DIR/$TARGET_THEME/starship-colors.toml" > "$HOME/.config/starship.toml"

	# Map active theme to the Neovim colorscheme name
	case "$TARGET_THEME" in
	  "Catppuccin")  NVIM_THEME="catppuccin-mocha" ;;
	  "Gruvbox")     NVIM_THEME="gruvbox" ;;
	  "Tokyo-night") NVIM_THEME="tokyonight-night" ;;
	  "Rose-pine")   NVIM_THEME="rose-pine" ;;
	  "Nord")        NVIM_THEME="nord" ;;
	  "Onedark")     NVIM_THEME="onedark" ;;
	  "Dracula")     NVIM_THEME="dracula" ;;
	  "Everforest")  NVIM_THEME="everforest" ;;
	  "Monokai-pro") NVIM_THEME="monokai-pro" ;;
	  "Ayu-mirage")  NVIM_THEME="ayu-mirage" ;;
	  "E-ink")       NVIM_THEME="e-ink" ;;
	  "Emerald")     NVIM_THEME="emerald" ;;
	  *)             NVIM_THEME="catppuccin" ;;
	esac

	# 1. Save current colorscheme to a dedicated state file
	mkdir -p "$HOME/.local/state/nvim"
	echo "$NVIM_THEME" > "$HOME/.local/state/nvim/active_colorscheme"

    # Reload components
	# 3. LIVE RELOAD ALL RUNNING KITTY INSTANCES (Paste here)
	kitty @ set-colors --all "$HOME/.config/kitty/kitty-colors.conf" 2>/dev/null

	# 4. Signal all Fish terminals to repaint Starship instantly
	killall -s SIGUSR1 fish 2>/dev/null
    hyprctl reload
    killall -SIGUSR1 kitty 2>/dev/null
	killall -SIGUSR1 nvim 2>/dev/null

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
