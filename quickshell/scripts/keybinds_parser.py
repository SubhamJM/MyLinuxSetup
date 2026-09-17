#!/usr/bin/env python3
import os
import re
import sys
import json
import shutil
import argparse
import subprocess

SPECIAL_KEYS = {
    "RETURN": "RETURN",
    "ENTER": "RETURN",
    "SPACE": "Space",
    "SLASH": "slash",
    "/": "slash",
    "GRAVE": "grave",
    "`": "grave",
    "TILDE": "grave",
    "TAB": "TAB",
    "ESCAPE": "Escape",
    "ESC": "Escape",
    "PRINT": "Print",
    "PRINTSCREEN": "Print",
    "LEFT": "left",
    "RIGHT": "right",
    "UP": "up",
    "DOWN": "down",
    "BACKSPACE": "BackSpace",
    "DELETE": "Delete",
    "DEL": "Delete",
    "HOME": "Home",
    "END": "End",
    "PAGEUP": "Prior",
    "PAGEDOWN": "Next"
}

def normalize_key_combo(combo):
    raw_tokens = [t.strip() for t in combo.replace("+", " ").split() if t.strip()]
    mods = []
    keys = []
    for t in raw_tokens:
        tu = t.upper()
        if tu in ("SUPER", "WIN", "CMD", "MOD4", "MAINMOD"):
            mods.append("SUPER")
        elif tu in ("SHIFT", "SHFT"):
            mods.append("SHIFT")
        elif tu in ("CTRL", "CONTROL"):
            mods.append("CONTROL")
        elif tu in ("ALT", "MOD1"):
            mods.append("ALT")
        elif tu in SPECIAL_KEYS:
            keys.append(SPECIAL_KEYS[tu])
        elif len(t) == 1:
            keys.append(t.upper())
        elif t.lower().startswith("f") and t[1:].isdigit():
            keys.append(t.upper())
        else:
            keys.append(t)

    ordered_mods = []
    for m in ["SUPER", "CONTROL", "ALT", "SHIFT"]:
        if m in mods and m not in ordered_mods:
            ordered_mods.append(m)

    all_tokens = ordered_mods + keys
    return " + ".join(all_tokens), all_tokens

