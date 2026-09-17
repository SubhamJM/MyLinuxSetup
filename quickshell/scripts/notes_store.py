#!/usr/bin/env python3
import sys
import os
import json

NOTES_FILE = os.path.expanduser("~/.cache/quickshell/notes.json")

def ensure_file():
    os.makedirs(os.path.dirname(NOTES_FILE), exist_ok=True)
    if not os.path.exists(NOTES_FILE):
        default_data = {
            "scratchpad": "",
            "todos": []
        }
        with open(NOTES_FILE, "w", encoding="utf-8") as f:
            json.dump(default_data, f, indent=2)

def load_data():
    ensure_file()
    try:
        with open(NOTES_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        return {"scratchpad": "", "todos": []}

def save_data(data):
    ensure_file()
    try:
        temp_file = NOTES_FILE + ".tmp"
        with open(temp_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(temp_file, NOTES_FILE)
        return True
    except Exception as e:
        print(f"Error saving notes: {e}", file=sys.stderr)
        return False

def main():
    if len(sys.argv) < 2:
        print(json.dumps(load_data()))
        return

    cmd = sys.argv[1]

    if cmd == "load":
        print(json.dumps(load_data()))
    elif cmd in ("save_scratchpad_b64", "save_scratchpad_enc"):
        import urllib.parse
        content = urllib.parse.unquote(sys.argv[2])
        data = load_data()
        data["scratchpad"] = content
        save_data(data)
        print("OK")
    elif cmd in ("save_todos_b64", "save_todos_enc"):
        import urllib.parse
        content = urllib.parse.unquote(sys.argv[2])
        data = load_data()
        try:
            data["todos"] = json.loads(content)
            save_data(data)
            print("OK")
        except Exception as e:
            print(f"Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)
    elif cmd == "export_txt":
        import urllib.parse
        filepath = os.path.expanduser(sys.argv[2])
        content = urllib.parse.unquote(sys.argv[3])
        try:
            os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)
            print("OK:" + filepath)
        except Exception as e:
            print(f"Error exporting file: {e}", file=sys.stderr)
            sys.exit(1)
    elif cmd == "save_scratchpad":
        content = sys.stdin.read()
        data = load_data()
        data["scratchpad"] = content
        save_data(data)
        print("OK")
    elif cmd == "save_todos":
        content = sys.stdin.read()
        data = load_data()
        try:
            data["todos"] = json.loads(content)
            save_data(data)
            print("OK")
        except Exception as e:
            print(f"Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)
    elif cmd == "save_all":
        content = sys.stdin.read()
        try:
            parsed = json.loads(content)
            save_data(parsed)
            print("OK")
        except Exception as e:
            print(f"Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
