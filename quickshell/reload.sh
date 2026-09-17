#!/bin/bash

quickshell kill 2>/dev/null
pkill -9 quickshell 2>/dev/null
pkill -9 qs 2>/dev/null
while pgrep -x quickshell >/dev/null || pgrep -x qs >/dev/null; do sleep 0.05; done
sleep 0.1
setsid quickshell >/dev/null 2>&1 &

