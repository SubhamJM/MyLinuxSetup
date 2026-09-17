#!/usr/bin/env python3
import os
import json

def scan_themes():
    theme_dir = os.path.expanduser("~/.config/themes")
    if not os.path.exists(theme_dir):
        print(json.dumps([]))
        return

    themes = sorted(os.listdir(theme_dir))
    result = []

    for t in themes:
        p = os.path.join(theme_dir, t)
        if not os.path.isdir(p):
            continue

        bg = "#181825"
        accent = "#89b4fa"
        text = "#cdd6f4"
        palette = ["#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5"]

        # 1. Parse JSON color configs
        json_candidates = [
            os.path.join(p, "quickshell-colors.json"),
            os.path.join(p, "colors.json"),
            os.path.join(p, "theme.json"),
            os.path.join(p, "palette.json")
        ]

        found_json = False
        for jc in json_candidates:
            if os.path.exists(jc):
                try:
                    with open(jc, "r", encoding="utf-8") as f:
                        d = json.load(f)
                        bg = d.get("card_bg") or d.get("bg") or d.get("background") or bg
                        accent = d.get("accent") or d.get("primary") or d.get("color4") or accent
                        text = d.get("text_primary") or d.get("text") or d.get("foreground") or text
                        found_json = True
                        break
                except Exception:
                    pass

        # 2. Parse kitty-colors.conf for ANSI 1-6 palette swatches and fallback bg
        kc_path = os.path.join(p, "kitty-colors.conf")
        if os.path.exists(kc_path):
            c_map = {}
            try:
                with open(kc_path, "r", encoding="utf-8") as f:
                    for line in f:
                        parts = line.strip().split()
                        if len(parts) >= 2:
                            key = parts[0].lower()
                            val = parts[1]
                            if key.startswith("color"):
                                c_map[key] = val
                            elif key == "background" and not found_json:
                                bg = val
                            elif key == "foreground" and not found_json:
                                text = val

                p_extracted = [c_map.get(f"color{i}") for i in range(1, 7)]
                if all(p_extracted):
                    palette = p_extracted
            except Exception:
                pass

        result.append({
            "rawName": t,
            "themeName": t.lower(),
            "cardBg": bg,
            "accentColor": accent,
            "textColor": text,
            "palette": palette
        })

    print(json.dumps(result))

if __name__ == "__main__":
    scan_themes()
