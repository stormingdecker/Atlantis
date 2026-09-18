---
name: godot-headless-iteration
description: Run the Atlantis VTT Godot app headlessly on a display-less devserver to capture screenshots of both windows (GM control + projector) AND test audio (crossfade timing, track wiring), so visuals and audio can be iterated on without a monitor or sound card. Use when working on the Atlantis VTT Godot project and you need to SEE what a change looks like (boot visuals, map/sector layout, tier colors, ambient effects) or VERIFY audio (music crossfades, which track plays per scene) but there is no display or audio device attached.
---

# Running the Atlantis VTT Godot iteration loop headlessly

The dev box has **no display** (`DISPLAY` is empty). Godot's plain `--headless`
mode runs GDScript but renders nothing (dummy driver), so you can't screenshot
it. The trick: a virtual X display (**Xvfb**) + Mesa **software** GL (llvmpipe)
+ an in-engine screenshot harness already wired into `main.gd`. This lets you
edit code/assets, render, and look at the result entirely from the shell.

## ⚡ Use `tools/iterate.sh` (the self-driven harness)

`VTT/tools/iterate.sh` wraps the whole loop and handles the traps below. Prefer it
over raw `capture.sh`.
- `bash tools/iterate.sh check` — sync + headless boot-validate (clean quit), reports script errors (~15s).
- `bash tools/iterate.sh shot <label> [stage]` — sync + capture GM+projector PNGs to `../captures/<label>_*.png`.
- `bash tools/iterate.sh sync|clean` — refresh the local mirror / kill stale procs.

Rendering can take minutes on a cold shader cache — **background it and poll**:
```bash
cd .../VTT && rm -f /tmp/atlantis_iterate.done
nohup bash tools/iterate.sh shot v1 > /tmp/iter_v1.out 2>&1 &
# poll /tmp/atlantis_iterate.done for PASS/FAIL, then Read ../captures/v1_*.png
```

## 🕳️ Three traps that WILL waste an hour if you forget them

1. **FUSE is fatally slow — never run Godot against the gdrive path.** The project
   is on a gdrive FUSE mount; Godot's startup filesystem scan reads every file
   through FUSE and hangs for minutes (banner prints, then nothing). Fix: mirror the
   project to LOCAL disk and run there. Local import ~10s, boot <1s. `iterate.sh`
   rsyncs `gdrive VTT -> ~/.cache/atlantis-vtt/VTT` and runs Godot on the mirror.
   **Edit the gdrive copy (source of truth); the harness syncs it before each run.**
2. **gdrive FUSE can't hold an exec bit.** `chmod +x` on the binary silently doesn't
   stick, so `./Godot...` => "Permission denied". Fix: the harness stages a runnable
   copy at `~/.cache/atlantis-vtt/godot` (refreshed when the source is newer).
3. **`pkill` is sandbox-blocked** (exit 144, kills your own command). Kill stale
   Godot/Xvfb by pid: `for p in $(pgrep godot); do kill "$p"; done`.

## Layout (paths are absolute on the devserver)

