hl.config({
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,

        follow_mouse = 1,
        off_window_axis_events = 2,

        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.7
        }
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 0,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        enable_swallow = false,
        swallow_regex = "(foot|kitty|allacritty|Alacritty)",
        on_focus_under_fullscreen = 2,
        allow_session_lock_restore = true,
        session_lock_xray = true,
        initial_workspace_tracking = false,
        focus_on_activate = true
    },

    binds = {
        scroll_event_delay = 0,
        hide_special_on_workspace_change = true
    },

    cursor = {
        zoom_factor = 1,
        zoom_rigid = false,
        zoom_disable_aa = true,
        hotspot_padding = 1
    },

    xwayland = {
        force_zero_scaling = true
    }
})

-- Device-specific overrides (FLAT format)
hl.device({
    name = "ascf1201:00-2808:0231-touchpad",
    sensitivity = 0.3,
    accel_profile = "adaptive", 
    scroll_factor = 0.5,
    natural_scroll = true,
    tap_to_click = true,
    clickfinger_behavior = true
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


-- 3 finger swipe left/right → switch workspaces
hl.gesture({
    fingers = 3,
    direction = "vertical",
    action = "workspace",
    scale = 1.8 -- INCREASE THIS if the swipe still feels laggy/heavy
})

-- 4 finger swipe up → fullscreen
hl.gesture({
    fingers = 4,
    direction = "up",
    action = "fullscreen",
    scale = 1.5
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "scroll_move"
})


