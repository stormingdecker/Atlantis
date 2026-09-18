#!/bin/bash
# Atlantis VTT — self-driven iteration harness.
#
# One entry point for the edit -> render -> look loop on a display-less box.
# It handles every gotcha that bites here:
#
#   1. FUSE IS FATALLY SLOW. The project lives on a gdrive FUSE mount; running
#      Godot directly against it hangs for minutes (its startup filesystem scan
#      reads every file through FUSE). So we MIRROR the project to local disk
#      (~/.cache) and run Godot there. Local import ~10s + boot <1s, vs never.
#      Edits are made in the gdrive copy (durable source of truth); `sync`
#      rsyncs them to the local mirror before each run. Screenshots are copied
#      back to gdrive ../captures/.
#   2. The gdrive FUSE mount CANNOT hold an exec bit, so the Godot binary is
#      staged to ~/.cache and refreshed when the source changes.
#   3. Software GL (llvmpipe) is slow and the FIRST render compiles all shaders
#      (minutes); Godot persists them to the local .godot/ so later runs are
#      fast. This is meant to be backgrounded + polled: it prints RESULT: and
#      writes a marker file when done.
#
# Usage (run from anywhere; paths resolve off this script):
#   tools/iterate.sh check                 # sync + headless boot-validate (clean quit), report errors
#   tools/iterate.sh shot <label> [stage]  # sync + capture GM+projector PNGs -> ../captures/<label>_*.png
#                                           #   [stage] optional ATLANTIS_STAGE, e.g. arc01_knossos:knossos
#   tools/iterate.sh sync                  # just refresh the local mirror
#   tools/iterate.sh clean                 # kill stale Xvfb/godot (by pid; pkill is sandbox-blocked)
#
# Backgrounded pattern the agent uses (rendering can take minutes on cold cache):
#   nohup bash tools/iterate.sh shot v1 > /tmp/iter_v1.out 2>&1 &
#   # poll /tmp/atlantis_iterate.done for PASS/FAIL, then read ../captures/v1_*.png

set -uo pipefail

SRC_PROJ="$(cd "$(dirname "$0")/.." && pwd)"        # gdrive VTT (source of truth)
SRC_GODOT="$SRC_PROJ/../Godot_v4.6.3-stable_linux.x86_64"
CACHE="$HOME/.cache/atlantis-vtt"
GODOT="$CACHE/godot"
PROJ="$CACHE/VTT"                                    # local mirror (fast, exec-ok)
OUT_DIR="$SRC_PROJ/../captures"                      # screenshots land here (gdrive)
DISPLAY_NUM=":99"
NOISE='alsa|xkbcommon|pulse|PulseAudio|ALSA|V-Sync|vsync|Unreferenced static string'
MARKER="/tmp/atlantis_iterate.done"

log() { echo "[iterate] $*"; }
filter() { grep -ivE "$NOISE"; }

ensure_godot() {
  mkdir -p "$CACHE"
  if [[ ! -x "$GODOT" || "$SRC_GODOT" -nt "$GODOT" ]]; then
    log "staging Godot binary -> $GODOT"
    cp "$SRC_GODOT" "$GODOT" && chmod +x "$GODOT" || { log "FATAL: stage godot failed"; exit 2; }
  fi
}

sync_proj() {
  mkdir -p "$PROJ"
  # Keep the local .godot/ (import + shader cache) warm across runs; only
  # mirror sources. --delete so removed files disappear from the mirror too.
  log "sync gdrive -> local mirror"
  rsync -a --delete --exclude '.godot/' --exclude '*.import' "$SRC_PROJ/" "$PROJ/" 2>/tmp/rsync_err.log \
    || { log "FATAL: rsync failed ($(tail -1 /tmp/rsync_err.log))"; exit 2; }
}

kill_stale() {
  # pkill is blocked by the sandbox; kill by pid instead.
  for p in $(pgrep godot 2>/dev/null); do kill "$p" 2>/dev/null; done
  for p in $(pgrep Xvfb 2>/dev/null);  do kill "$p" 2>/dev/null; done
  sleep 1
}

report_errors() {  # $1=logfile -> 0 clean, 1 errors
  local errs
  errs="$(grep -iE "SCRIPT ERROR|Parse Error|ERROR: .*\.gd|Failed to load" "$1" 2>/dev/null | filter | head -30)"
  [[ -z "$errs" ]] && return 0
  echo "--- errors ---"; echo "$errs"; return 1
}

cmd_check() {
  ensure_godot; sync_proj; kill_stale
  local logf="/tmp/iter_check.log"
  log "import (local, ~10s)"
  timeout 120 "$GODOT" --headless --import --path "$PROJ" > /tmp/iter_import.log 2>&1
  log "boot-validate (headless, clean quit-after 60)"
  timeout 60 stdbuf -oL -eL "$GODOT" --headless --quit-after 60 --path "$PROJ" > "$logf" 2>&1
  local rc=$?
  if [[ $rc -ne 0 ]]; then log "WARN: boot did not clean-quit (exit $rc)"; fi
  if report_errors "$logf"; then
    log "RESULT: PASS (boots clean, no script errors)"; echo "PASS" > "$MARKER"
  else
    log "RESULT: FAIL (full log: $logf)"; echo "FAIL" > "$MARKER"
  fi
}

