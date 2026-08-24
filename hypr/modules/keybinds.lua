---------------------
---- MY PROGRAMS ----
---------------------
           
local terminal    = "kitty"
local fileManager = "kitty --class yazi -e yazi"
local menu = "hyprlauncher"
local browser = "zen-browser"


local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- My keybinds (MAIN)
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("~/.config/quickshell/reload.sh"))
hl.bind(mainMod .. " + Space", hl.dsp.global("quickshell:toggleNotchLauncher"))
hl.bind(mainMod .. " + T", hl.dsp.global("quickshell:toggleThemeNotch"))
hl.bind(mainMod .. " + W", hl.dsp.global("quickshell:toggleWallpaperNotch"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.global("quickshell:toggleTransitionNotch"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.global("quickshell:toggleMusicInfoNotch"))
hl.bind(mainMod .. " + grave", hl.dsp.global("quickshell:resetNotchToIdle"))
hl.bind(mainMod .. " + D", hl.dsp.global("quickshell:toggleShelfNotch"))
hl.bind(mainMod .. " + N", hl.dsp.global("quickshell:toggleNotificationsNotch"))
hl.bind("Print", hl.dsp.exec_cmd('grimblast --notify copysave area'))

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
-- hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.global("quickshell:toggleClipboardNotch"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.global("quickshell:togglePowerMenuNotch"))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only


-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "d" }))

hl.bind(mainMod .. " + CONTROL + up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + CONTROL + down", hl.dsp.focus({ workspace = "r+1" }))

hl.bind(mainMod .. " + CONTROL + SHIFT + up", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + down", hl.dsp.window.move({ workspace = "r+1" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("~/.config/scripts/osd-control.sh volume_up"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("~/.config/scripts/osd-control.sh volume_down"),     { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("~/.config/scripts/osd-control.sh volume_mute"),     { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/scripts/osd-control.sh brightness_up"),  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/scripts/osd-control.sh brightness_down"),{ locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("~/.config/scripts/osd-control.sh kbd_up"),          { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("~/.config/scripts/osd-control.sh kbd_down"),        { locked = true, repeating = true })


-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


-- 2. Full Output (Entire Screen)
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd([[sh -c 'grim - | wl-copy && notify-send "Screenshot" "Full screen copied to clipboard"']]))

-- 3. Active Window
hl.bind(mainMod .. " + CTRL + Print", hl.dsp.exec_cmd([[sh -c 'hyprctl activewindow -j | jq -r "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" | grim -g - - | wl-copy && notify-send "Screenshot" "Window copied to clipboard"']]))

hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("fuzzel"), { on_release = true })

hl.bind("SUPER + M", hl.dsp.workspace.toggle_special("music"))
hl.bind("SUPER + D", hl.dsp.workspace.toggle_special("extra"))