- Project root (source of truth, EDIT here): `/home/stormingdecker/gdrive/Decker53153/Atlantis/VTT`
- Local run mirror (Godot runs HERE): `~/.cache/atlantis-vtt/VTT`
- Godot source binary (non-exec on FUSE): `/home/stormingdecker/gdrive/Decker53153/Atlantis/Godot_v4.6.3-stable_linux.x86_64`
- Staged runnable binary: `~/.cache/atlantis-vtt/godot`
- Harness: `VTT/tools/iterate.sh` (wraps `capture.sh`'s mechanism + the traps above)
- Screenshots land in: `/home/stormingdecker/gdrive/Decker53153/Atlantis/captures/`

## The loop

1. Edit GDScript (`VTT/scripts/*.gd`) in the gdrive copy (source of truth) and/or
   regenerate assets (see below).
2. Capture (harness syncs to the local mirror first — see the ⚡ section):
   ```bash
   cd /home/stormingdecker/gdrive/Decker53153/Atlantis/VTT
   bash tools/iterate.sh shot <label>      # backgrounds well; poll /tmp/atlantis_iterate.done
   ```
   Writes `../captures/<label>_gm.png` and `../captures/<label>_projector.png`.
3. View the two PNGs (read them as images). The **projector** PNG is the real
   show — it has the live caustics + meteor glow. The **GM** PNG is the GM
   control window (map_preview): map + sectors + hex + tokens, no ambient FX.
4. Repeat. Use a fresh `<label>` (e.g. `v4`, `v5`) to keep a before/after trail.

> `tools/capture.sh` is the older raw wrapper; `iterate.sh` supersedes it (adds the
> local mirror, staged binary, and pid-based cleanup). Prefer `iterate.sh`.

## Audio testing (no sound card needed)

> ⚠️ These two wrappers predate the FUSE / local-mirror discovery and still invoke
> `../Godot...` directly against the gdrive project — so they hit the same
> fatally-slow FUSE scan + non-exec-binary traps (see the ⚡ section) and have NOT
> been re-verified since the folder move. To run them, point at the staged binary +
> local mirror (`~/.cache/atlantis-vtt/godot --path ~/.cache/atlantis-vtt/VTT`), or
> fold them into `iterate.sh` as `audio`/`fade` subcommands first. TODO.

Godot's Dummy audio driver (what `--headless` uses) outputs **pure silence**, so
audio is tested two ways — both run from `VTT/`:

**1. Crossfade timing / envelope — `tools/fadetest.sh`** (the reliable one).
Runs under the Dummy driver and logs the music `volume_db` every frame while
switching tier mid-run. The volume tween runs on the **scene clock**, so the
envelope is REAL TIME and measurable without any audio device. Prints an ASCII
envelope and a pass/fail (sees the crossfade dip toward −60 dB and recovery).
```bash
tools/fadetest.sh
```
Mechanism: `main.gd` `ATLANTIS_FADETEST=<csv>` starts the demo suite at
exploration, switches to combat at ~1.8 s, samples
`audio_controller.get_music_volume_db()` per frame.

**2. Track wiring + content — `tools/audiocheck.sh`.**
Headless (no device): reports which track each (suite, tier) and each mission
location resolves to — exercising the app's real suite-scan + resolution — then
analyzes those source WAVs on disk for non-silence/duration. Catches "wrong or
missing track wired for a scene" and "silent track."
```bash
tools/audiocheck.sh
```
Mechanism: `main.gd` `ATLANTIS_AUDIOCHECK=<csv>` writes the resolution report; the
wrapper peak-analyzes the referenced files with Python's `wave`.

**Limitation — capturing the live MIXED output to a WAV is NOT practical here.**
Tried and abandoned: the Dummy driver is silent; an ALSA `null` PCM doesn't pull
audio so the mixer idles (still silent); the ALSA `file` plugin *does* drive the
mixer but is unthrottled (no realtime sink on this kernel — `snd-dummy` absent,
PipeWire/Pulse daemon conflicts), producing multi-GB files and starving the main
loop; `AudioEffectRecord.get_recording()` then segfaults on the huge buffer.
So: verify mix *behavior* via the fade envelope (#1) and *content* via source
analysis (#2). Don't re-attempt raw-mix WAV capture unless a realtime virtual
sink becomes available.

## Asset generators (run BEFORE capture if you touched layout)

Order matters — the placeholder map reads the sector JSON:

```bash
cd /home/stormingdecker/gdrive/Atlantis/VTT
python3 tools/gen_sectors.py            # writes assets/maps/atlantis_sectors.json
python3 tools/gen_atlantis_placeholder.py   # writes assets/maps/atlantis.png (reads the sector JSON)
```

- `gen_sectors.py` — 16 sectors as annular wedges from ring radii + 45° slices.
  Tune the constants at the top (`R_INNER_LO/HI`, `R_OUTER_LO/HI`,
  `LABEL_R_INNER/OUTER`, `PAD_DEG`). Never hand-edit the JSON coordinates.
- `gen_atlantis_placeholder.py` — procedural 2048² placeholder map (pure stdlib
  PNG encoder, ~slow, run once per change). Ring-band radii near the top must
  match `gen_sectors.py`'s radii so the baked art aligns with the overlay.

## How the screenshot harness works (already in main.gd)

Gated behind the `ATLANTIS_SCREENSHOT` env var, so it is INERT during normal
runs. When set to a path prefix, `main.gd`:
- waits `_shot_delay_sec` (2.5s) of **wall-clock** time (lets the 1.5s boot
  crossfade finish + effects animate),
- saves `<prefix>_gm.png` (main window) and `<prefix>_projector.png`
  (`projector_window`, a Godot `Window` = `Viewport`, so `.get_texture()` works),
- calls `get_tree().quit()`.

`capture.sh` sets `ATLANTIS_SCREENSHOT=/tmp/cap_<label>` then copies the results
into `captures/`.

## What "success" looks like

`capture.sh` prints (from stderr, via `printerr`):
```
[screenshot] armed, prefix=/tmp/cap_<label> delay=2.5s
[screenshot] gm save rc=0
[screenshot] projector save rc=0
```
`rc=0` = Godot `OK`. Clean process exit is `0`. Both PNGs listed at the end.

## Gotchas (learned the hard way)

- **Capture must be TIME-based, not frame-based.** Software rendering (llvmpipe)
  is slow — a single frame can take seconds, so a frame counter (e.g. "180
  frames") may never complete inside the timeout and you get an empty run. The
  harness uses a wall-clock accumulator for this reason. Don't revert it.
- **Empty log / exit 124** = the `timeout` killed it before it captured. Usually
  means rendering was too slow OR the harness didn't arm. Bump the timeout in
  `capture.sh` or check the env var. Block-buffered stdout is lost on kill —
  that's why the harness diagnostics use `printerr` (stderr, unbuffered).
- **ALSA + xkbcommon errors are noise.** No sound card on the server → audio
  falls back to the dummy driver. The `dead_hamza` xkb errors are harmless.
  Filter them: `grep -ivE "alsa|xkbcommon"`.
- **Reimport after changing a PNG.** Changing `atlantis.png` makes Godot
  reimport on next run; first run may be slower.
- **Keep captures out of `res://`.** They live in `Atlantis/captures/` so Godot
  doesn't generate `.import` sidecars for screenshots. `VTT/.gitignore` also
  ignores `captures/`, `*.import`, `.godot/`.
- **STALE IMPORT CACHE — the nasty one.** After `gen_atlantis_placeholder.py`
  regenerates `atlantis.png`, the Godot binary may keep rendering the OLD baked
  map from `.godot/imported/atlantis.png-*.ctex` (the runtime, unlike the editor,
  doesn't always reimport). Symptom: stale geometry (e.g. old diamond sectors)
  shows UNDER the current overlay. `capture.sh` now runs `--headless --import`
  before each capture to rebuild the cache. If you ever bypass capture.sh and
  see ghost geometry, force it manually:
  ```bash
  rm -f .godot/imported/atlantis.png-*.ctex .godot/imported/atlantis.png-*.md5 assets/maps/atlantis.png.import
  ../Godot_v4.6.3-stable_linux.x86_64 --headless --import --path "$PWD"
  ```
  Diagnosis trick: `Image.load_from_file(<source>.png)` reads the raw file, while
  `load("res://...png").get_image()` reads the imported `.ctex`. Crop both and
  compare — if they differ, the import is stale.
- **Caustics shader: additive, not multiply.** `render_mode blend_mul` over a
  dark map is nearly invisible (it just faintly tints an already-dark surface).
  Use `render_mode blend_add` so bright ribbons ADD light. The shader is
  `shaders/underwater_caustics.gdshader`; tunables come from the sidecar's
  `underwater_caustics` block (`intensity`, `speed`, `tint`).
- **Inspecting a frame up close.** No PIL/ImageMagick on the box. Use Godot for
  Image ops (works in `--headless`, no GPU needed): a small `extends SceneTree`
  script that does `Image.load_from_file(...)`, `get_region(Rect2i(...))`,
  `resize(..., Image.INTERPOLATE_NEAREST)`, `save_png(...)`. Run with
  `--headless --script <file>` (wrap in `timeout`; it may not self-quit).

## One-time setup (already done on this box; redo on a fresh box)

```bash
sudo dnf install -y xorg-x11-server-Xvfb   # provides Xvfb + xvfb-run
```
Mesa/EGL (`libEGL_mesa`) is already present and gives the software GL context.
`capture.sh` starts `Xvfb :99` itself; no need to manage it manually.

## Just validate it boots (no rendering needed)

To catch script errors / missing assets fast, without a display. Wrap in
`timeout` — this project does not reliably self-quit in `--headless` (the
projector `Window` keeps the tree alive), so `--quit-after` may not fire:
```bash
cd /home/stormingdecker/gdrive/Atlantis/VTT
timeout 15 ../Godot_v4.6.3-stable_linux.x86_64 --headless 2>&1 | grep -ivE "alsa|xkbcommon" | head -40
```
Errors print within the first second or two. Any `SCRIPT ERROR` / `Parse Error`
/ `make_current`-style lines are real and worth fixing. (This is how the
camera-before-add_child bug in `projector.gd` was first caught.) Exit code will
be 124 from `timeout` — that's expected here, not a failure.
