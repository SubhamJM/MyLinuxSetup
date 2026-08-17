-- ==================================================
--  Base Window Rules & Transparency
-- ==================================================

hl.window_rule({
    name = "spotify-transparency",
    match = { class = "spotify" },
    opacity = "0.90 0.80"
})

hl.window_rule({
    name = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize"
})



-- ==================================================
--  Layer Rules (Blur)
-- ==================================================

hl.layer_rule({
    name = "waybar-blur",
    match = { namespace = "waybar" },
    blur = true,
    ignore_alpha = 0.0
})

hl.layer_rule({
    name = "rofi-blur",
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.0
})

hl.layer_rule({
    name = "logout-blur",
    match = { namespace = "logout_dialog" },
    blur = true,
    ignore_alpha = 0.0
})

hl.layer_rule({
    name = "logout-blur-fallback",
    match = { namespace = "wlogout" },
    blur = true,
    ignore_alpha = 0.0
})

hl.layer_rule({
    name = "swaync-blur",
    match = { namespace = "swaync-control-center" },
    blur = true,
    ignore_alpha = 0.0
})

hl.layer_rule({
    name = "caelestia-dashboard-blur",
    match = { namespace = "caelestia-dashboard" },
    blur = true,
    ignore_alpha = 0.0
})

hl.layer_rule({
    name = "fuzzel-blur",
    match = { namespace = "launcher" },
    blur = true,
    ignore_alpha = 0.2
})

hl.layer_rule({
    name = "quickshell-popups-no-blur",
    match = { namespace = "qs_popup" },
    blur = true
})


-- ==================================================
--  Floating, Centering & Dialog Rules
-- ==================================================

-- Grouped File Dialogs (Open, Save, etc)
hl.window_rule({
    match = { title = "^(Open File|Select a File|Open Folder|Save As|Library|File Upload|Add Folder to Workspace|Authentication [rR]equired)(.*)$" },
    float = true,
    center = true
})

hl.window_rule({
    match = { title = "^(.*)(wants to save|wants to open)$" },
    float = true,
    center = true
})

hl.window_rule({
    match = { title = "^(Choose wallpaper)(.*)$" },
    float = true,
    center = true,
    size = {"(monitor_w*0.60)", "(monitor_h*0.65)"}
})

hl.window_rule({
    match = { title = "(Open Files)" },
    float = true,
    size = {"(monitor_w*0.7)", "(monitor_h*0.6)"}
})

hl.window_rule({
    match = { class = "^(pavucontrol|org\\.pulseaudio\\.pavucontrol|com\\.saivert\\.pwvucontrol)$" },
    float = true,
    center = true,
    size = {"(monitor_w*0.45)", "(monitor_h*0.45)"}
})

hl.window_rule({
    match = { class = "^(nm-connection-editor)$" },
    float = true,
    center = true,
    size = {"(monitor_w*0.45)", "(monitor_h*0.45)"}
})

hl.window_rule({
    match = { class = "^(blueberry\\.py|guifetch|.*plasmawindowed.*|polkit-kde-authentication-agent-1)$" },
    float = true
})


-- ==================================================
--  Specific Utility Rules
-- ==================================================

hl.window_rule({
    match = { class = "^(plasma-changeicons)$" }, 
    float = true,
    no_initial_focus = true,
    move = {999999, 999999}
})

hl.window_rule({
    match = { title = "^(Copying — Dolphin)$" },
    move = {40, 80}
})

hl.window_rule({
    match = { class = "^dev\\.warp\\.Warp$" },
    tile = true
})

-- Master Picture-in-Picture Rule
hl.window_rule({
    name = "Master-PiP-Rule",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, 
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    move = {"72%", "7%"},
    size = {"(monitor_w*0.3)", "(monitor_h*0.3)"},
    opacity = "0.95 0.75"
})

hl.window_rule({
    match = { title = ".*is sharing (a window|your screen).*" }, 
    float = true,
    pin = true,
    move = {"(monitor_w*.5-window_w*.5)", "(monitor_h-window_h-12)"}
})


-- ==================================================
--  Gaming / Tearing
-- ==================================================

hl.window_rule({
    match = { title = ".*\\.exe|.*minecraft.*" },
    immediate = true
})

hl.window_rule({
    match = { class = "^(steam_app).*" },
    immediate = true
})


-- ==================================================
--  Workspaces
-- ==================================================

hl.window_rule({
    match = { initial_class = "(?i)spotify" },
    workspace = "special:music silent"
})

hl.window_rule({
    match = { initial_class = "(?i)discord" },
    workspace = "special:extra silent"
})

hl.window_rule({
    match = { initial_class = "(?i)webcord" },
    workspace = "special:extra silent"
})

hl.window_rule({
    match = { initial_class = "(?i)vesktop" },
    workspace = "special:extra silent"
})

hl.window_rule({
    match = { initial_class = "(?i)karere" },
    workspace = "special:extra silent"
})

hl.window_rule({
    match = { initial_class = "(?i)zapzap" },
    workspace = "special:extra silent"
})


-- ==================================================
--  KoolDots Tagging System
-- ==================================================

