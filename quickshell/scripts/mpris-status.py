import dbus
import sys

try:
    bus = dbus.SessionBus()
    players = [n for n in bus.list_names() if n.startswith("org.mpris.MediaPlayer2.")]
    
    selected_player = None
    selected_props = None
    
    # Priority: First player that is actually Playing
    for p in players:
        try:
            proxy = bus.get_object(p, "/org/mpris/MediaPlayer2")
            props_iface = dbus.Interface(proxy, "org.freedesktop.DBus.Properties")
            props = props_iface.GetAll("org.mpris.MediaPlayer2.Player")
            status = str(props.get("PlaybackStatus", ""))
            if status == "Playing":
                selected_player = p
                selected_props = props
                break
            elif not selected_props:
                selected_player = p
                selected_props = props
        except Exception:
            continue
            
    if selected_props:
        status = str(selected_props.get("PlaybackStatus", ""))
        meta = selected_props.get("Metadata", {})
        title = str(meta.get("xesam:title", ""))
        artists = meta.get("xesam:artist", [""])
        if isinstance(artists, (list, tuple, dbus.Array)) and len(artists) > 0:
            artist = str(artists[0])
        else:
            artist = str(artists) if artists else ""
        art = str(meta.get("mpris:artUrl", ""))
        try:
            pos = int(selected_props.get("Position", 0))
        except Exception:
            pos = 0
        try:
            length = int(meta.get("mpris:length", 0))
        except Exception:
            length = 0
        print(f"{status}\n{title}\n{artist}\n{art}\n{pos}\n{length}")
    else:
        print("\n\n\n\n\n")
except Exception:
    print("\n\n\n\n\n")
