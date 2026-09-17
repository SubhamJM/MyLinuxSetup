#!/usr/bin/env python3
import os
import sys
import glob
import json
import subprocess

def get_telemetry():
    bats = [
        b for b in glob.glob('/sys/class/power_supply/*')
        if os.path.exists(os.path.join(b, 'type')) and open(os.path.join(b, 'type')).read().strip() == 'Battery'
    ]
    if not bats:
        return {
            'percentage': 100,
            'status': 'AC Connected',
            'isCharging': False,
            'isFull': True,
            'powerW': 0.0,
            'voltageV': 0.0,
            'health': 100,
            'currentEnergyWh': 0.0,
            'fullEnergyWh': 0.0,
            'timeStr': 'Connected to AC Power',
            'chargeThreshold': 100,
            'refreshRate': 144,
            'kbdBacklight': 0,
            'topDrainers': []
        }

    bat = bats[0]

    def read_num(n):
        p = os.path.join(bat, n)
        if os.path.exists(p):
            try:
                return float(open(p).read().strip())
            except Exception:
                pass
        return 0.0

    def read_str(n, default=''):
        p = os.path.join(bat, n)
        if os.path.exists(p):
            try:
                return open(p).read().strip()
            except Exception:
                pass
        return default

    cap = int(read_num('capacity'))
    status = read_str('status', 'Discharging')
    is_charging = status.lower() == 'charging'
    is_full = (status.lower() in ('full', 'not charging')) and cap >= 95

    c_now = read_num('charge_now') or read_num('energy_now')
    c_full = read_num('charge_full') or read_num('energy_full')
    c_design = read_num('charge_full_design') or read_num('energy_full_design')
    cur = read_num('current_now') or read_num('power_now')
    v_now = read_num('voltage_now') or 11993000.0

    # Power in Watts & Voltage
    power_w = round((cur * v_now) / 1e12, 1)
    voltage_v = round(v_now / 1e6, 1)
    current_energy_wh = round((c_now * v_now) / 1e12, 1)
    full_energy_wh = round((c_full * v_now) / 1e12, 1)

    # Battery Health
    health = 100
    if c_design > 0:
        health = int(round((c_full / c_design) * 100))

    # Time remaining or time to full
    time_str = 'Calculating...'
    if is_full:
        time_str = 'Fully Charged'
    elif is_charging and cur > 0 and c_full > c_now:
        rem_hrs = (c_full - c_now) / cur
        hrs = int(rem_hrs)
        mins = int((rem_hrs - hrs) * 60)
        time_str = f'{hrs}h {mins}m until full' if hrs > 0 else f'{mins}m until full'
    elif not is_charging and cur > 0 and c_now > 0:
        rem_hrs = c_now / cur
        hrs = int(rem_hrs)
        mins = int((rem_hrs - hrs) * 60)
        time_str = f'{hrs}h {mins}m remaining' if hrs > 0 else f'{mins}m remaining'
    elif is_charging:
        time_str = 'Charging'
    else:
        time_str = f'{cap}% Discharging'

    # Asus Charge Control Threshold
    thresh = 100
    thresh_path = os.path.join(bat, 'charge_control_end_threshold')
    if os.path.exists(thresh_path):
        try:
            thresh = int(open(thresh_path).read().strip())
        except Exception:
            pass

    # Monitor Refresh Rate
    rr = 144
    try:
        m_out = subprocess.check_output(['hyprctl', 'monitors', '-j'], stderr=subprocess.DEVNULL).decode()
        m_data = json.loads(m_out)
        if m_data and 'refreshRate' in m_data[0]:
            rr = int(round(m_data[0]['refreshRate']))
    except Exception:
        pass

    # Keyboard Backlight
    kbd = 0
    kbd_path = '/sys/class/leds/asus::kbd_backlight/brightness'
    if os.path.exists(kbd_path):
        try:
            kbd = int(open(kbd_path).read().strip())
        except Exception:
            pass

    # Top CPU / Energy Draining Processes
    drainers = []
    try:
        ps_out = subprocess.check_output(['ps', '-eo', 'pid,%cpu,comm', '--sort=-%cpu'], stderr=subprocess.DEVNULL).decode().splitlines()
        seen = set()
        for line in ps_out[1:]:
            parts = line.strip().split(None, 2)
            if len(parts) == 3:
                try:
                    cpu_val = float(parts[1])
                except Exception:
                    continue
                comm = parts[2]
                cl = comm.lower()
                if cl in ('ps', 'python', 'python3', 'systemd', 'qs') or cl.startswith('[') or cl.startswith('kworker'):
                    continue
                if comm not in seen and cpu_val >= 0.1:
                    seen.add(comm)
                    icon = '󰘚'
                    name = comm
                    if 'zen' in cl or 'web' in cl: icon, name = '󰈹', 'Zen Browser'
                    elif 'firefox' in cl: icon, name = '󰈹', 'Firefox'
                    elif 'chrome' in cl or 'chromium' in cl: icon, name = '󰊯', 'Chrome'
                    elif 'brave' in cl: icon, name = '󰖟', 'Brave'
                    elif 'kitty' in cl: icon, name = '󰆍', 'Kitty'
                    elif 'alacritty' in cl or 'foot' in cl: icon, name = '󰆍', 'Terminal'
                    elif 'nvim' in cl: icon, name = '', 'Neovim'
                    elif 'hyprland' in cl: icon, name = '', 'Hyprland'
                    elif 'agy' in cl or 'antigravity' in cl: icon, name = '󰌠', 'AI CLI'
                    elif 'code' in cl: icon, name = '󰨞', 'VSCode'
                    elif 'discord' in cl or 'vesktop' in cl: icon, name = '󰙯', 'Discord'
                    elif 'spotify' in cl: icon, name = '󰓇', 'Spotify'
                    elif 'steam' in cl: icon, name = '󰓓', 'Steam'
                    elif 'obs' in cl: icon, name = '󰑋', 'OBS Studio'
                    elif 'vlc' in cl or 'mpv' in cl: icon, name = '󰕼', 'Media Player'
                    elif 'telegram' in cl: icon, name = '󰓧', 'Telegram'
                    drainers.append({'name': name, 'cpu': f'{cpu_val:.1f}%', 'cpuNum': cpu_val, 'icon': icon, 'pid': parts[0]})
                if len(drainers) >= 3:
                    break
    except Exception:
        pass

    return {
        'percentage': cap,
        'status': status,
        'isCharging': is_charging,
        'isFull': is_full,
        'powerW': power_w,
        'voltageV': voltage_v,
        'health': health,
        'currentEnergyWh': current_energy_wh,
        'fullEnergyWh': full_energy_wh,
        'timeStr': time_str,
        'chargeThreshold': thresh,
        'refreshRate': rr,
        'kbdBacklight': kbd,
        'topDrainers': drainers
    }

