# Atlantis — Agent Notes

Hard-won operational knowledge that **is not recoverable from the code**. Written
2026-08-20 as a memory flush before a context pivot, so a fresh session (mine or
anyone's) doesn't have to rediscover any of it.

Where a fact already lives somewhere in the tree, this file points at it rather than
duplicating it. What's here is the stuff that only ever lived in an agent's head.

---

## 1. The environment

**`~/gdrive` is an mclone/rclone FUSE mount and its root view shifts between sessions.**
The same Atlantis folder has appeared as both `~/gdrive/Atlantis` and
`~/gdrive/Decker53153/Atlantis`. Never hardcode the deep path — resolve it fresh:
`find ~/gdrive -maxdepth 2 -iname Atlantis`.

Diagnose *down* vs *moved* before assuming an outage:

```bash
mountpoint ~/gdrive && ls ~/gdrive     # lists but wrong shape => root moved, not down
pgrep -af mclone                       # no daemon => genuinely down
bash ~/bin/gdrive-mount.sh             # remount; re-verify the path afterwards
```

**FUSE is fatally slow, and it cannot hold an exec bit.** Never run Godot or a build
against the mount — Godot's startup filesystem scan hangs for minutes. `iterate.sh`
handles this (mirrors to `~/.cache/atlantis-vtt`, stages a runnable Godot copy); its
header comment is the authoritative explanation.

**`pkill` is sandbox-blocked** (exit 144). Kill by pid.

**Not installed on this box:** ImageMagick (`identify`/`convert`), PIL, and `trash`.
Use `ffprobe`/`ffmpeg` for image inspection and `mv` to a `.retired` name instead of
deleting. `pip` is blocked.

**Drive is shared with other devservers and is addressed by folder ID, not path.**
Renaming a folder here does not stop another machine writing into it. Move, don't
delete, and say what you moved.

---

## 2. The one repo lesson that has bitten twice

**In this codebase, set derived state BEFORE emitting.**

Godot signals are synchronous. `SessionState` is the single source of truth and fans out
to `projector.gd` and `map_preview.gd` in the same call stack as the emit. The `map_fit`
bug (2026-08-13) was exactly this: `current_map_metadata_changed` fired before
`current_map_fit` was assigned, so every map staged after the home base projected at the
*previous* map's fit — 68% in a black box. Silent, and invisible until you look at a
render.

Any new derived field on `SessionState` needs the same discipline.

---

## 3. Iteration: look at the thing

`VTT/tools/iterate.sh` — verbs `check` / `shot <label> [stage]` / `movie` / `sync` /
`clean`. Stage strings are `campaign:mission:area:map`.

Cold shader cache takes **minutes** (llvmpipe compiles the caustics/meteor shaders, then
persists to the local `.godot/`). Background it and poll:

```bash
nohup bash tools/iterate.sh shot v1 "the_long_1910s:harbin:harbin:extraction" \
  > /tmp/iter_v1.out 2>&1 &
# poll /tmp/atlantis_iterate.done for PASS/FAIL, then Read ../captures/v1_projector.png
```

`movie` runs under `--fixed-fps` for deterministic capture — use it for particles,
flicker and lighting motion, which a still cannot show.

**Measuring, not just looking.** `ffprobe -f lavfi -i "movie=X.png,signalstats"
-show_entries frame_tags=lavfi.signalstats.YAVG,lavfi.signalstats.UAVG,lavfi.signalstats.VAVG`
gives mean luma and chroma. Useful sibling comparison: Harbin's four tiles should sit in
roughly the same YAVG band. `ROADMAP.md` item 6 proposes turning this into an
`iterate.sh luma` verb — worth doing before the map count grows past what one agent can
eyeball.

---

## 4. Lighting

The model is `time_of_day` × `season` as continuous 0..1 phases with four named anchor
stops each, folded with a cinematic grade. `DESIGN.md` §3.4 has the scene-block table.

Two things the table doesn't tell you:

**Named stops paint winter scenes wrong.** `"dusk"` turns snow and river ice sepia. For
winter night tiles use raw phase floats. The Harbin ladder that reads well: **0.60**
guarded interior with lamps on, **0.68** after-hours, **0.70** river rendezvous, **0.72**
rail yard.

**`light_energy` alone cannot fix a plate that was *generated* dark.** This cost two
render passes on 2026-08-20. At `time_of_day: 0.72` the tint is about
`(0.58, 0.62, 0.82)`; winter bias pushes it bluer still; and a night-generated plate
carries its own blue cast underneath. Energy scales that whole stack uniformly and never
touches the ratio, so you get *brighter blue mud*. You must push `light_grade` warm at
the same time. The rail yard landed on `light_energy: 1.85` +
`light_grade: [1.24, 1.02, 0.72]`, taking YAVG 25.4 → 46.7.

Conversely, a **relit** plate (one derived from a lit sibling via img2img) already
carries its own darkness, so the night grade multiplies to near-black. That is what
`light_energy` was added for — `harbin_epoch_site_dark` runs 1.7.

---

## 5. Art generation

Full recipe: `Wiki/Design-Notes/Map-Art-Generation.md`. Worked prompt scripts with the
exact strings that succeeded: `tools/pending.retired/`.

The lessons most likely to be re-learned the hard way:

- **"Top-down" alone does not hold for trains or interiors.** Nano Banana defaults to a
  cinematic ¾-aerial. What works is drone/nadir wording plus an explicit negation:
  *"photographed from a drone hovering directly above and pointing straight down at 90
  degrees … NOT ONE SIDE OR FACE of any object is visible anywhere in the frame."*
- **Buildings need roofs-off floor plans.** Roof-tops are useless for play. Walls as thin
  plan-view cuts, no visible wall height.
- **Style clashes are fixable without starting over.** `harbin_epoch_site` came back
  cel-shaded with heavy ink outlines against a painterly sibling; the `finish_maps.sh`
  REPAINT img2img pattern (repaint photoreal *from itself*, then re-derive the dark
  relight from the repaint) fixed it.
- **Never run 3+ `generate-image` (buck2) jobs in parallel** — they silently crash with a
  backtrace and no image. Sequential, or two at a time. Same for TTS.
- **Vertex throttling** surfaces as `PB-VERTEX-THROTTLING` / HTTP 429 and can last hours.
  Wrap generation in a retry with backoff (`sleep $((try*45))`, ~6 attempts).
- **House standard:** 2752×1536 (aspect 1.792), 16:9, pure terrain, no grid/text/UI —
  the app draws the hexes. Legacy `arc01_knossos` plates are 2048² and will pillarbox.

**Known trap:** `tools/finish_maps.sh`, `gen_pack.sh` and `remap_all.sh` all hardcode
`cd "$HOME/fbsource"`, which is **Decker's** checkout, not this instance's. Export
`ATLANTIS_FBSOURCE=~/fbsource-atlantis` and use a patched copy, or call the skill
directly. `buck2` resolves its project root from the cwd, which is the only reason a
checkout is needed at all.

---

## 6. Audio

`reference` detail lives in the wiki, but the operational facts:

- **TTS works token-free via buck2**, not the HTTP path (which needs an interactive OAuth
  token you cannot get headless):
  `buck2 run langtech/tts/service/client:tts_batch_client -- --id play_ai_<Voice> --tier
  shortwave.tts_router.thrift.prod --batch <tsv> --output /tmp/tts_%i.wav --audio_format wav`
  Use `play_ai_*` IDs; the `en_US.N` HTTP IDs crash the client. Confirmed-good:
  `play_ai_Briggs` (deep narrator), `play_ai_1P_Lady_Macbeth`, `play_ai_Nia`,
  `play_ai_B17_S06_OTHERWORLDLY`, `play_ai_B17_S27_WISE`. Samples in `captures/voices/`.
  Avoid real-celebrity clone voices for anything published.
- **Ambience beds are procedural** — `tools/gen_ambience.py` (24 s seamless stereo loops).
  The four original beds predate it and had no generator; it was written 2026-08-13.
  ffmpeg gotcha: `tremolo` minimum frequency is 0.1 Hz.
- **Music is Alexandre's**, written in Suno. All 16 authored scenes are on the
  placeholder `test_mission` suite. Do not generate music.

---

## 7. Current state, 2026-08-20

`ROADMAP.md` is the live list — 14 ranked recommendations, P0 items 1–3 done today.

Shortest honest summary: **the VTT works and the Wiki is nine missions ahead of it.**
14 mission write-ups exist; 4 are wired (Carpathian Cache, Fátima, Tarim, Ember
Extraction) plus a calibration demo, for 16 maps total. The engineering is in decent
shape; the gap is content and music.

The single biggest table-readiness gap is music, and it is not an agent's to close.
