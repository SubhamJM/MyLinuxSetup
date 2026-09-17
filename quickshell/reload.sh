#!/bin/bash

qs kill 2>/dev/null
while pgrep -x qs >/dev/null; do sleep 0.05; done
sleep 0.1
setsid qs >/dev/null 2>&1 &
