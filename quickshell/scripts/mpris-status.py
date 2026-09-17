import dbus
import sys
import os
import urllib.request
import hashlib

try:
    bus = dbus.SessionBus()
    players = [n for n in bus.list_names() if n.startswith("org.mpris.MediaPlayer2.")]
    
    selected_player = None
    selected_props = None
    
    # Priority selection: Playing with title > Playing > Paused with title > Any with title
    candidates = []
    for p in players:
        try:
            proxy = bus.get_object(p, "/org/mpris/MediaPlayer2")
            props_iface = dbus.Interface(proxy, "org.freedesktop.DBus.Properties")
            props = props_iface.GetAll("org.mpris.MediaPlayer2.Player")
            status = str(props.get("PlaybackStatus", ""))
            meta = props.get("Metadata", {})
            title = str(meta.get("xesam:title", "")).strip()
            
            score = 0
            if status == "Playing":
                score = 100 if title else 80
            elif status == "Paused":
                score = 60 if title else 30
            elif title:
                score = 40
            else:
                score = 10
            
            candidates.append((score, p, props))
        except Exception:
            continue

    if candidates:
        candidates.sort(key=lambda x: x[0], reverse=True)
        selected_player = candidates[0][1]
        selected_props = candidates[0][2]
            
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
        
        # Cache remote artwork locally for fast & error-free QML loading
        if art.startswith("http://") or art.startswith("https://"):
            try:
                hash_val = hashlib.md5(art.encode()).hexdigest()
                cache_path = f"/tmp/mpris_art_{hash_val}.jpg"
                if not os.path.exists(cache_path) or os.path.getsize(cache_path) == 0:
                    urllib.request.urlretrieve(art, cache_path)
                art = f"file://{cache_path}"
            except Exception:
                pass

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