local function apply_window_rule(rule)
  if hl.window_rule then
    hl.window_rule(rule)
  end
end

-- --- Tags ---
apply_window_rule({
  name = "tag-browser",
  match = { class = "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin|[Gg]oogle-chrome(-beta|-dev|-unstable)?|chrome-.+-Default|[Cc]hromium|[Mm]icrosoft-edge(-stable|-beta|-dev|-unstable)|[Bb]rave-browser(-beta|-dev|-unstable)?|[Tt]horium-browser|[Cc]achy-browser|zen-alpha|zen)$" },
  tag = "+browser"
})

apply_window_rule({
  name = "tag-notifications-swaync",
  match = { class = "^(swaync-control-center|swaync-notification-window|swaync-client|class)$" },
  tag = "+notif"
})

apply_window_rule({
  name = "tag-terminal-emulators",
  match = { class = "^(ghostty|wezterm|Alacritty|kitty|kitty-dropterm)$" },
  tag = "+terminal"
})

apply_window_rule({
  name = "tag-email",
  match = { class = "^([Tt]hunderbird|org.mozilla.Thunderbird|eu.betterbird.Betterbird|org.gnome.Evolution)$" },
  tag = "+email"
})

apply_window_rule({
  name = "tag-projects",
  match = { class = "^(codium|codium-url-handler|VSCodium|VSCode|code|code-url-handler|jetbrains-.+|dev.zed.Zed|antigravity)$" },
  tag = "+projects"
})

apply_window_rule({
  name = "tag-screenshare-obs",
  match = { class = "^(com.obsproject.Studio)$" },
  tag = "+screenshare"
})

