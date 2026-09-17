#!/usr/bin/env python3
import sys
import re
import subprocess

def evaluate(query):
    q = query.strip()
    if not q:
        return ""

    # Normalization for temperature
    q = re.sub(r'\b([0-9\.\-]+)\s*f\s+(to|in)\s+c\b', r'\1 fahrenheit to celsius', q, flags=re.I)
    q = re.sub(r'\b([0-9\.\-]+)\s*c\s+(to|in)\s+f\b', r'\1 celsius to fahrenheit', q, flags=re.I)

    # Run qalc
    try:
        p = subprocess.run(['qalc', '-t', q], capture_output=True, text=True, timeout=1.2)
        out = p.stdout.strip()
        if out and not out.startswith('error') and 'unknown' not in out.lower():
            # Clean up redundant approx text if any
            out = re.sub(r'^approx\.\s*', '≈ ', out)
            return out
    except Exception:
        pass

    return ""

if __name__ == "__main__":
    if len(sys.argv) > 1:
        print(evaluate(" ".join(sys.argv[1:])))
