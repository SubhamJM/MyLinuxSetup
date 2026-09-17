#!/usr/bin/env python3
import sys
import subprocess
import re

def get_battery(mac):
    try:
        info = subprocess.check_output(['bluetoothctl', 'info', mac], text=True, timeout=1.5)
        m = re.search(r'Battery Percentage:.*?\((\d+)\)', info)
        if m:
            return m.group(1) + '%'
    except Exception:
        pass
    return ''

def mode_current():
    import os
    if os.path.exists('/tmp/test_bt_connected'):
        try:
            with open('/tmp/test_bt_connected') as f:
                content = f.read().strip()
                if content:
                    print(content)
                    return
        except Exception:
            pass
    try:
        out = subprocess.check_output(['bluetoothctl', 'devices', 'Connected'], text=True, timeout=1.5).strip()
        lines = [l for l in out.split('\n') if l.strip().startswith('Device')]
        if lines:
            parts = lines[0].split(' ', 2)
            mac = parts[1]
            name = parts[2] if len(parts) > 2 else mac
            bat = get_battery(mac)
            print(f"1|{mac}|{name}|{bat}")
            return
    except Exception:
        pass
    print("0|||")

def mode_all():
    try:
        out = subprocess.check_output(['bluetoothctl', 'devices'], text=True, timeout=1.5).strip()
        for line in out.split('\n'):
            line = line.strip()
            if line.startswith('Device'):
                parts = line.split(' ', 2)
                if len(parts) >= 2:
                    mac = parts[1]
                    bat = get_battery(mac)
                    if bat:
                        print(f"{mac}={bat}")
    except Exception:
        pass

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--all':
        mode_all()
    else:
        mode_current()
