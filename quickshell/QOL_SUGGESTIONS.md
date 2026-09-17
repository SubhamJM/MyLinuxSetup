# Quickshell + Hyprland: Quality of Life (QoL) Feature Roadmap

This document outlines proposed Quality-of-Life (QoL) features and utility enhancements for the custom Dynamic Notch setup on Hyprland.

---

## 1. Daily Productivity & Fast Utilities

### 🧮 Inline Math & Unit/Currency Converter (Launcher) (✅ Completed)
- **Description**: Add real-time expression evaluation directly inside the existing `Launcher` search input.
- **Workflow**:
  - Typing `1280 * 720`, `(540 / 3) + 12.5`, `2^10`, `sqrt(144)`, or `15% of 850` renders the result immediately at the top of the launcher with 0ms latency.
  - Typing unit/currency conversions (e.g., `45 usd to inr`, `16 gb to mb`, `100 f to c`, `50 km to miles`) dynamically evaluated via GNU Qalculate (`qalc`).
  - Pressing `Enter` or clicking copies the computed answer directly to the clipboard with green checkmark toast confirmation.
- **Tools / Dependencies**: Native JavaScript safe math engine + `qalc` helper (`scripts/calc_helper.py`).

### ⏱️ Dynamic Island Pomodoro & Countdown Timer
- **Description**: A dedicated or quick-set timer integrated right into the notch.
- **Workflow**:
  - Quick presets: 25m Focus, 5m Short Break, 15m Long Break, or custom minute input.
  - When active, the idle notch displays an unobtrusive countdown indicator (e.g. `󱎫 24:18`).
  - When the countdown finishes, the Dynamic Island smoothly expands with a gentle chime, pulse glow, and completion banner.

### 📝 Quick Scratchpad & Todo Notes Module (✅ Completed)
- **Description**: A persistent micro-scratchpad accessible via shortcut (`Super+Shift+N`), bang (`!notes`), or from the Control Center.
- **Workflow**:
  - **Segmented Tab Switcher**: Seamlessly switch between freeform Scratchpad and Todo Tasks with fluid animated pill indicator.
  - **Scratchpad Tab**: Multi-line editor with live character/line counters, debounced auto-save to `~/.cache/quickshell/notes.json`, "Copy All" with visual feedback, and "Clear" button.
  - **Todo Tab**: Add tasks via input or Enter key, custom animated checkboxes with strikethrough completion, delete task buttons, "Clear Done" bulk purge, and live progress bar indicator.
  - **Keybind**: `Super + Shift + N` toggles directly (`quickshell:toggleNotesNotch`).
- **Tools / Dependencies**: `modules/NotesModule.qml` + atomic JSON storage engine `scripts/notes_store.py`.

---

## 2. System Hardware & Audio Control

### 📊 Real-Time Hardware Monitor & Process Killer
- **Description**: A performance dashboard module (or hover peek card) for system diagnostics.
- **Workflow**:
  - Real-time gauges/sparklines for CPU load (%), RAM usage (used / total GB), GPU / VRAM usage, and core temperatures.
  - "Top Consumers" list showing the top 3-5 resource-heavy processes.
  - One-click `󰅙 Terminate` button next to hung or runaway processes without needing `btop` or terminal `kill`.
- **Tools / Dependencies**: `/proc` polling, `sensors`, or `nvidia-smi` / `radeontop`.

### 🎧 Audio Device Quick Switcher (WirePlumber / PipeWire)
- **Description**: Fast audio sink (output) and source (microphone) selection.
- **Workflow**:
  - Sub-panel or dropdown inside the OSD / Quick Settings to seamlessly switch between Bluetooth headphones, built-in speakers, USB DACs, and external microphones.
  - Per-app audio stream volume sliders (e.g., lower Discord or Spotify independently).
- **Tools / Dependencies**: `wpctl` / `pactl`.

### 🌙 Night Light / Blue Light Filter (`hyprsunset`)
- **Description**: Screen warmth control to reduce eye strain during late hours.
- **Workflow**:
  - A simple toggle button and a color temperature slider (e.g., 6500K to 3500K) inside the notch.
  - Automatic sunset/sunrise scheduling or manual toggle via shortcut.
- **Tools / Dependencies**: `hyprsunset` or `gammastep`.

---

## 3. Screen & Creative Utilities

### 🎨 Screen Color Picker (`hyprpicker`)
- **Description**: Instant pixel color sampling with Dynamic Island visual feedback.
- **Workflow**:
  - Trigger via shortcut (e.g., `Super+Shift+C`) or notch button.
  - Screen freezes with a loupe; clicking any pixel captures the exact hex color.
  - Dynamic Island expands briefly showing the color swatch, Hex code, and RGB values, automatically copying the hex code to the clipboard.

### 🔍 Screen OCR / Snip-to-Text (`grim` + `slurp` + `tesseract`)
- **Description**: Extract unselectable text from images, videos, and PDFs on screen.
- **Workflow**:
  - Shortcut triggers selection box (`slurp`).
  - Screen crop is piped into `tesseract` OCR, and recognized text is automatically pushed to the clipboard and `ClipboardModule` history.
  - Dynamic Island briefly pops up showing preview text snippet with character count.

