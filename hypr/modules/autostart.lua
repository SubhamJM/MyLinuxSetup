-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function () 
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("qs")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("bash -c \"wl-paste --type text --watch cliphist store &\"")
    hl.exec_cmd("bash -c \"wl-paste --type image --watch cliphist store &\"")
	
--  to make the things more stable....
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk

end)



