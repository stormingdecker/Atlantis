#!/bin/bash
# Render the project under a virtual X display (Xvfb) and capture both
# windows to ../captures/<label>_{gm,projector}.png. Needs Xvfb + the Godot
# binary one dir above the project. Usage: tools/capture.sh [label]
set -e
LABEL="${1:-shot}"
PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$PROJ_DIR/../Godot_v4.6.3-stable_linux.x86_64"
OUT_DIR="$PROJ_DIR/../captures"
mkdir -p "$OUT_DIR"
Xvfb :99 -screen 0 2560x1440x24 -ac +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 2
export DISPLAY=:99
export ATLANTIS_SCREENSHOT="/tmp/cap_$LABEL"
rm -f "/tmp/cap_${LABEL}"_*.png
# Force a reimport first. Regenerating atlantis.png leaves Godot's import cache
# (.godot/imported/*.ctex) stale, so the runtime can render an OLD baked map
# under the current overlay. --import rebuilds the cache from current sources.
timeout 60 "$GODOT" --headless --import --path "$PROJ_DIR" > "/tmp/cap_${LABEL}_import.log" 2>&1 || true
timeout 150 "$GODOT" --path "$PROJ_DIR" --rendering-driver opengl3 > "/tmp/cap_$LABEL.log" 2>&1 || true
kill "$XVFB_PID" 2>/dev/null || true
cp "/tmp/cap_${LABEL}_gm.png" "$OUT_DIR/${LABEL}_gm.png" 2>/dev/null || echo "WARN: no gm png"
cp "/tmp/cap_${LABEL}_projector.png" "$OUT_DIR/${LABEL}_projector.png" 2>/dev/null || echo "WARN: no projector png"
grep -i screenshot "/tmp/cap_$LABEL.log" || true
ls -la "$OUT_DIR/${LABEL}"_*.png 2>/dev/null