cmd_shot() {
  local label="${1:-shot}" stage="${2:-}"
  ensure_godot; sync_proj; kill_stale
  mkdir -p "$OUT_DIR"
  rm -f "/tmp/cap_${label}"_*.png "$MARKER"

  Xvfb "$DISPLAY_NUM" -screen 0 2560x1440x24 -ac +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
  local xvfb_pid=$!
  trap 'kill "$xvfb_pid" 2>/dev/null' EXIT
  sleep 2
  export DISPLAY="$DISPLAY_NUM" ATLANTIS_SCREENSHOT="/tmp/cap_$label"
  [[ -n "$stage" ]] && export ATLANTIS_STAGE="$stage"

  log "import (local; up to 120s)"
  timeout 120 "$GODOT" --headless --import --path "$PROJ" > "/tmp/cap_${label}_import.log" 2>&1
  # Cold shader cache compiles under llvmpipe (slow); warm runs are quick.
  log "render + capture (up to 300s cold / seconds warm)${stage:+, staged=$stage}"
  timeout 300 stdbuf -oL -eL "$GODOT" --path "$PROJ" --rendering-driver opengl3 > "/tmp/cap_$label.log" 2>&1

  kill "$xvfb_pid" 2>/dev/null; trap - EXIT

  echo "--- screenshot harness output ---"
  grep -i "\[screenshot\]" "/tmp/cap_$label.log" | filter || echo "(harness did not arm — see /tmp/cap_$label.log)"
  report_errors "/tmp/cap_$label.log" || true

  local ok=1
  for view in gm projector; do
    if cp "/tmp/cap_${label}_${view}.png" "$OUT_DIR/${label}_${view}.png" 2>/dev/null; then
      log "captured ${view}: $OUT_DIR/${label}_${view}.png ($(stat -c%s "$OUT_DIR/${label}_${view}.png" 2>/dev/null) bytes)"
    else
      log "MISSING ${view} png"; ok=0
    fi
  done
  if [[ "$ok" == 1 ]]; then
    log "RESULT: PASS"; echo "PASS $OUT_DIR/${label}_gm.png $OUT_DIR/${label}_projector.png" > "$MARKER"
  else
    log "RESULT: FAIL (full log: /tmp/cap_$label.log)"; echo "FAIL" > "$MARKER"
  fi
}

cmd_movie() {
  # Render a short deterministic clip of the projector view and encode to mp4.
  # Uses --fixed-fps so delta-driven flicker/particles advance a constant step
  # per captured frame (see main.gd ATLANTIS_MOVIE harness). Slow under llvmpipe.
  local label="${1:-clip}" stage="${2:-}" frames="${3:-45}" warmup="${4:-48}" fps="${5:-30}"
  ensure_godot; sync_proj; kill_stale
  mkdir -p "$OUT_DIR"
  local fdir="/tmp/mov_$label"; rm -rf "$fdir"; mkdir -p "$fdir"; rm -f "$MARKER"
  Xvfb "$DISPLAY_NUM" -screen 0 2560x1440x24 -ac +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
  local xvfb_pid=$!
  trap 'kill "$xvfb_pid" 2>/dev/null' EXIT
  sleep 2
  export DISPLAY="$DISPLAY_NUM"
  export ATLANTIS_MOVIE="$fdir/f" ATLANTIS_MOVIE_FRAMES="$frames" ATLANTIS_MOVIE_WARMUP="$warmup"
  [[ -n "$stage" ]] && export ATLANTIS_STAGE="$stage"
  log "import (local; up to 120s)"
  timeout 120 "$GODOT" --headless --import --path "$PROJ" > "/tmp/mov_${label}_import.log" 2>&1
  log "render movie ($frames frames @ fixed ${fps}fps, warmup $warmup)${stage:+, staged=$stage}"
  timeout 500 stdbuf -oL -eL "$GODOT" --path "$PROJ" --rendering-driver opengl3 --fixed-fps "$fps" > "/tmp/mov_$label.log" 2>&1
  kill "$xvfb_pid" 2>/dev/null; trap - EXIT
  report_errors "/tmp/mov_$label.log" || true
  local n; n=$(ls "$fdir"/f_*.png 2>/dev/null | wc -l)
  if [[ "$n" -lt 1 ]]; then log "RESULT: FAIL (no frames; see /tmp/mov_$label.log)"; echo "FAIL" > "$MARKER"; return; fi
  local out="$OUT_DIR/${label}.mp4"
  if command -v ffmpeg >/dev/null 2>&1; then
    if ffmpeg -y -framerate "$fps" -i "$fdir/f_%04d.png" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$out" > "/tmp/mov_${label}_ff.log" 2>&1; then
      log "RESULT: PASS ($n frames -> $out, $(stat -c%s "$out" 2>/dev/null) bytes)"; echo "PASS $out" > "$MARKER"
    else
      log "RESULT: FAIL (ffmpeg; see /tmp/mov_${label}_ff.log)"; echo "FAIL" > "$MARKER"
    fi
  else
    log "ffmpeg missing; PNG frames left in $fdir"; echo "PASS $fdir" > "$MARKER"
  fi
}

case "${1:-}" in
  check) cmd_check ;;
  shot)  shift; cmd_shot "$@" ;;
  movie) shift; cmd_movie "$@" ;;
  sync)  ensure_godot; sync_proj ;;
  clean) kill_stale; log "cleaned" ;;
  *) echo "usage: tools/iterate.sh {check | shot <label> [stage] | movie <label> <stage> [frames] [warmup] [fps] | sync | clean}"; exit 1 ;;
esac
