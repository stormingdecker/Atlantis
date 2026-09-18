#!/bin/bash
# Verify the AUDIO WIRING without an audio device: which track each (suite,tier)
# and each mission location resolves to, and whether those source files are
# non-silent. Runs the app headless (faithful to its real suite-scan +
# resolution) via ATLANTIS_AUDIOCHECK, then analyzes the referenced WAVs.
# For crossfade TIMING use tools/fadetest.sh. Usage: tools/audiocheck.sh
set -e
PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$PROJ_DIR/../Godot_v4.6.3-stable_linux.x86_64"
REPORT="/tmp/audiocheck.csv"
rm -f "$REPORT"
export ATLANTIS_AUDIOCHECK="$REPORT"
timeout 30 "$GODOT" --headless --path "$PROJ_DIR" > /tmp/audiocheck.log 2>&1 || true
unset ATLANTIS_AUDIOCHECK
python3 - "$REPORT" "$PROJ_DIR" << 'PY'
import sys, os, wave, struct, math
report, proj = sys.argv[1], sys.argv[2]
try: rows=[l.split(",",2) for l in open(report).read().splitlines()[1:] if l]
except Exception as e: print("no report:", e); sys.exit(0)
def res_to_fs(p):
    return p.replace("res://", proj.rstrip("/")+"/") if p.startswith("res://") else p
def analyze(path):
    fs=res_to_fs(path)
    if not path: return "MISSING (no track resolved)"
    if not os.path.exists(fs): return "FILE NOT FOUND"
    try:
        w=wave.open(fs,"rb"); fr=w.getframerate(); n=w.getnframes()
        raw=w.readframes(min(fr*2,n)); s=struct.unpack("<%dh"%(len(raw)//2),raw) if raw else []
        peak=max(abs(x) for x in s) if s else 0
        return f"{n/fr:.1f}s peak={peak} " + ("ok" if peak>100 else "SILENT")
    except Exception as e: return f"unreadable ({e})"
print(f"{'KIND':9} {'KEY':32} RESULT")
ok=True
for kind,key,path in rows:
    r=analyze(path)
    if "ok" not in r: ok=False
    print(f"{kind:9} {key:32} {r}")
print("\nRESULT:", "all tracks wired + non-silent ✓" if ok else "issues found ✗")
PY
