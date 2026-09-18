# Atlantis VTT — Implementation Plan: migrating the app to DESIGN.md

> Companion to `DESIGN.md`. This is the **how**: concrete, file-by-file changes to
> move the *current* code (built through v0.8, plus the v0.9 missions scan already in
> `main.gd`/`session_state.gd`) onto the upgraded design. Grounded in the code as it
> stands today — function names and line references are real.
>
> **Scope of this doc = the foundation (DESIGN §8 v0.9 + the persistence split).**
> Get the content tree, the `scene` block, and the lighting model landed and the rest
> of the roadmap (events, Prep/Live UI, polish) sits cleanly on top. Later milestones
> are sketched in §6; detail them in follow-up plans once this lands.
>
> **Prime directive (from DESIGN §1): never break a running session.** Every step
> ships independently, keeps the app booting, and fails soft on bad data.

---

## 0. Where the code is today (the starting point)

- **`main.gd`** scans the filesystem and seeds `SessionState`. Already has
  `_scan_missions()` (`index.json` → `mission.json` → per-location leaf, keys
  `id/title/blurb/default_music_suite/locations[]`, each location = `{id,title,staging}`).
  Also has `DEMO_ON_BOOT`, `_stage_for_capture()`, and three env-gated test harnesses
  (`_process_screenshot/_process_audiocheck/_process_fadetest`) — **two of these read
  the mission/location/staging shape directly** and must move with it.
- **`session_state.gd`** is the single source of truth (autoload). Relevant pieces:
  `missions`, `set_missions()`, `get_mission()`, `apply_location_staging()`
  (`session_state.gd:558`); `SCENE_MOODS` const + `current_scene_mood` +
  `set_current_scene_mood()` (`:317`–`:375`); `current_ambient_effects` /
  `set_current_ambient_effects()` (`:401`,`:418`); persistence `save_session()` /
  `load_session()` (`:588`,`:609`) and the separate `facility_state` +
  `save/load_facility_state()` (`:495`,`:504`).
- **`projector.gd`** renders. `TintLayer` reads `SCENE_MOODS[mood].tint` on
  `current_scene_mood_changed` (`projector.gd:408`–`:413`); `ParticleLayer` maps the
  mood's particle preset; `AmbientLayer` under/over drive caustics/meteor glow from
  `current_ambient_effects`.
- **`map_preview.gd`** is the GM-side mirror of the projector (must mirror any new
  lighting/effects the projector gains).
- **`gm_window.gd`** builds the panel; `_build_atmosphere_section()` is a single mood
  dropdown; `_build_missions_section()` is Mission dropdown → Location list.

The mission-scan work already done is the perfect seam: we're **widening** it from
`Mission→Location(scene)` to `Campaign→Mission→Area→Map(scene)`, not starting over.

---

## 1. Step 1 — Lighting model (replaces welded "mood")

**Goal:** a scene's atmosphere = `time_of_day` × `season` (computed tint) + a separate
`effects` list. Old moods keep working as presets. Ship this first — it's isolated and
touches rendering, giving us a visible win with low blast radius.

**New authored file:** `assets/lighting.json` — the anchor table from DESIGN §3.5
(`time_of_day`: dawn/noon/dusk/midnight; `season`: spring/summer/autumn/winter, each
with `tint_bias` + `suggests`).

**`main.gd`:** in `_populate_libraries()`, read `res://assets/lighting.json` via the
existing `_read_json()` and pass it to a new `SessionState.set_lighting_model(dict)`.
Missing file ⇒ fall back to a hardcoded default table (never crash).

**`session_state.gd`:**
- Add state: `lighting_model: Dictionary`, `current_time_of_day: float` (0..1 phase),
  `current_season: float` (0..1 phase). Named stops map to phases
  (dawn=0, noon=0.25, dusk=0.5, midnight=0.75; spring=0…winter=0.75).
- Add `set_lighting_model()`, `set_time_of_day(phase_or_name)`, `set_season(...)`.
- Add `compute_scene_tint() -> Color`: interpolate between the two adjacent
  time-of-day anchors (wrapping), multiply by the interpolated season `tint_bias`,
  fold `brightness` into RGB. Pure function of the two phases + the model.
- New signal `scene_lighting_changed(tint: Color)`; emit it from both setters.
- **Keep `SCENE_MOODS`** but add `expand_mood(mood_id) -> {time_of_day, season, effects}`
  so a mood becomes a preset that drives the new state. `set_current_scene_mood()`
  stays as a convenience that calls the new setters + `set_scene_effects()`.