def toggle_refresh_rate():
    try:
        m_out = subprocess.check_output(['hyprctl', 'monitors', '-j'], stderr=subprocess.DEVNULL).decode()
        m_data = json.loads(m_out)
        curr_hz = 144
        if m_data and 'refreshRate' in m_data[0]:
            curr_hz = int(round(m_data[0]['refreshRate']))

        if curr_hz > 100:
            # Switch to 60Hz
            cmd = 'hl.monitor({ output = "eDP-1", mode = "1920x1200@60.00", position = "auto", scale = "1.20" })'
        else:
            # Switch to 144Hz
            cmd = 'hl.monitor({ output = "eDP-1", mode = "1920x1200@144.00", position = "auto", scale = "1.20" })'

        subprocess.run(['hyprctl', 'eval', cmd], capture_output=True)
        print(json.dumps({'status': 'ok', 'newRate': 60 if curr_hz > 100 else 144}))
    except Exception as e:
        print(json.dumps({'status': 'error', 'message': str(e)}))

def toggle_kbd_backlight():
    try:
        kbd_path = '/sys/class/leds/asus::kbd_backlight/brightness'
        curr = 0
        if os.path.exists(kbd_path):
            curr = int(open(kbd_path).read().strip())
        new_val = 2 if curr == 0 else 0
        subprocess.run(['brightnessctl', "--device=asus::kbd_backlight", 'set', str(new_val)], capture_output=True)
        print(json.dumps({'status': 'ok', 'kbdBacklight': new_val}))
    except Exception as e:
        print(json.dumps({'status': 'error', 'message': str(e)}))

def set_charge_threshold(val):
    try:
        val_int = int(val)
        if val_int not in (60, 80, 100):
            print(json.dumps({'status': 'error', 'message': 'Invalid threshold. Use 60, 80, or 100'}))
            return
        subprocess.Popen(['pkexec', 'sh', '-c', f'echo {val_int} > /sys/class/power_supply/BAT1/charge_control_end_threshold'])
        print(json.dumps({'status': 'ok', 'chargeThreshold': val_int}))
    except Exception as e:
        print(json.dumps({'status': 'error', 'message': str(e)}))

def main():
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == 'toggle_hz':
            toggle_refresh_rate()
        elif cmd == 'toggle_kbd':
            toggle_kbd_backlight()
        elif cmd == 'set_threshold' and len(sys.argv) > 2:
            set_charge_threshold(sys.argv[2])
        elif cmd == 'telemetry':
            print(json.dumps(get_telemetry()))
        else:
            print(json.dumps(get_telemetry()))
    else:
        print(json.dumps(get_telemetry()))

if __name__ == '__main__':
    main()
