# First-Run Test Plan

After installing Godot 4.3+ and generating test content, run through this checklist to verify v0.1–v0.4 work.

## Setup

```
# From the VTT project root:
pip install Pillow                    # one-time for the map generator
python tools/generate_test_maps.py    # writes 6 maps into assets/maps/
python tools/generate_test_audio.py   # writes 4 audio files into assets/audio/
```

Then open `project.godot` in Godot 4.3+ (or run `godot --path .` from this directory) and press **F5**.

## v0.1 — Two-window scaffold

- [ ] Two OS windows appear: "Atlantis VTT — GM Control" and "Atlantis VTT — Projector"
- [ ] On a single-monitor system both float; on multi-monitor the projector auto-fullscreens on display 2
- [ ] The GM window shows the split layout: preview pane (left) + control column (right)
- [ ] Closing the projector via its window controls does **not** close it (intentional — GM closes via main window)
- [ ] Closing the GM window quits the app

## v0.2 — Maps + crossfade

- [ ] GM panel "Maps" section lists all 6 test maps (alphabetically)
- [ ] Clicking a map triggers a ~1.5 s crossfade on the projector
- [ ] Switching between maps with different aspect ratios all fit-to-viewport correctly:
  - `coast` is widescreen — should fit with letterbox top/bottom
  - `temple` is portrait — should fit with letterbox left/right
  - The square-ish ones fill more of the viewport
- [ ] "Show Hex Grid" toggle adds/removes the hex overlay on **both** projector and preview
- [ ] Preview hex grid visually aligns with projector hex grid (same cells, same positions, just scaled)
- [ ] "Refresh" button rescans the asset directories (drop a new map into `assets/maps/` then click Refresh — it should appear in the list)

## v0.3 — Tokens

- [ ] "Add Token" creates a new colored circle at the projector's center on **both** views
- [ ] Each new token cycles through the 8-color palette (red → blue → green → yellow → purple → orange → cyan → pink → repeat)
- [ ] Click+drag a token on the preview → moves it in real time on both preview and projector
- [ ] Release a drag with the hex grid **visible** → token snaps to the nearest hex center
- [ ] Release a drag with the hex grid **hidden** → token stays where dropped (no snap)
- [ ] "Remove Selected" deletes a token from the list and removes it from both views
- [ ] Multiple tokens can be on the map at once; each can be dragged independently
- [ ] Tokens stay put when switching maps (note: this is a known limitation — see README)

## v0.4 — Audio

- [ ] GM panel Music section's **Singles** list includes `music_01_drone_low.wav` and `music_02_drone_mid.wav` (plus the suite tracks if the recursive scan is working)
- [ ] Select `music_01` and click Play → low drone fades in over ~1.5 s
- [ ] Switch to `music_02` while it's playing → crossfade smoothly to the higher drone
- [ ] Click Stop → music fades out over ~1 s
- [ ] SFX section lists `sfx_01_beep.wav` and `sfx_02_chime.wav`
- [ ] Select `sfx_01`, click Trigger → short beep
- [ ] Trigger the beep several times rapidly → multiple beeps overlap (each plays to completion independently)
- [ ] Trigger SFX while music is playing → SFX layers on top of music, music continues uninterrupted
- [ ] Switch maps while music plays → audio is uninterrupted

## v0.5 — Music suites (mission tiers)

- [ ] GM panel Music section shows a **Mission suite** dropdown listing `Test mission` (from `assets/audio/music/missions/test_mission/`)
- [ ] Four tier buttons appear: Exploration, Civilization, Combat, Boss — all enabled (the test suite has all four)
- [ ] Select `Test mission`, click Exploration → A2 drone fades in
- [ ] Click Civilization → crossfades to the D3 drone
- [ ] Click Combat → crossfades to the A3 drone
- [ ] Click Boss → crossfades to the E4 drone (the most audibly distinct jump)
- [ ] The active tier button stays visually pressed; switching tiers updates the pressed state
- [ ] Click Stop → music fades out, tier button stays highlighted (pressing it again re-triggers)
- [ ] Drop a folder `assets/audio/music/missions/sparse_test/` containing only one file named `boss.wav` → click Refresh → `Sparse test` appears in the dropdown, only the Boss button is enabled (the other three are disabled)
- [ ] Faction signatures / location signatures in subfolders (e.g. `music/locations/atlantis.ogg`) appear in the **Singles** list and play via the Play button as before
- [ ] Click a Single while a suite tier is playing → Single takes over; clicking a tier button switches back to the suite track

## v0.6 — Token labels + sizes, scene moods