def parse_hypr_lua(path):
    if not os.path.exists(path):
        return []

    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    vars_map = {"mainMod": "SUPER"}
    full_text = "".join(lines)
    for m in re.finditer(r'local\s+([a-zA-Z0-9_]+)\s*=\s*["\x27](.*?)["\x27]', full_text):
        vars_map[m.group(1)] = m.group(2)

    binds = []

    # Check for workspace loop
    if 'for i = 1, 10 do' in full_text:
        binds.append({
            "id": "loop_ws_focus",
            "lineNum": -1,
            "key": "SUPER + 1..0",
            "keys": ["SUPER", "1..0"],
            "desc": "Switch to Workspace 1 - 10",
            "cat": "Workspaces",
            "cmd": "hl.dsp.focus({ workspace = 1..10 })",
            "canDelete": False,
            "isCustom": False
        })
        binds.append({
            "id": "loop_ws_move",
            "lineNum": -1,
            "key": "SUPER + SHIFT + 1..0",
            "keys": ["SUPER", "SHIFT", "1..0"],
            "desc": "Move Window to Workspace 1 - 10",
            "cat": "Workspaces",
            "cmd": "hl.dsp.window.move({ workspace = 1..10 })",
            "canDelete": False,
            "isCustom": False
        })

    for idx, line_raw in enumerate(lines, 1):
        line = line_raw.strip()
        if not line.startswith("hl.bind"):
            continue

        m = re.match(r'hl\.bind\s*\(\s*(.+?)\s*,\s*(.+?)(?:,\s*(\{.*?\}))?\s*\)', line)
        if not m:
            continue

        raw_key = m.group(1).strip()
        raw_dsp = m.group(2).strip()

        # Check if preceding line is a custom metadata comment
        custom_desc = None
        custom_cat = None
        is_custom = False
        if idx > 1:
            prev_line = lines[idx - 2].strip()
            if prev_line.startswith("--"):
                if "desc:" in prev_line:
                    dm = re.search(r'desc:\s*([^|]+)', prev_line)
                    if dm:
                        custom_desc = dm.group(1).strip()
                if "cat:" in prev_line:
                    cm = re.search(r'cat:\s*([^|]+)', prev_line)
                    if cm:
                        custom_cat = cm.group(1).strip()
                if "custom:" in prev_line:
                    is_custom = True

        # Substitute variable names in raw_key
        for k, v in vars_map.items():
            raw_key = re.sub(r'\b' + k + r'\b', v, raw_key)

        clean_key = raw_key.replace('..', '').replace('"', '').replace("'", '').strip()
        clean_key = re.sub(r'\s+', ' ', clean_key)

        # Substitute variable names in raw_dsp
        clean_dsp = raw_dsp
        for k, v in vars_map.items():
            clean_dsp = re.sub(r'\b' + k + r'\b', v, clean_dsp)
        if not clean_dsp.endswith(")") and clean_dsp.count("(") > clean_dsp.count(")"):
            clean_dsp += ")" * (clean_dsp.count("(") - clean_dsp.count(")"))

        # Categorization & human readable descriptions
        cat = custom_cat or "System"
        desc = custom_desc or clean_dsp

        if not custom_desc or not custom_cat:
            # Smart category & description detection
            if "quickshell:toggleNotchLauncher" in clean_dsp:
                desc = "Open Notch App Launcher"
                cat = "Launchers"
            elif "quickshell:toggleThemeNotch" in clean_dsp:
                desc = "Open Notch Theme Selector"
                cat = "Launchers"
            elif "quickshell:toggleWallpaperNotch" in clean_dsp:
                desc = "Open Notch Wallpaper Selector"
                cat = "Launchers"
            elif "quickshell:toggleTransitionNotch" in clean_dsp:
                desc = "Open Notch Transition Selector"
                cat = "Launchers"
            elif "quickshell:toggleMusicInfoNotch" in clean_dsp:
                desc = "Expand Apple-Style Music Card"
                cat = "Media"
            elif "quickshell:resetNotchToIdle" in clean_dsp:
                desc = "Collapse Notch to Idle"
                cat = "System"
            elif "quickshell:toggleShelfNotch" in clean_dsp:
                desc = "Toggle File Stash Shelf"
                cat = "Launchers"
            elif "quickshell:toggleNotificationsNotch" in clean_dsp:
                desc = "Open Notification Center"
                cat = "System"
            elif "quickshell:toggleUtilityNotch" in clean_dsp:
                desc = "Open Dynamic Control Center"
                cat = "System"
            elif "quickshell:triggerScreenOcr" in clean_dsp:
                desc = "Snip Screen OCR (Copy text from image)"
                cat = "Media"
            elif "quickshell:cycleWindowNext" in clean_dsp:
                desc = "Alt-Tab: Cycle Next Window"
                cat = "Window"
            elif "quickshell:cycleWindowPrev" in clean_dsp:
                desc = "Alt-Tab: Cycle Previous Window"
                cat = "Window"
            elif "quickshell:toggleClipboardNotch" in clean_dsp:
                desc = "Open Clipboard History Manager"
                cat = "Launchers"
            elif "quickshell:togglePowerMenuNotch" in clean_dsp:
                desc = "Open Power Menu (Lock/Shutdown)"
                cat = "System"
            elif "quickshell:toggleNotesNotch" in clean_dsp:
                desc = "Open Quick Scratchpad & Todo Notes"
                cat = "Launchers"
            elif "quickshell:toggleCheatsheetNotch" in clean_dsp:
                desc = "Open Hyprland Keybind Cheat Sheet"
                cat = "Launchers"
            elif "exec_cmd" in clean_dsp:
                cat = "Launchers"
                if vars_map.get("browser", "zen-browser") in clean_dsp:
                    desc = f"Launch Web Browser ({vars_map.get('browser', 'Zen')})"
                elif vars_map.get("terminal", "kitty") in clean_dsp and "yazi" not in clean_dsp:
                    desc = f"Launch Terminal ({vars_map.get('terminal', 'Kitty')})"
                elif "yazi" in clean_dsp:
                    desc = "Launch Terminal File Manager (Yazi)"
                elif vars_map.get("menu", "hyprlauncher") in clean_dsp:
                    desc = "Launch App Menu"
                elif "grimblast" in clean_dsp:
                    desc = "Screenshot Area (Copy & Save)"
                    cat = "Media"
                elif "grim" in clean_dsp and "activewindow" in clean_dsp:
                    desc = "Screenshot Active Window"
                    cat = "Media"
                elif "grim" in clean_dsp:
                    desc = "Screenshot Full Screen"
                    cat = "Media"
                elif "osd-control.sh volume_up" in clean_dsp:
                    desc = "Raise Master Volume (+5%)"
                    cat = "Media"
                elif "osd-control.sh volume_down" in clean_dsp:
                    desc = "Lower Master Volume (-5%)"
                    cat = "Media"
                elif "osd-control.sh volume_mute" in clean_dsp:
                    desc = "Toggle Audio Mute"
                    cat = "Media"
                elif "osd-control.sh brightness_up" in clean_dsp:
                    desc = "Increase Screen Brightness (+5%)"
                    cat = "Media"
                elif "osd-control.sh brightness_down" in clean_dsp:
                    desc = "Decrease Screen Brightness (-5%)"
                    cat = "Media"
                elif "osd-control.sh kbd_up" in clean_dsp:
                    desc = "Increase Keyboard Backlight"
                    cat = "Media"
                elif "osd-control.sh kbd_down" in clean_dsp:
                    desc = "Decrease Keyboard Backlight"
                    cat = "Media"
                elif "playerctl next" in clean_dsp:
                    desc = "Media: Next Track"
                    cat = "Media"
                elif "playerctl previous" in clean_dsp or "playerctl prev" in clean_dsp:
                    desc = "Media: Previous Track"
                    cat = "Media"
                elif "playerctl play-pause" in clean_dsp:
                    desc = "Media: Play / Pause"
                    cat = "Media"
                elif "reload.sh" in clean_dsp:
                    desc = "Reload Quickshell Dynamic Island"
                    cat = "System"
                else:
                    cmd_match = re.search(r'exec_cmd\(\[?\[?(.*?)\]?\]?\)', clean_dsp)
                    if cmd_match:
                        raw_c = cmd_match.group(1).strip("\"'")
                        desc = f"Run `{raw_c}`"
                    else:
                        desc = clean_dsp

            elif "fullscreen" in clean_dsp:
                desc = "Toggle Maximized / Fullscreen"
                cat = "Window"
            elif "window.close" in clean_dsp:
                desc = "Close Focused Window"
                cat = "Window"
            elif "focus(" in clean_dsp:
                if "direction" in clean_dsp:
                    d = re.search(r'direction\s*=\s*["\x27](\w+)["\x27]', clean_dsp)
                    direction = d.group(1) if d else "relative"
                    desc = f"Move Focus Window ({direction})"
                    cat = "Window"
                elif "workspace" in clean_dsp:
                    desc = "Switch Focus Workspace"
                    cat = "Workspaces"
            elif "window.move" in clean_dsp:
                if "direction" in clean_dsp:
                    d = re.search(r'direction\s*=\s*["\x27](\w+)["\x27]', clean_dsp)
                    direction = d.group(1) if d else "relative"
                    desc = f"Move Window Position ({direction})"
                    cat = "Window"
                elif "workspace" in clean_dsp:
                    desc = "Move Window to Workspace"
                    cat = "Workspaces"
            elif "workspace.toggle_special" in clean_dsp:
                desc = "Toggle Scratchpad Workspace (magic)"
                cat = "Workspaces"
            elif "window.drag" in clean_dsp:
                desc = "Drag / Move Floating Window"
                cat = "Window"
            elif "window.resize" in clean_dsp:
                desc = "Resize Floating Window"
                cat = "Window"
            elif "togglesplit" in clean_dsp:
                desc = "Toggle Layout Split (Horizontal / Vertical)"
                cat = "Window"

        key_tokens = [k.strip() for k in clean_key.split("+") if k.strip()]

        binds.append({
            "id": f"b_{idx}",
            "lineNum": idx,
            "key": clean_key,
            "keys": key_tokens,
            "desc": custom_desc or desc,
            "cat": custom_cat or cat,
            "cmd": clean_dsp,
            "rawLine": line,
            "canDelete": True,
            "isCustom": is_custom
        })

    return binds

