# Atlantis VTT

A top-down projection app for running the Atlantis tabletop RPG campaign through an overhead projector. Built in Godot 4.

## Architecture

Two-window app, single Godot process:

- **GM Control window** (main OS window) — split view: live preview of the projector on the left, control panel on the right (maps / tokens / audio).
- **Projector window** (secondary OS window) — full-bleed top-down map display with crossfade transitions, hex grid overlay, and tokens.

If the system detects a second display at launch, the projector window opens fullscreen on it automatically. Otherwise it floats as a regular window for development on a single screen.

State flows through a `SessionState` autoload — neither window references the other directly. The GM panel mutates state; the projector subscribes to state changes.

The projector's close button is intentionally non-functional — the GM closes the app from the main window. This prevents accidentally killing the projector mid-session.

## Running

1. Install Godot 4.3+ from <https://godotengine.org/download/linux>.
2. Open this folder in Godot (or run `godot --path .` from this directory).
3. Press F5 (or click Play) to launch.
4. Drop assets into the appropriate folders and use the GM panel to control them.

## Project Layout

```
project.godot              Godot project configuration (autoloads SessionState)
.gitignore                 Godot-aware ignore rules
scenes/
    main.tscn              Root scene — boots both windows
    gm_window.tscn         GM control panel host
    projector.tscn         Projector display host
    audio_controller.tscn  Process-global audio node
scripts/
    session_state.gd       Shared autoload — single source of truth
    main.gd                Bootstrap, window spawning, asset directory scanning
    gm_window.gd           GM control panel UI (maps / tokens / audio)
    map_preview.gd         Interactive scaled-down projector mirror
    projector.gd           Map rendering + crossfade + hex overlay + token visuals
    audio_controller.gd    Background music (with crossfade) + one-shot SFX
assets/
    maps/                  Drop map images here (PNG/JPG/WEBP)
    audio/
        music/             Background music — recursive (OGG/MP3/WAV)
            factions/      Faction signatures (Singles)
            locations/     Location signatures (Singles — Atlantis, EPOCH base, ...)
            characters/    Character themes (Singles)
            missions/      Each subfolder = a 4-tier suite
                howland_1937/
                    01_exploration.wav
                    02_civilization.wav
                    03_combat.wav
                    04_boss.wav
        sfx/               One-shot ambient SFX (OGG/MP3/WAV)
```

## Features (current — through v0.5)

**Maps**
- Auto-discovers map images in `assets/maps/`.
- Click a map in the GM list to load it on the projector with a 1.5 s crossfade.
- Refresh button rescans the asset directories at runtime.

**Hex grid**
- Toggleable pointy-top overlay; renders on both projector and GM preview.
- Per-map hex scale via JSON sidecar: drop a `map_name.json` next to a `map_name.png` containing `{"hex_radius_px": 55}` and that map gets larger/smaller hexes. Default radius is 40 px when no sidecar is present.

**Persistence**
- On graceful quit, the active map, hex toggle, music suite + tier, and all tokens are written to `user://session.json`. On next launch, state is restored after the asset libraries are scanned (stale entries — deleted maps, missing music suites — are silently dropped).

**Tokens**
- Add Token: appears at projector center with the next color in the palette.
- Drag tokens directly on the GM preview to move them — the projector mirrors in real time.
- Release a drag with the hex grid visible to snap to the nearest hex center.
- Remove Selected: drops the highlighted token.
- Select a token in the list to open the inspector: edit its **label** (rendered under the circle on both preview and projector) and pick a **size** (small / medium / large / huge — scales relative to hex radius).

**Atmosphere (v0.6)**
- Scene mood dropdown applies a multiplicative color **tint** (cool blue for winter, amber for forest dusk, sodium for sandstorm, etc.) plus a matching **particle overlay** (snow, rain, leaves, embers, dust). Tint sits above the map; tokens and the hex grid sit above particles so they stay legible.
- Moods are bundled — picking "Winter" gives you cold-blue tint *and* snow at once. "None" disables both layers.