apply_window_rule({
  name = "tag-im",
  match = { class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop|[Ff]erdium|[Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap|org.telegram.desktop|io.github.tdesktop_x64.TDesktop|teams-for-linux|im.riot.Riot|Element)$" },
  tag = "+im"
})

apply_window_rule({
  name = "tag-games",
  match = { class = "^(gamescope|steam_app_\\\\d+)$" },
  tag = "+games"
})

apply_window_rule({
  name = "tag-games-proton",
  match = { xdg_tag = "^(proton-game)$" },
  tag = "+games"
})

apply_window_rule({
  name = "tag-gamestore",
  match = { class = "^([Ss]team|com.heroicgameslauncher.hgl)$" },
  tag = "+gamestore"
})

apply_window_rule({
  name = "tag-gamestore-lutris",
  match = { title = "^([Ll]utris)$" },
  tag = "+gamestore"
})

apply_window_rule({
  name = "tag-file-manager",
  match = { class = "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt|app.drey.Warp)$" },
  tag = "+file-manager"
})

apply_window_rule({
  name = "tag-wallpaper-waytrogen",
  match = { class = "^([Ww]aytrogen)$" },
  tag = "+wallpaper"
})

apply_window_rule({
  name = "tag-multimedia",
  match = { class = "^([Aa]udacious)$" },
  tag = "+multimedia"
})

apply_window_rule({
  name = "tag-multimedia-video",
  match = { class = "^([Mm]pv|vlc)$" },
  tag = "+multimedia_video"
})

apply_window_rule({
  name = "tag-settings",
  match = { class = "^(wihotspot(-gui)?|[Bb]aobab|org.gnome.[Bb]aobab|gnome-disks|file-roller|org.gnome.FileRoller|nm-applet|blueman-manager|qt5ct|qt6ct|xdg-desktop-portal-gtk|org.kde.polkit-kde-authentication-agent-1|[Rr]ofi|btrfs-assistant|timeshift-gtk)$" },
  tag = "+settings"
})

apply_window_rule({
  name = "tag-settings-rog",
  match = { title = "^(ROG Control|Kvantum Manager)$" },
  tag = "+settings"
})

apply_window_rule({
  name = "tag-viewer",
  match = { class = "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter|evince|eog|org.gnome.Loupe)$" },
  tag = "+viewer"
})


-- --- Tag Executions ---
apply_window_rule({
  match = { tag = "multimedia" },
  no_blur = true,
  opacity = 1.0
})

apply_window_rule({
  match = { tag = "browser" },
  opacity = "0.99 0.8"
})

apply_window_rule({
  match = { tag = "projects" },
  opacity = "0.9 0.8"
})

apply_window_rule({
  match = { tag = "im" },
  opacity = "0.94 0.86"
})

apply_window_rule({
  match = { tag = "file-manager" },
  opacity = "0.9 0.8"
})

apply_window_rule({
  match = { tag = "terminal" },
  opacity = "0.9 0.7"
})

apply_window_rule({
  match = { tag = "wallpaper" },
  float = true,
  center = true,
  size = "(monitor_w*0.7) (monitor_h*0.7)",
  opacity = "0.9 0.7"
})

apply_window_rule({
  match = { tag = "settings" },
  float = true,
  center = true,
  size = "(monitor_w*0.7) (monitor_h*0.7)",
  opacity = "0.8 0.7"
})

apply_window_rule({
  match = { tag = "viewer" },
  float = true,
  center = true,
  opacity = "0.82 0.75"
})

apply_window_rule({
  match = { tag = "multimedia_video" },
  no_blur = true,
  opacity = 1.0
})

apply_window_rule({
  match = { tag = "games" },
  no_blur = true,
  fullscreen = 0
})


-- ==================================================
--  System Tools & Utilities
-- ==================================================

apply_window_rule({
  match = { class = "([Zz]oom|onedriver|onedriver-launcher|^mpv|com.github.rafostar.Clapper|^[Qq]alculate-gtk)$" },
  float = true
})

apply_window_rule({
  match = { class = "^(xfce-polkit|mate-polkit|polkit-mate-authentication-agent-1)$", title = "^(Authentication required|Authentication Required)$" },
  float = true,
  center = true,
  size = "(monitor_w*0.35) (monitor_h*0.35)"
})

apply_window_rule({
  match = { class = "(codium|codium-url-handler|VSCodium)", title = "negative:(.*codium.*|.*VSCodium.*)" },
  float = true
})

apply_window_rule({
  match = { class = "^(com.heroicgameslauncher.hgl)$", title = "negative:(Heroic Games Launcher)" },
  float = true
})

apply_window_rule({
  match = { class = "^([Ss]team)$", title = "negative:^([Ss]team)$" },
  float = true
})

-- Centered Modals
apply_window_rule({
  match = { title = "^(SDDM Background)$" },
  float = true,
  center = true,
  size = "(monitor_w*0.16) (monitor_h*0.12)"
})

apply_window_rule({
  match = { class = "^(yad)$" },
  float = true,
  center = true,
  size = "(monitor_w*0.2) (monitor_h*0.2)"
})

apply_window_rule({
  match = { class = "^(hyprland-donate-screen)$" },
  float = true,
  center = true
})

apply_window_rule({
  match = { class = "^(nm-applet)$", title = "^(Wi-Fi Network Authentication Required)$" },
  center = true
})


-- Idle Inhibit
apply_window_rule({
  match = { fullscreen = true },
  idle_inhibit = "fullscreen"
})

apply_window_rule({
  match = { fullscreen = 1 },
  idle_inhibit = "fullscreen"
})

apply_window_rule({
  match = { class = ".*" },
  idle_inhibit = "fullscreen"
})

-- Opacities
apply_window_rule({
  match = { class = "^(gedit|org.gnome.TextEditor|mousepad)$" },
  opacity = "0.8 0.7"
})

apply_window_rule({
  match = { class = "^(deluge|seahorse)$" },
  opacity = "0.9 0.8"
})


-- Focus Rules
apply_window_rule({
  match = { class = "^(jetbrains-.*)$" },
  no_initial_focus = true
})

apply_window_rule({
  match = { title = "^(wind.*)$" },
  no_initial_focus = true
})


-- CachyOS & System Apps (Safer 2-condition match)
apply_window_rule({
  match = { class = "^(org.cachyos.KernelManager)$", title = "^(CachyOS Kernel Manager)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(mainline-gtk)$", title = "^(Mainline Kernels)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(org.kde.kwalletmanager)$", title = "^(Wallet Manager)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(nvidia-settings)$", title = "^(NVIDIA Settings)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(org.cachyos.cachyos-pi)$", title = "^(CachyOS Package Installer)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(com.shellyorg.shelly)$", title = "^(Shelly)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(CachyOSHello)$", title = "^(CachyOS Hello)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(octopi-cachecleaner)$", title = "^(Cache Cleaner - Octopi)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(octopi)$", title = "^(Octopi)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(octopi-repoeditor)$", title = "^(Repository Editor - Octopi)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(Bitwarden)$", title = "^(Bitwarden)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(hyprpwcenter)$", title = "^(Pipewire Control Center)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(garuda-assistant)$", title = "^(Garuda Assistant)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(com.github.hyprmod)$", title = "^(HyprMod)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

apply_window_rule({
  match = { class = "^(com.github.wwmm.easyeffects)$", title = "^(Easy Effects)$" },
  float = true, center = true, size = "(monitor_w*0.6) (monitor_h*0.6)"
})

-- Leftover Generic Apps
apply_window_rule({
  match = { class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" },
  float = true,
  center = true
})

apply_window_rule({
  match = { class = "(org.gnome.Calculator|qalculate-gtk)" },
  float = true,
  center = true,
  size = "(monitor_w*0.55) (monitor_h*0.45)"
})

apply_window_rule({
  match = { class = "^(io.github.amit9838.mousam)$" },
  float = true,
  center = true,
  size = "(monitor_w*0.7) (monitor_h*0.75)"
})

apply_window_rule({
  match = { class = "^([Ff]erdium)$" },
  float = true,
  center = true,
  size = "(monitor_w*0.6) (monitor_h*0.7)"
})

apply_window_rule({
  match = { class = "^(nz\\.co\\.mega\\.megasync)$" },
  float = true,
  center = true,
  size = "(monitor_w*0.1) (monitor_h*0.2)"
})

apply_window_rule({
  match = { class = "kitty-dropterm" },
  float = true
})