**Token inspector**
- [ ] Add a token, select it in the list → inspector populates with its current label and size (medium by default)
- [ ] Type a new label into the Label field, press Enter or click away → token text under the circle updates on both preview and projector, list entry updates too
- [ ] Change the Size dropdown to Small / Large / Huge → token circle on both views resizes (0.6× / 1.5× / 2.0× of the medium radius)
- [ ] Hit-test still works after resizing — dragging the now-Huge token grabs from anywhere inside its larger circle
- [ ] Remove the selected token → inspector clears, label field becomes empty + non-editable, size dropdown disables
- [ ] Add two tokens, select the second → inspector shows the second's data; switch selection to the first → inspector swaps to the first's values

**Atmosphere**
- [ ] GM panel has a new "Atmosphere" section at the bottom with a mood dropdown listing: None, Winter, Forest at Dusk, Cave, Underwater, Volcanic, Sandstorm, Rain
- [ ] Pick Winter → projector tints cold blue and snow particles fall from the top
- [ ] Pick Forest at Dusk → tint shifts amber, falling leaves replace the snow
- [ ] Pick Cave → warm-dim tint, no particles
- [ ] Pick Underwater → cyan-blue tint, no particles
- [ ] Pick Volcanic → reddish tint with embers rising from the bottom
- [ ] Pick Sandstorm → sodium-yellow tint with dust streaming left-to-right
- [ ] Pick Rain → grey-blue tint with rain falling fast
- [ ] Pick None → tint clears, particles stop
- [ ] Token labels and the hex grid remain readable under every mood (they sit above the tint+particle layers)
- [ ] Switching maps while a mood is active keeps the mood applied
- [ ] Set a mood, edit a token label, close the GM window, re-launch → mood + label restore from session.json

## v0.7 — Combat tactical layer (GURPS)

**Token combat inspector**
- [ ] Select a token → inspector shows the new "Combatant" checkbox (off by default), HP/FP spin pairs (10/10 default), Basic Speed spin (5.00 default), and 8 status checkboxes
- [ ] With Combatant **off** → no HP/FP bars or status icons render on preview or projector (token looks the same as in v0.6)
- [ ] Toggle Combatant **on** → HP and FP bars appear above the circle on both preview and projector (HP green, FP blue, full width = full)
- [ ] Set HP current to 3 (of 10) → HP bar turns yellow (the GURPS "reeling" band)
- [ ] Set HP current to 0 or negative → HP bar turns red
- [ ] Set Basic Speed to 6.25 → value persists in inspector
- [ ] Check the Stunned status → a yellow "S" disk appears under the token's label on both views
- [ ] Check several statuses → they line up in a row left-to-right under the label
- [ ] Uncheck a status → disk disappears
- [ ] Select a different token → inspector flips to that token's values
- [ ] Remove a token → inspector clears; combat inspector greys out

**Combat section + initiative**
- [ ] Flag 4 tokens as combatants with different Basic Speeds (5.00, 6.50, 5.75, 4.25)
- [ ] GM panel "Combat" section shows them in descending Basic Speed order (6.50 first)
- [ ] "Start Combat" button enables only when ≥1 combatant exists
- [ ] Click Start → round counter shows "Round 1", first combatant (highest BS) is marked active (▶ marker in the list and "Active: <name>" label)
- [ ] Click "Next Turn" → active marker advances down the list
- [ ] Reach the bottom and Next Turn again → wraps to the top, round counter increments to 2
- [ ] Edit a combatant's Basic Speed mid-fight → list re-sorts; the active combatant stays the same (tracked by id, not position)
- [ ] Remove the active combatant mid-fight → the list shrinks and active marker moves to a remaining combatant (no ghost)
- [ ] Click "End Combat" → round counter clears, no active marker

**Projector initiative rail**
- [ ] Rail is **invisible** when combat is inactive
- [ ] On Start Combat, rail appears on the right edge of the projector window: "Round 1" header, then one entry per combatant
- [ ] Each entry shows: color swatch, name, Basic Speed (right-aligned), HP bar with "HP n/m" label, FP bar with "FP n/m" label
- [ ] Active entry has a yellow border + yellow tint
- [ ] Edit HP via the inspector → rail HP bar updates in real time
- [ ] End Combat → rail disappears

**Persistence**
- [ ] Set up a combat (3 combatants, mid-round 2, one Stunned, one reeling), close the GM window
- [ ] Re-launch → combat is still active, on Round 2, same active combatant, statuses + HP intact

## v0.8 — Sector overlays + ambient effects + facility progression

**Sector overlay rendering**
- [ ] Load `atlantis.png` (with `atlantis.json` sidecar pointing at `atlantis_sectors.json`) → the 16 placeholder sector polygons appear on both projector and preview, each labeled with `[I-n] Name [T1]`
- [ ] Switching to any other map (e.g. `coast`) → sectors disappear (no overlay = no polygons drawn)
- [ ] Returning to `atlantis` → sectors reappear at their saved tiers
- [ ] Polygon coverage matches the projector exactly when scaled; labels readable on both views

