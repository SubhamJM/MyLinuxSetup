hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0.5,
        accel_profile = 'flat',
        numlock_by_default = true,
        repeat_rate = 35,
        repeat_delay = 250,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            middle_button_emulation = false,
            scroll_factor = 0.5,
        }
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
    direction = "horizontal",
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