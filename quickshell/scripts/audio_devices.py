#!/usr/bin/env python3
import sys
import json
import subprocess

def get_audio_info():
    try:
        sinks_out = subprocess.check_output(['pactl', 'list', 'sinks'], text=True, stderr=subprocess.DEVNULL)
        default_sink = subprocess.check_output(['pactl', 'get-default-sink'], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        sinks_out = ""
        default_sink = ""

    sinks = []
    curr = {}
    for line in sinks_out.splitlines():
        line = line.strip()
        if line.startswith('Sink #'):
            if curr: sinks.append(curr)
            curr = {'id': line.split('#')[1]}
        elif line.startswith('Name:'):
            curr['name'] = line.split(':', 1)[1].strip()
            curr['isDefault'] = (curr['name'] == default_sink)
        elif line.startswith('Description:'):
            curr['desc'] = line.split(':', 1)[1].strip()
    if curr: sinks.append(curr)

    try:
        sources_out = subprocess.check_output(['pactl', 'list', 'sources'], text=True, stderr=subprocess.DEVNULL)
        default_source = subprocess.check_output(['pactl', 'get-default-source'], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        sources_out = ""
        default_source = ""

    sources = []
    curr = {}
    for line in sources_out.splitlines():
        line = line.strip()
        if line.startswith('Source #'):
            if curr and '.monitor' not in curr.get('name', ''): sources.append(curr)
            curr = {'id': line.split('#')[1]}
        elif line.startswith('Name:'):
            curr['name'] = line.split(':', 1)[1].strip()
            curr['isDefault'] = (curr['name'] == default_source)
        elif line.startswith('Description:'):
            curr['desc'] = line.split(':', 1)[1].strip()
    if curr and '.monitor' not in curr.get('name', ''): sources.append(curr)

    return {"sinks": sinks, "sources": sources}

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "set-sink":
        subprocess.run(['pactl', 'set-default-sink', sys.argv[2]])
    elif len(sys.argv) > 2 and sys.argv[1] == "set-source":
        subprocess.run(['pactl', 'set-default-source', sys.argv[2]])
    else:
        print(json.dumps(get_audio_info()))