**Sector selection + facility inspector**
- [ ] GM panel **Facility** section visible at the bottom of the right column
- [ ] On a non-Atlantis map the sector list is empty + the tier dropdown / upgrading toggle are disabled
- [ ] On Atlantis, the sector list shows all 16 sectors as `[I-n] Name — Tk`
- [ ] Click a sector on the **preview** → the matching row highlights in the list, the inspector label updates to `Selected: [I-n] Name`, the tier dropdown shows the current tier, the upgrading toggle reflects the current state
- [ ] Pick a different tier from the dropdown → sector polygon color shifts (grey → white → gold) on both views, list row text updates
- [ ] Toggle Upgrading on → a pulsing orange outline appears on the polygon on both views, list row gets a `⚙` suffix; toggle off → outline disappears
- [ ] Click a non-sector area on the preview while the map has an overlay → selection clears
- [ ] Click a sector row in the GM list → preview's yellow selection outline jumps to that polygon

**Token vs sector click priority**
- [ ] Drop a token on top of a sector polygon. Click the token → drag begins normally (no sector selection)
- [ ] Click an empty region of the same sector → token doesn't move, sector selection takes effect

**TP + RU**
- [ ] TP balance label starts at 0
- [ ] Set the spin to 5, click "+" → TP shows 5
- [ ] Click "−" → TP shows 0
- [ ] Type `cumaean_cooperation` into the RU input, press Enter → it appears in the RU list
- [ ] Type the same id again → no duplicate appears
- [ ] Select an RU and click "Remove Selected" → it disappears from the list

**Ambient effects**
- [ ] On the Atlantis map, underwater caustics animate continuously over the entire map area (subtle blue brightness ripples)
- [ ] Meteor glow appears near `position_px` (centre by default) with a slow pulse — additive on top of the map, beneath tokens
- [ ] Tokens and the hex grid remain readable above the caustics
- [ ] Switching to a map *without* `ambient` entries → caustics and glow disappear
- [ ] Edit `atlantis.json` to set `meteor_glow.color` to `[0.4, 0.6, 1.0, 1.0]`, click Refresh → glow recolors to cool blue without restart

**Persistence**
- [ ] Set 3 sectors to T2, mark one as upgrading, award 10 TP, add an RU
- [ ] Close the GM window, re-launch → facility state restored exactly (sector tiers, upgrading flag, TP, RU list)
- [ ] Delete `user://facility_state.json` between runs → facility resets to defaults (all T1, 0 TP, no RUs), session.json still restores normally

## Per-map hex scale + persistence

- [ ] Load `map_03_coast.png` (the widescreen one). Toggle the hex grid → hexes are visibly larger than on the other maps (radius 55 vs default 40), and the preview matches the projector
- [ ] Drop a token on the coast map → token circle is also larger (scaled with hex radius, 0.7×)
- [ ] Switch to `map_01_grassland.png` → hexes revert to default 40 px radius; existing token shrinks back to match
- [ ] Edit `assets/maps/map_03_coast.json` to set `"hex_radius_px": 80`, click Refresh, switch to coast → hexes grow further (no app restart needed)
- [ ] Set a suite + tier playing, place a few tokens, toggle hex grid on, close the GM window (X)
- [ ] Re-launch → music resumes on the same suite + tier, tokens are back where you left them, hex grid is on, the previously-loaded map is loaded
- [ ] Delete a map from `assets/maps/` between sessions → on next launch that map is silently skipped (rest of state still restores cleanly)

## Notes on likely failure modes

If something doesn't work, the most likely culprits (in rough order of probability):

1. **Tween/crossfade syntax** — if both sprites fade in lockstep or the new map snaps in without fade, the `set_parallel()` call in `projector.gd:_crossfade_to` needs adjustment.
2. **Preview hex grid misaligned** — math should match the projector but the `_publish_viewport_size()` deferred call might race. Try resizing the projector window to force a republish.
3. **Tokens not draggable** — check that `MapPreview.mouse_filter` is `MOUSE_FILTER_STOP` and the parent containers aren't blocking input.
4. **Audio doesn't loop** — Godot 4 dropped Theora-style auto-loop; the `_configure_loop()` call handles OGG/MP3/WAV but if you drop in some other format it may play once and stop. WAV with the test generator should loop fine.
5. **Projector window closes anyway** — if `close_requested.connect(func(): pass)` doesn't block the close, replace with `projector_window.hide()` or set the window to borderless.
6. **Suite dropdown empty** — `main.gd:_scan_music_suites` looks in `assets/audio/music/missions/`. If that folder is missing, the dropdown shows `(no suites — drop folders into music/missions/)`. The recursive Singles scan should still find files elsewhere.
7. **Tier button stays enabled with no track** — filename matching is substring-based against `exploration` / `civilization` / `combat` / `boss`. A file named `civilization_intro.wav` will match civilization, but a typo like `cilivization.wav` won't. Rename and Refresh.

Report which step failed (and any console errors from the Godot output panel) and we'll fix from there.
