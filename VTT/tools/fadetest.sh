#!/bin/bash
# Measure the music crossfade envelope in REALTIME. No audio device needed:
# runs under the Dummy driver and logs music volume_db every frame while
# main.gd (ATLANTIS_FADETEST) switches tier mid-run. The volume tween runs on
# the scene clock, so the envelope is real time. Usage: tools/fadetest.sh
set -e
PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$PROJ_DIR/../Godot_v4.6.3-stable_linux.x86_64"
CSV="/tmp/fadetest.csv"
rm -f "$CSV"
Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 2
export DISPLAY=:99
export ATLANTIS_FADETEST="$CSV"
timeout 60 "$GODOT" --path "$PROJ_DIR" --rendering-driver opengl3 > /tmp/fadetest.log 2>&1 || true
kill "$XVFB_PID" 2>/dev/null || true
unset ATLANTIS_FADETEST
python3 - "$CSV" << 'PY'
import sys
try: lines=open(sys.argv[1]).read().splitlines()
except Exception as e: print("no CSV:", e); sys.exit(0)
rows=[l.split(",") for l in lines[1:] if l]
if not rows: print("no samples"); sys.exit(0)
ts=[float(r[0]) for r in rows]; vol=[float(r[1]) for r in rows]
print("t(s)  vol_dB  envelope")
step=max(1,len(rows)//26)
for i in range(0,len(rows),step):
    bar="#"*max(0,int((vol[i]+60)/3))
    print(f"{ts[i]:4.2f} {vol[i]:7.2f}  {bar}")
print(f"min={min(vol):.1f}dB max={max(vol):.1f}dB")
print("RESULT:", "crossfade dip seen ✓" if min(vol) < -20 else "no dip ✗")
PY