- Generalize effects: add `set_scene_effects(effect_ids: Array, config := {})` and
  signal `scene_effects_changed(effect_ids)`. (Fold the current mood-particle + the
  existing `current_ambient_effects` into one "effects" concept: particles *and*
  shader ambients are both entries in the catalog. Caustics/meteor stay driven by the
  map sidecar as they are today; particles now come from the scene's `effects`.)

**`projector.gd`:**
- `TintLayer`: stop reading `SCENE_MOODS`; instead connect `scene_lighting_changed` and
  set `_color = tint`. Seed from `compute_scene_tint()` in `_ready()`.
- `ParticleLayer`: connect `scene_effects_changed`; map each effect id → its particle
  preset; support the fixed catalog (snow/rain/leaves/embers/dust/ash). For v0.9 a
  single active particle set is fine (first catalog match wins); multi-particle can
  come later.
- Layer order unchanged (DESIGN §3.5): image → region → lighting tint → effects →
  sectors → hex → tokens → combat HUD.

**`map_preview.gd`:** mirror the same — subscribe to `scene_lighting_changed` /
`scene_effects_changed` so the GM preview matches the projector.

**`gm_window.gd`:** `_build_atmosphere_section()` — replace the lone mood dropdown with
two `HSlider`s (time-of-day, season) each labeled with its four named stops, plus keep
the mood presets as a compact quick-pick row. Wire sliders → `set_time_of_day/season`.

**Back-compat:** a saved `current_scene_mood` still restores (it expands to the new
state). No content authored yet needs `time_of_day`/`season`.

---

## 2. Step 2 — The content tree: Campaign → Mission → Area → Map

**Goal:** widen the scan + state from Mission→Location to the four-level tree, with a
shim so today's `assets/missions/` still loads.

**New layout** (DESIGN §3.1): `assets/campaigns/index.json` → `<c>/campaign.json` →
`<c>/<mission>/mission.json` → `<c>/<mission>/<area>.json` (each area lists `maps[]`,
each map has a `scene` block).

**`main.gd` — replace `_scan_missions()` with `_scan_campaigns()`:**
- New const `CAMPAIGNS_DIR := "res://assets/campaigns"`.
- Walk index → campaign.json (`missions[]`) → mission.json (`areas[]`) → area file
  (`maps[]`). Build the nested structure and hand it to
  `SessionState.set_campaigns(tree)`. Reuse `_read_json()` and the existing
  `push_warning` fail-soft pattern per level.
- **Shim:** if `CAMPAIGNS_DIR` is absent but `MISSIONS_DIR/index.json` exists, build a
  synthetic single campaign `{id:"atlantis", title:"Atlantis", missions:[...]}` from the
  old scan, and convert each old location (a single-scene file) into an **area with one
  map** `{id:"default", scene: convert_legacy_staging(staging)}`. Keep the old
  `_scan_missions()` body as `_scan_legacy_missions()` feeding the shim.
- `convert_legacy_staging(staging)`: map old keys → `scene` (`map`→`image`,
  `music`→`music`, `hex_grid`→`hex_grid`, `mood`→expand to `time_of_day/season/effects`,
  `gm_notes`→`gm_notes`).
- **Update the harnesses that read the old shape** (they will otherwise break):
  - `_stage_for_capture()` (`main.gd:145`): change `ATLANTIS_STAGE` from
    `"mission:location"` to a path like `"campaign:mission:area:map"` and call the new
    `SessionState.stage_map(...)`.
  - `_process_audiocheck()` (`main.gd:202`): iterate campaigns→missions→areas→maps and
    read `map.scene.music` instead of `loc.staging.music`.
  - `DEMO_ON_BOOT`/`_apply_demo_boot()`: still fine (it uses low-level setters), but
    add a demo `stage_map()` once a real area exists.

**`session_state.gd`:**
- Add `campaigns: Array` + `set_campaigns()` + signal `campaigns_changed`. Add getters
  `get_campaign(id)`, `get_mission(campaign_id, id)`, `get_area(...)`, `get_map(...)`.
  (Keep `missions`/`get_mission()` as thin back-compat wrappers over the active
  campaign so nothing else breaks mid-migration.)
- Track staged path: `current_campaign_id`, `current_staged_mission_id`,
  `current_staged_area_id`, `current_staged_map_id`.
- **Add `apply_scene(scene: Dictionary)`** — the new heart. Reads the DESIGN §3.4
  scene fields and composes existing setters: `image`→`set_current_map`;
  `region`→(new, optional — defer crop rendering to a sub-task, ignore for now);
  `hex_grid`→`set_hex_grid_visible`; `music{suite,tier}`→suite/tier setters;
  `time_of_day`/`season`→lighting setters; `effects`→`set_scene_effects`;
  `sectors`→(handled via map metadata as today). Unknown keys ignored (fail-soft).
- **Add `stage_map(campaign_id, mission_id, area_id, map_id)`** — looks up the map in
  the tree, calls `apply_scene(map.scene)`, sets the staged-path vars, emits a new
  `map_staged(...)` signal. This **replaces `apply_location_staging()`** (keep the old
  function as a one-line adapter during migration, then delete).

**`gm_window.gd`:** `_build_missions_section()` → a Campaign dropdown + Mission
dropdown + Area list + Map list (tiles later). Selecting a map calls `stage_map(...)`.
Keep the existing "one click stages everything" feel; the unit is now the Map. (Full
Prep/Live restructure is DESIGN §8 v0.11 — here we just re-point the existing widgets.)

---

## 3. Step 3 — Formalize the `scene` block + a content validator

- Lock the `scene` schema (DESIGN §3.4 table) as the contract `apply_scene()` reads.
- **`tools/validate_content.py`** (standalone, run at prep time — the sandbox has no
  Godot-side network but Python is fine offline): walk `assets/campaigns/`, resolve
  every `image`, `music.suite`, `sectors` path, every `time_of_day`/`season`/`effects`
  id against the catalogs, and print a report with "did you mean" hints. Exit non-zero
  on any broken ref so it can gate authoring.
- Optionally mirror a lightweight version at boot in `main.gd` that `push_warning`s a
  one-line manifest report (disable the broken piece, never the app).

---

## 4. Step 4 — Persistence split (keyed by campaign)

- `save_session()`/`load_session()` (`session_state.gd:588`): add the staged path
  (`current_campaign_id`/mission/area/map), `current_time_of_day`, `current_season`,
  and any live effects override to `session.json`. Restore validates the staged path
  against the loaded tree (drop stale, same pattern as the map-path check at `:624`).
- **Campaign-scoped campaign state:** today `facility_state` is one global
  `user://facility_state.json`. Generalize to `user://campaign.json` shaped as
  `{ "<campaign_id>": { facility... } }` so the Calibration testbed can't clobber
  Atlantis (DESIGN §4). Keep a one-time migration: if the old `facility_state.json`
  exists and `campaign.json` doesn't, load it in under `"atlantis"`.

---

## 5. Recommended build order & checkpoints

Each lands green (app boots, table-safe) before the next:

1. **Lighting model** (§1) — visible atmosphere change, tiny blast radius. Verify: old
   moods still render; sliders move tint live on both projector + preview.
2. **Content tree + shim** (§2) — verify: existing `arc01_knossos` content still loads
   via the shim and stages correctly; harnesses updated and green.
3. **`scene` block + validator** (§3) — verify: author one real new-format area
   (Camelot, 2 maps) and stage it; `validate_content.py` passes and catches a planted
   typo.
4. **Persistence split** (§4) — verify: stage a map, quit, relaunch → same map/lighting
   restored; facility survives; testbed campaign has separate save.

**Verification harness already exists** — reuse the headless screenshot path
(`ATLANTIS_SCREENSHOT`) and `TESTING.md` conventions to capture projector+GM frames
after each step on the display-less devserver. Update `ATLANTIS_STAGE` to the new
`campaign:mission:area:map` form (§2).

---

## 6. Later milestones (land on this foundation — detail later)

Per DESIGN §8, once the foundation is in:

- **v0.10 Events** — `EventBus`/sequence-runner in `SessionState`: `blackout/resume`
  (remember-and-restore), `combat_start/end` auto-driving music tier via the map's
  `on_combat`, `reveal/hide_handout`, `ping`, and the interruptible `on_enter` runner.
- **v0.11 Operator UI** — split `gm_window.gd` into Prep vs Live modes + pinned HUD +
  live lighting sliders + `adjacent` quick-jump; hotkeys; click-token-to-select.
- **v0.12 Combat depth** — initiative reorder + Delay; **fix token identity by id**
  (store id in list-item metadata; kill the label-matching in `gm_window.gd:722`); mob
  scatter + palette extension.
- **v0.13+** — map-relative tokens + fog of war; table calibration; cinematic
  transitions.

---

## 7. Open implementation questions

1. **Region crops** (`scene.region`) — deferred in §2 (ignored on load). Confirm we can
   punt rendering map crops to a later sub-task, or is a multi-map-from-one-image town
   in your first authored area? (Decides whether crop rendering is v0.9 or v0.10.)
2. **Multi-particle scenes** — v0.9 supports one active particle set. Any first-content
   scene that needs, e.g., snow *and* ash at once? If not, single-set is fine to start.
3. **Do you want me to start with Step 1 (lighting) now**, or land the whole foundation
   (§1–§4) in one go? Step 1 is the safest, most visible first commit.