**Sector overlays + facility progression (v0.8)**
- Maps may attach a **sector overlay** via the sidecar's `overlays.sectors` field — a path to a JSON file defining polygons (in map-pixel space), sector names, and per-tier labels.
- Sectors render as tinted polygons on top of the map (on both projector and GM preview) with a name + `[Tn]` tier badge at the configured label anchor. Tier colors: T1 grey, T2 white, T3 gold. A pulsing orange outline marks sectors currently upgrading; a yellow outline marks the GM's selection.
- The GM panel **Facility** section exposes TP balance (with +/− award/spend), the sector list (kept in sync with the active map's overlay), a tier dropdown + "upgrading" toggle for the selected sector, and a Research Upgrade inventory (free-text add by id, remove selected).
- **Click a sector on the preview** to select it in the inspector — token hit-test wins when overlapping, then sectors take the click.
- Facility state (TP, RUs, per-sector tier + upgrading flag) persists to `user://facility_state.json`, independent of the per-session save so campaign progression survives editing map assets.

**Ambient effects (v0.8)**
- Per-map opt-in via the sidecar's `overlays.ambient: ["effect_name", ...]`. Effects:
    - `underwater_caustics` — animated blue/white caustics shader, multiplied over the map. Tunables in the sidecar: `intensity`, `speed`, `tint`.
    - `meteor_glow` — pulsing additive radial glow positioned over the meteor. Tunables: `position_px` (map-pixel space), `radius_px`, `color`.
- Effects layer between the map and the hex grid / tokens so combatants stay readable. Tokens still drop on the map normally — the same map can host an EPOCH-attack combat with the sectors and caustics still active underneath.

**Combat tactical layer (v0.7) — GURPS-flavored**
- Flag any token as a **combatant** in the inspector. Combatants get HP and FP fields (current and max), a Basic Speed value, and a row of 8 GURPS status checkboxes (Stunned / Unconscious / Prone / Bleeding / Grappled / Aiming / All-Out Attack / All-Out Defense).
- HP and FP render as bars above each combatant token on both the projector and the preview. HP colors band by ratio — green / yellow at ≤⅓ ("reeling") / red at ≤0 — and FP rides underneath in blue.
- Active statuses appear as small lettered colored disks under the token's label, identical between preview and projector.
- The GM panel has a **Combat** section with Start / Next Turn / End Combat buttons and a round counter. Initiative order is computed from Basic Speed (descending). DX tiebreak is the GM's call manually.
- The projector renders an **initiative rail** down the right edge during combat: round counter, color swatch + name + Basic Speed + HP/FP bars per combatant, active entry highlighted. Hidden when combat is inactive or no combatants exist.
- Combat state (active/round/who's-up) persists with the rest of the session — a crashed projector resumes mid-fight where you left off.

**Audio — Singles**
- Recursive discovery of all audio files under `assets/audio/music/` (faction signatures, location signatures, character themes, anything ad-hoc).
- Background music plays looped with a 1.5 s crossfade on track change.
- SFX trigger fire-and-forget (multiple can overlap).
- Stop button fades music out over 1 s.

**Audio — Mission Suites (v0.5)**
- Each subfolder of `assets/audio/music/missions/` is treated as a 4-tier music suite. Files are auto-mapped to tiers by filename substring (`exploration` / `civilization` / `combat` / `boss`).
- GM panel exposes a **suite dropdown** + four **tier buttons** (Exploration / Civilization / Combat / Boss). Pressing a tier crossfades to that track.
- Tier buttons disable themselves when the current suite has no track for that tier.
- Suite + tier are the two gameplay variables; either may be empty (in which case the Singles list is the only control).

## Milestones

The roadmap is shaped by the project's hard constraint: **single GM, in-person play, projector pointed at the physical table, no remote players.** Anything that exists in other VTTs to substitute for being-in-the-same-room (dice rollers, chat, voice, character sheets, per-player vision, automation engines) is explicitly out of scope.

### Done

- **v0.1** — Two-window scaffold, single map load, hex toggle ✓
- **v0.2** — Multi-map library, crossfade transitions ✓
- **v0.3** — Tokens with drag-to-move on GM preview, snap-to-hex ✓
- **v0.4** — Audio (looping music + SFX) ✓
- **v0.5** — Music suites with tier switching (mission-based gameplay variables) ✓
- **v0.5b** — Per-map hex scale via JSON sidecars + quit/restore session persistence ✓
- **v0.6** — Token labels + size enum, scene moods (tint + particles: snow / rain / leaves / embers / dust) ✓
- **v0.7** — Combat tactical layer (GURPS-flavored): per-token HP + FP bars, status icons (8 GURPS conditions), initiative tracker driven by Basic Speed, projected side rail with active-combatant highlight ✓
- **v0.8** — Map sector overlays (polygons + per-tier badges) + per-map ambient effects (underwater caustics shader, pulsing meteor glow). Facility progression (TP/RU/per-sector tier) persisted independently of session state ✓

### Planned

Ordered by gameplay impact. The first three address features present in every major VTT (Foundry, Roll20, Owlbear, Fantasy Grounds, TaleSpire) that we currently lack; the later milestones are in-person-specific wins that online VTTs don't bother with.

- **v0.9** — *Annotation tools.* Click-drag ruler with hex distance, AoE templates (circle / cone / line) the GM can drop and label, and a "ping" pulse on click that draws all eyes to a map location — the projector equivalent of pointing. All three share one annotation input system.
- **v0.10** — *Projector flow control.* Blackout / intermission hotkey (fade the projector to black or a title card for breaks and dramatic reveals), full-screen image handouts (NPC portraits, letters, symbols) that fade in and fade back to the map, and named scene presets (save current map + tokens + music tier + mood as a one-click bundle for prepped encounters).
- **v0.11** — *Map-relative content.* Refactor tokens and annotations to be anchored to the active map instead of world space, so switching maps loads each map's own token + annotation set. Prerequisite for fog of war.
- **v0.12** — *Fog of war.* Paint-to-reveal brush + polygon reveal regions, persisted per map. Replaces the "place paper cutouts to hide rooms" hack that in-person GMs currently improvise on the table itself.
- **v0.13** — *GM-only secret layer.* Notes pinned to map locations, secret door markers, monster stat snippets — visible only on the GM control panel, never on the projector. Foundry has a GM layer but it's still designed assuming each player has their own screen; for a single projector this is a real differentiation lever.
- **v0.14** — *Physical-table calibration.* One-time alignment mode for fitting the projected hex grid to a physical grid mat or terrain set (nudge / scale / rotate). No online VTT needs this; for an overhead-projector setup it's foundational.
- **v0.15** — *Cinematic transitions.* Shader-driven transitions between maps and into handouts (wipes, dissolves, iris). Polish layer once the gameplay-critical features are in.

### Explicitly out of scope

Considered and rejected because the in-person table already provides them: character sheets, dice rollers, chat / whisper, voice / video integration, per-player vision and darkvision, player permissions, macro / automation engines for rules adjudication, compendiums and SRD bundles, marketplace / module ecosystem, 3D rendering, cloud sync.

## Implementation Notes

**Multi-window.** Godot 4 supports real OS sub-windows when `display/window/subwindows/embed_subwindows=false` is set. The `Window` node spawned by `main.gd` becomes a real top-level window. Auto-promoted to fullscreen on display 2 if present.

**State model.** `SessionState` is the single source of truth. GM mutates → SessionState emits → projector + preview both react. No direct GM↔projector references; adding new state types only requires adding signals + setters.

**Coordinate system.** Token positions are stored in projector world-space pixels (origin at viewport center). The GM-side `MapPreview` reads the published projector viewport size from `SessionState` to convert mouse drags in preview-space to world-space.

**Hex grid.** Pointy-top hexagons. Spacing: horizontal = √3 × radius, vertical = 1.5 × radius, odd rows offset by half horizontal. v0.3 uses a fixed 40 px world radius; later should tie this to per-map metadata.

**Audio looping.** Each `AudioStream` subclass exposes looping differently. `AudioStreamOggVorbis` and `AudioStreamMP3` have a `loop` boolean; `AudioStreamWAV` has `loop_mode`. The audio controller sets each appropriately before playback.

## Known Limitations / Future Work

- Token positions are world-space, not map-relative — switching maps with different aspect ratios will leave tokens in their world positions, which may not line up with the new map. A later version should introduce per-scene token sets.
- Persistence is quit-only; a hard crash loses state since the last clean exit. A future version could autosave every N seconds or on mutation.
- The token name → row mapping in `gm_window.gd` relies on name uniqueness, which is true for v0.3 but fragile. Should be replaced with id-in-metadata.
- Suite/tier resolution is by filename substring only. If two files in the same suite folder both match the same tier word, the last one wins (alphabetical order is preserved by `DirAccess.get_next` on most systems but not guaranteed). Keep one file per tier.