def add_keybind(key, cmd, desc="", cat="Custom"):
    path = os.path.expanduser("~/.config/hypr/modules/keybinds.lua")
    if not os.path.exists(path):
        return {"status": "error", "message": "keybinds.lua not found"}

    if not key or not key.strip():
        return {"status": "error", "message": "Key combination cannot be empty"}
    if not cmd or not cmd.strip():
        return {"status": "error", "message": "Command cannot be empty"}

    combo_str, key_tokens = normalize_key_combo(key)

    # Format Lua key definition
    if "SUPER" in key_tokens:
        non_super = [p for p in key_tokens if p != "SUPER"]
        if non_super:
            lua_key = f'mainMod .. " + {" + ".join(non_super)}"'
        else:
            lua_key = 'mainMod'
    else:
        lua_key = f'"{combo_str}"'

    clean_cmd = cmd.strip()
    if clean_cmd.startswith("hl.dsp."):
        lua_cmd = clean_cmd
    else:
        lua_cmd = f'hl.dsp.exec_cmd([[{clean_cmd}]])'

    desc_str = desc.strip() or f"Run `{clean_cmd}`"
    cat_str = cat.strip() or "Custom"

    backup_path = path + ".bak"
    shutil.copyfile(path, backup_path)

    comment_line = f"\n-- desc: {desc_str} | cat: {cat_str} | custom: true\n"
    bind_line = f"hl.bind({lua_key}, {lua_cmd})\n"

    with open(path, "a", encoding="utf-8") as f:
        f.write(comment_line + bind_line)

    # Validate Lua syntax with luac
    val = subprocess.run(["luac", "-p", path], capture_output=True, text=True)
    if val.returncode != 0:
        shutil.copyfile(backup_path, path)
        return {"status": "error", "message": f"Lua syntax error: {val.stderr.strip()}"}

    # Reload Hyprland
    subprocess.run(["hyprctl", "reload"], capture_output=True)
    return {
        "status": "ok",
        "message": f"Added keybind '{combo_str}'",
        "key": combo_str,
        "cmd": clean_cmd,
        "desc": desc_str,
        "cat": cat_str
    }