---

## 4. Multimedia Enhancements

### 🎵 Expanded Apple-Style Music Island (✅ Completed)
- **Description**: Turn the existing MPRIS media pill into an interactive player card.
- **Workflow**:
  - Automatically displays mini media pill in idle notch when music is playing.
  - Clicking on the media pill in idle mode, clicking the music button in the Control Center, or pressing `Super + Shift + M` expands the notch into the full player card (`activeMode === "music"`).
  - Features:
    - Rounded 72x72 album art card with fallback animated vinyl disc & tap-to-toggle overlay.
    - Track title, artist/album, and player identity pill (Spotify, Zen/Firefox, Chromium, MPV, VLC).
    - Apple-style 16-bar harmonic dynamic live audio equalizer (0% CPU impact).
    - Scrubbable interactive seek bar with elapsed & total duration timestamps, drag scrubbing, and mouse wheel seek (±5s).
    - Full playback controls: Shuffle toggle, Previous, Circular Play/Pause hero button, Next, Loop toggle.
    - Volume control: Mute/unmute button, compact slider, and mouse wheel volume adjustment (±5%).
    - Seamless navigation: Back button returns to Control Center (`utility`) if opened from there, or collapses to idle. Outside click & Escape support.

---

## 5. Launcher & Power User Features

### 🚀 Search Bangs & Direct Command Execution (Launcher) (✅ Completed)
- **Description**: Supercharged launcher search capabilities.
- **Workflow**:
  - **Web Search Bangs**:
    - `!g <query>` → Opens Google search in default browser
    - `!gh <query>` → Searches GitHub repositories
    - `!yt <query>` → Searches YouTube
    - `!w <query>` → Opens Wikipedia
    - `!aw <query>` / `!arch <query>` → Searches ArchWiki
    - `!d <query>` / `!ddg <query>` → Searches DuckDuckGo
    - `!keys` / `!?` → Opens Hyprland Keybind Cheat Sheet
    - `!notes` / `!todo` → Opens Quick Scratchpad & Todo Notes
  - **Direct Shell Command Execution**:
    - `> <command>` (e.g., `> btop`, `> neofetch`, `> ls -la`)
    - Smart auto-detection: TUI programs (`htop`, `btop`, `yazi`, `nano`, `vim`, `less`) automatically launch inside a `kitty` terminal window.
    - Background apps launch detached with zero terminal flicker.
    - `Shift + Enter` forces any command to run in `kitty`.

### ⌨️ Hyprland Keybind Cheat Sheet (✅ Completed)
- **Description**: A searchable 800x440 HUD modal showing all configured keybindings.
- **Workflow**:
  - Pressing `Super + /` (or clicking "Keys" in Control Center, or typing `!keys`) opens a categorized modal displaying all active Hyprland binds parsed directly from `~/.config/hypr/modules/keybinds.lua` and `hyprland.conf`.
  - Filter pills: All, Window, Workspaces, Launchers, Media, System.
  - Real-time search bar filtering across key combos and human-readable descriptions.
  - Physical keyboard-style keycap badges (`[SUPER]` `+` `[SHIFT]` `+` `[N]`, `[ALT]` `+` `[TAB]`).
  - One-click copy keybind or command to clipboard.

---

## Current Architecture Reference

The setup currently features:
- **MainDash**: Dynamic Island with persistent clock, battery pill, workspaces peek, MagSafe power alert, Bluetooth alert, Network handoff alert, and MPRIS ticker.
- **Expanded Modules**:
  1. `Launcher`: Fuzzy application runner with categories, inline math evaluation, search bangs, and shell execution.
  2. `ThemeSelector`: Live dynamic theming engine.
  3. `WallpaperSelector`: Live wallpaper grid switcher with swww.
  4. `TransitionSelector`: Live animation / transition selector.
  5. `Osd`: Volume and brightness HUD.
  6. `BluetoothModule`: Device list and pairing manager.
  7. `WifiModule`: Network selector and status.
  8. `RecorderModule`: Screen and audio recording interface.
  9. `BatteryModule`: Power statistics and profiles.
  10. `PowerMenu`: System logout, suspend, reboot, and shutdown.
  11. `CalendarModule`: Month calendar and event schedule.
  12. `ClipboardModule`: Searchable clipboard manager with pin/delete.
  13. `ShelfModule`: Drag-and-drop temporary file stash shelf.
  14. `NotificationModule`: Notification history center.
  15. `WindowSwitcher`: Alt-Tab keyboard/mouse window switcher.
  16. `MusicModule`: Apple-style expanded music island with live audio equalizer.
  17. `NotesModule`: Persistent micro-scratchpad and Todo task checklist.
  18. `KeybindsModule`: Searchable & categorized Hyprland keybinding cheat sheet HUD.