def match_bind_line(line, combo):
    m = re.match(r'hl\.bind\s*\(\s*(.+?)\s*,\s*(.+)', line.strip())
    if not m:
        return False
    raw_key = m.group(1).replace('mainMod', 'SUPER').replace('"', '').replace("'", '').replace('..', '').replace('+', ' ')
    line_tokens = sorted([t.strip().upper() for t in raw_key.split() if t.strip()])
    target_tokens = sorted([t.strip().upper() for t in combo.replace('+', ' ').split() if t.strip()])
    return line_tokens == target_tokens

def remove_keybind(line_num=None, key_combo=None, raw_line=None):
    path = os.path.expanduser("~/.config/hypr/modules/keybinds.lua")
    if not os.path.exists(path):
        return {"status": "error", "message": "keybinds.lua not found"}

    backup_path = path + ".bak"
    shutil.copyfile(path, backup_path)

    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    target_idx = None

    # 1. Match by exact raw line if provided
    if raw_line:
        clean_target = raw_line.strip()
        for idx, l in enumerate(lines):
            if l.strip() == clean_target:
                target_idx = idx
                break

    # 2. Match by 1-based line number if valid
    if target_idx is None and line_num is not None and 1 <= line_num <= len(lines):
        if lines[line_num - 1].strip().startswith("hl.bind"):
            target_idx = line_num - 1

    # 3. Match by key combo
    if target_idx is None and key_combo:
        for idx, l in enumerate(lines):
            if match_bind_line(l, key_combo):
                target_idx = idx
                break

    if target_idx is None:
        return {"status": "error", "message": f"Could not find keybind to remove"}

    remove_indices = {target_idx}
    # If the immediately preceding line is a comment metadata header, remove it too
    if target_idx > 0:
        prev = lines[target_idx - 1].strip()
        if prev.startswith("--") and ("desc:" in prev or "cat:" in prev or "custom:" in prev):
            remove_indices.add(target_idx - 1)

    new_lines = [l for i, l in enumerate(lines) if i not in remove_indices]

    with open(path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)

    # Validate Lua syntax with luac
    val = subprocess.run(["luac", "-p", path], capture_output=True, text=True)
    if val.returncode != 0:
        shutil.copyfile(backup_path, path)
        return {"status": "error", "message": f"Removal caused syntax error: {val.stderr.strip()}"}

    # Reload Hyprland
    subprocess.run(["hyprctl", "reload"], capture_output=True)
    return {"status": "ok", "message": "Keybind removed successfully"}

def main():
    parser = argparse.ArgumentParser(description="Hyprland keybindings manager and parser")
    subparsers = parser.add_subparsers(dest="subcommand")

    # list
    subparsers.add_parser("list", help="List all keybindings as JSON")

    # add
    add_p = subparsers.add_parser("add", help="Add a new keybinding")
    add_p.add_argument("--key", required=True, help="Key combination, e.g. 'SUPER + ALT + K'")
    add_p.add_argument("--cmd", required=True, help="Command to run, e.g. 'pavucontrol'")
    add_p.add_argument("--desc", default="", help="Description of the keybinding")
    add_p.add_argument("--cat", default="Custom", help="Category: Launchers, Window, Media, System, Custom")

    # remove
    rem_p = subparsers.add_parser("remove", help="Remove a keybinding")
    rem_p.add_argument("--line", type=int, default=None, help="1-based line number")
    rem_p.add_argument("--key", default=None, help="Key combination to match")
    rem_p.add_argument("--raw", default=None, help="Raw line content to match")

    args = parser.parse_args()

    if args.subcommand == "add":
        res = add_keybind(args.key, args.cmd, args.desc, args.cat)
        print(json.dumps(res))
    elif args.subcommand == "remove":
        res = remove_keybind(line_num=args.line, key_combo=args.key, raw_line=args.raw)
        print(json.dumps(res))
    else:
        # Default: list
        lua_path = os.path.expanduser("~/.config/hypr/modules/keybinds.lua")
        results = parse_hypr_lua(lua_path)
        print(json.dumps(results))

if __name__ == "__main__":
    main()
