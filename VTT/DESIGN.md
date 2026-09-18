# Atlantis VTT — Design Doc (North Star)

> **What this is.** The target design for the app. `README.md` describes what's
> built *today*; this describes what we're building *toward*, so an implementation
> agent can pick any section and build it without re-deriving the whole model.
> When the two disagree, this doc wins — but check `README.md` / the code for
> what already exists before writing new code (a lot of the content model is
> already parsed; we're mostly formalizing and extending it).

---

## 1. The one constraint (read this first)

**Single GM. In-person play. A projector pointed at the physical table. No remote
players.** Every design decision serves a human running a live game in a dim room,
one screen in front of them, five people watching the projected map, acting under
time pressure with everyone waiting.

Consequences that shape the whole app:

- **Speed of access beats feature count.** If the GM has to hunt for a control
  mid-scene, it failed — no matter how powerful it is.
- **The projector is the players' reality.** Anything the GM does to *prepare* the
  next beat must be possible **without the players seeing it** (stage behind a
  blackout, then reveal).
- **Authoring is prep-time; operating is play-time.** The heavy configuration
  (maps, lighting, effects, soundtracks per location) happens *before* the
  session, in JSON. During play the GM navigates and triggers — they don't
  configure.
- **Never crash mid-session.** Bad/missing JSON, a deleted asset, a typo'd
  effect name → fail soft (skip it, log it, keep running). A crash at the table
  is the worst possible outcome.
- **Out of scope forever** (the table already provides these): character sheets,
  dice rollers, chat, voice, per-player vision, rules-automation engines,
  compendiums, marketplace, 3D, cloud sync.

---

## 2. Core mental model

The GM doesn't think "load map X, set tint Y, play track Z." They think:

> *"We're running **Retrieve Excalibur**. The party's leaving **Camelot** for
> **The Lake**. Combat's about to kick off."*

So the app is organized around that hierarchy — a plain **tree** — and two verbs,
**stage** and **trigger**:

```
Campaign            "Atlantis"   (also: a "Calibration" testbed campaign, §9)
  └─ Mission        "Knights of the Round Table — Retrieve Excalibur"
       └─ Area      "Camelot" · "The Lake" · "Arthur's Battleground"
            └─ Map   "Camelot — Market" · "— Throne Hall" · "— Tavern" · ...
                 = a fully-authored SCENE (image + time/season + effects + music + notes)
                 maps within an area are ADJACENT — players move between them
```

- **An Area is a place; a Map is a board within it.** A town is the canonical
  multi-map area (market, throne hall, tavern — all adjacent, players move between
  them). A simple area is just one map. The **Map is the stageable unit** (the scene).
- **Stage a Map** → one click swaps the projector to that scene: image, hex grid,
  time-of-day + season lighting, VFX, and the right soundtrack, all at once.
- **Trigger an Event** → combat start/end, reveal a handout, ping, blackout. Events
  layer *on top* of the staged map and often mutate it (combat → jump the music to
  its combat tier, show the initiative rail).

Everything else (tokens, facility, atmosphere overrides) is refinement on top of a
staged map. **Adjacency:** maps in an area can declare neighbors so the Live HUD
offers one-tap "move to the next room" buttons.

---

## 3. Content model (authored JSON)

All authored content lives under `assets/`. It is **read-only at runtime** — the app
never writes it back. Runtime/session state is separate (§4).

### 3.1 Directory layout

```
assets/
  campaigns/
    index.json                     # registry: which campaigns exist (Atlantis, Calibration)
    atlantis/
      campaign.json                # campaign metadata + ordered missions
      excalibur/
        mission.json               # mission manifest: metadata + ordered AREAS
        camelot.json               # an AREA file: one or more ADJACENT maps
        the_lake.json
        battleground.json
    calibration/                   # testbed campaign (grid alignment, feature demos)
      campaign.json
      ...
  maps/
    knossos.png
    knossos.json                   # per-map sidecar (hex size, overlays, effect tunables)
    atlantis.png
    atlantis.json
    atlantis_sectors.json          # sector geometry for the home base
  audio/
    music/
      suites/<suite>/              # 4-tier themed suites (see §3.6)
      factions/ locations/ characters/   # "singles" (one-offs)
    sfx/
  handouts/                        # NEW: full-screen reveals — sheets, portraits, letters (§5)
  lighting.json                    # NEW: time-of-day + season lighting model (§3.5)
```

> **Migration note.** Today's tree is `assets/missions/index.json` + one folder per
> mission with per-location files. The new layout inserts a **campaign** level above
> missions and renames per-location files to per-**area** files. Keep a shim so the
> old `missions/` folder still loads as the default "Atlantis" campaign until content
> is moved.

### 3.2 `campaigns/index.json` — campaign registry (NEW) + `campaign.json`

```json
{
  "campaigns": [
    { "id": "atlantis",    "title": "Atlantis",              "path": "atlantis/campaign.json" },
    { "id": "calibration", "title": "Calibration / Testbed", "path": "calibration/campaign.json" }
  ]
}
```

```json
// atlantis/campaign.json
{
  "id": "atlantis",
  "title": "Atlantis",
  "blurb": "GURPS time-travel campaign.",
  "home_area": "excalibur/atlantis_base",   // optional: base to jump to (facility, §3.7)
  "missions": [
    { "id": "excalibur", "title": "Retrieve Excalibur", "path": "excalibur/mission.json" }
  ]
}
```

### 3.3 `mission.json` — mission manifest (exists today; now lists AREAS)

```json
{
  "id": "excalibur",
  "title": "Knights of the Round Table — Retrieve Excalibur",
  "blurb": "The party must recover Excalibur before the usurper does.",
  "theme": "arthurian_britain",         // NEW: default music/lighting flavor for the whole mission
  "default_music_suite": "arthur",
  "areas": [
    { "id": "camelot",      "title": "Camelot",               "file": "camelot.json" },
    { "id": "the_lake",     "title": "The Lake",              "file": "the_lake.json" },
    { "id": "battleground", "title": "Arthur's Battleground",  "file": "battleground.json" }
  ]
}
```

`theme` is a convenience default: a mission set in the Aztec Empire declares its
soundtrack/lighting flavor once; maps inherit unless they override. This is how you
get "heist music for the train job, Aztec drums for the temple" without repeating
yourself per map.

### 3.4 Area file — one or more adjacent Maps (each Map = a scene)

An **Area** is a place; it holds one or more **Maps** (adjacent boards — a town is
the canonical multi-map area). Each Map carries a full `scene` block. **Back-compat:**
today's per-location files have a single scene at the top level — read those as an
area with one map named "default".

```json
{
  "id": "camelot",
  "title": "Camelot",
  "gm_notes": "Seat of Arthur. The usurper's agents already walk the market.",
  "maps": [
    {
      "id": "market",
      "title": "Market Square",
      "adjacent": ["throne_hall", "tavern"],       // one-tap moves in the Live HUD
      "scene": {
        "image": "res://assets/maps/camelot_market.png",
        "region": null,                            // optional [x,y,w,h] crop to reuse a big image
        "hex_grid": true,
        "time_of_day": "noon",                     // dawn | noon | dusk | midnight (§3.5)
        "season": "summer",                        // spring | summer | autumn | winter (§3.5)
        "effects": ["dust_motes"],                 // additive VFX layers, order = draw order
        "music": { "suite": "arthur", "tier": "civilization" },
        "ambient_sfx": ["market_crowd"],
        "sectors": null,                           // path to a sector overlay, or null
        "on_enter": [ { "sfx": "fanfare" } ],      // authored auto-sequence (§5)
        "on_combat": { "music_tier": "combat" }    // event override for THIS map (§5)
      }
    },
    {
      "id": "throne_hall",
      "title": "Throne Hall",
      "adjacent": ["market"],
      "scene": {
        "image": "res://assets/maps/camelot_throne.png",
        "hex_grid": true,
        "time_of_day": "dusk",
        "season": "summer",
        "effects": [],
        "music": { "suite": "arthur", "tier": "exploration" },
        "on_combat": { "music_tier": "boss" }
      }
    }
  ]
}
```

**The `scene` block is the heart of the content model.** Every field is optional and
falls back to a sane default; anything unknown is ignored (fail-soft). Its fields:

| field | meaning | default |
|---|---|---|
| `image` | `res://` path to the base map image | required |
| `region` | `[x,y,w,h]` crop so several maps can reuse one big image | full image |
| `hex_grid` | show the hex overlay | inherit / false |
| `time_of_day` | `dawn`\|`noon`\|`dusk`\|`midnight` — a stop on the day slider (§3.5) | `noon` |
| `season` | `spring`\|`summer`\|`autumn`\|`winter` — a stop on the season slider (§3.5) | theme default |
| `light_energy` | scalar on the final tint. `>1` lifts a **pre-lit plate** back out of a night grade — a relit "after hours" map already carries its own darkness, and multiplying midnight on top crushes it to black | `1.0` |
| `light_grade` | `[r,g,b]` (or a colour string) multiplied over the tint — the authored half of the v0.15 cinematic grade | white |
| `effects` | list of VFX layer ids (particles + shaders) | `[]` |
| `music` | `{ suite, tier }` — themed 4-tier suite + starting tier | mission default |
| `ambient_sfx` | looping/one-shot environmental sound | `[]` |
| `sectors` | path to a sector overlay (facility maps) | none |
| `adjacent` | ids of neighboring maps in this area (quick-jump in Live HUD) | `[]` |
| `on_enter` | authored sequence fired when this map is staged (§5) | `[]` |
| `on_combat` | overrides applied when combat starts here (§5) | suite's `combat` tier |
| `gm_notes` | GM-only text, never projected | "" |
| `tokens` | pre-placed tokens (NPCs/hazards) authored for this scene | `[]` |

### 3.5 Lighting: time-of-day × season (two sliders, named stops) + effects

Today `mood` welds a color tint **and** particles together (e.g. "Winter" = cold blue
+ snow). You want time-of-day and season as **independent, adjustable** knobs — a
slider each, with named stops for reference. So the model is:

- **`time_of_day`** — a continuous 0→1 slider with **4 named anchor stops**:
  `dawn`, `noon`, `dusk`, `midnight`. Authored maps name a stop; the GM can drag the
  slider live and the tint/brightness **interpolates** between adjacent anchors
  (dawn↔noon↔dusk↔midnight, wrapping). Each anchor is a tint + brightness.
- **`season`** — same shape: a slider with **4 anchor stops** `spring`, `summer`,
  `autumn`, `winter`, each a tint bias (cool/warm) + a **default effect suggestion**
  (winter→snow, autumn→leaves) the GM can accept or clear.
- The **final scene tint = time_of_day anchor(s) × season bias**, both interpolated —
  so "Camelot at midnight in winter" and "Camelot at noon in summer" are two slider
  positions on the same map, no re-authoring.
- **`effects`** stays a separate list of additive VFX layers from a fixed catalog:
  particles (`snow`, `rain`, `leaves`, `embers`, `dust_motes`, `ash`) and shaders
  (`underwater_caustics`, `meteor_glow`, `heat_haze`, `fog`). Season *suggests*
  defaults; the scene's `effects` list is authoritative. Each effect may carry
  tunables (intensity/speed/color) inline or via the map sidecar.

The existing `SCENE_MOODS` collapse into this: a mood becomes a (time_of_day, season,
effects) preset the UI can still offer as a one-click shortcut, but the authored data
underneath is the decomposed form. Layer order (bottom→top) is fixed so combatants
stay legible: **image → region crop → lighting tint → effects → sector overlay → hex
grid → tokens → combat HUD**.

`lighting.json` — the anchor definitions for both sliders:
```json
{
  "time_of_day": {
    "dawn":     { "tint": [1.00, 0.82, 0.70, 1.0], "brightness": 0.80 },
    "noon":     { "tint": [1.00, 1.00, 1.00, 1.0], "brightness": 1.00 },
    "dusk":     { "tint": [1.00, 0.78, 0.60, 1.0], "brightness": 0.82 },
    "midnight": { "tint": [0.52, 0.60, 0.85, 1.0], "brightness": 0.50 }
  },
  "season": {
    "spring": { "tint_bias": [0.98, 1.02, 0.98, 1.0], "suggests": [] },
    "summer": { "tint_bias": [1.03, 1.00, 0.95, 1.0], "suggests": [] },
    "autumn": { "tint_bias": [1.05, 0.95, 0.85, 1.0], "suggests": ["leaves"] },
    "winter": { "tint_bias": [0.92, 0.96, 1.06, 1.0], "suggests": ["snow"] }
  }
}
```

### 3.6 Music: themed suites + event-driven tiers

A **suite** is a themed set of up to four tracks (in `assets/audio/music/suites/<id>/`)
mapped to gameplay intensity tiers: `exploration → civilization → combat → boss`. One
suite per *flavor*: `arthur` (Arthurian Britain), `train_heist`, `aztec_temple`,
`atlantis_home`. A Map picks a suite + a starting tier; **events move the tier
automatically** (combat → `combat`/`boss`, combat end → back to the pre-combat tier).
This is the mechanism behind "heist music during the heist, Aztec drums in the temple,
and it swells into combat music the moment a fight starts" — the GM never manually picks
a battle track.

"Singles" (faction/location/character themes) remain a flat manually-triggered list
for one-offs and stingers.

### 3.7 The home base ("Atlantis") as a special area

Atlantis is just an area whose map scene attaches a **sector overlay** + **facility
progression**. Its map sidecar (`atlantis.json`) already carries
`overlays.sectors` + `overlays.ambient` + per-effect tunables — that stays. The
facility model (TP balance, per-sector tier T1/T2/T3, "upgrading" flag, owned
Research Upgrades) is **mutable campaign state**, so it lives in the runtime layer
(§4), not the authored JSON. Authored = sector *geometry + names*; runtime = each
sector's current tier and upgrade status.

### 3.8 Validation & authoring safety

- A boot-time validator checks every referenced asset path, suite id, lighting id,
  and effect id exists; it prints a **manifest report** ("Arc 01 / Labyrinth:
  effect 'caustics' unknown — did you mean 'underwater_caustics'?") and disables
  only the broken piece, never the app.
- Provide `tools/validate_content.py` so authoring errors surface at prep time, not
  at the table.
- Every JSON supports a `_comment` / `notes` field, ignored by the parser (already
  the convention in the repo).

---

## 4. Runtime state model

Two clean layers — **do not blur them**:

1. **Authored content** (§3): read-only, loaded from `assets/` at boot. Campaigns,
   missions, areas, maps, scenes, lighting anchors, suites, sector geometry.
2. **Session/runtime state**: everything mutable, owned by the `SessionState`
   autoload (single source of truth today — keep that). Split its persistence into
   two files by lifetime:
   - `user://session.json` — *this session*: staged campaign/mission/area/map,
     tokens (positions, HP/FP, statuses), combat active/round/active-combatant, hex
     toggle, current music suite/tier, current time-of-day/season/effects overrides.
   - `user://campaign.json` — *across sessions*: facility TP/RU, per-sector tier +
     upgrading flags, and anything else that should survive between game nights.
     Keyed by campaign id so the Calibration testbed doesn't clobber Atlantis.
     (Facility already persists independently today — generalize it.)

Rule: **the GM can always override a staged scene live** (drag the time-of-day slider,
kill the snow, swap the track) and those overrides live in session state, layered over
the authored scene. Re-staging the map resets to authored defaults.

Architecture stays: GM panel mutates `SessionState` → it emits signals → projector
and preview both react. No direct GM↔projector references. Adding a new state type =
add a signal + setter. This is already how the code works and it's the right shape;
keep it.

---

## 5. Event system

Events are the "trigger" verb. An event is a named action that applies a bundle of
state changes and (optionally) plays a transition. **Both manual and authored
sequences are first-class** (per your call):

- **GM-fired** (a button / hotkey): `stage_map`, `combat_start`, `combat_end`,
  `reveal_handout`, `hide_handout`, `blackout`, `resume`, `ping`, `next_turn`.
- **Auto-fired** (the app reacts to a state change): staging a map auto-applies its
  `scene`; `combat_start` auto-jumps the music tier per the map's `on_combat`
  (falling back to the suite's `combat` tier) and shows the initiative rail;
  `combat_end` restores the pre-combat tier and hides the rail.
- **Authored sequences** — a scene's `on_enter` (and later `on_combat_start`, etc.) is
  an **ordered list of event steps** the app plays automatically. Each step is one of
  the primitive actions with a small payload, optional `delay_ms`, and optional
  `wait_for` (e.g. hold until the GM taps continue). Example:

```json
"on_enter": [
  { "blackout": true },
  { "reveal_handout": "handouts/excalibur_letter.png", "delay_ms": 500 },
  { "wait_for": "gm_continue" },
  { "hide_handout": true },
  { "music": { "suite": "arthur", "tier": "exploration" } },
  { "resume": true }
]
```

  Sequences are **always interruptible** — the GM can skip/abort at any point (a fight
  never gets locked behind an animation). Manual triggers and sequences share the same
  primitive event vocabulary, so a sequence is just a scripted list of manual events.

Design points:

- **Events are idempotent and reversible where it matters.** `blackout` remembers what
  was showing so `resume` restores it. `combat_end` restores the pre-combat music tier
  (stash it on combat start).
- **Staging behind a blackout** is a first-class flow: `blackout → stage_map (players
  see black) → resume` reveals the new scene cleanly. This is how you prep the next
  beat without spoiling it.
- Maps declare per-map event overrides + sequences (`on_enter`, `on_combat`). Keep the
  override schema small and additive.

**Handouts** are **full-screen reveals only** (per your call — players have paper
character sheets). `reveal_handout` fades a full-screen image (a projected copy of a
sheet, a portrait, a letter, a symbol from `assets/handouts/`) over the map and fades
back on `hide_handout` — used at discussion beats, not during live exploration. No
corner-pinned overlays; the map is either showing or the handout is.

---

## 6. UI design

### 6.1 Two modes, not one scroll

The single biggest usability problem today is that everything is one long scroll
column; mid-combat you scroll-hunt between the token inspector (buried in Tokens),
the Combat buttons (below), and initiative (below that). Fix: **mode-based layout**.

- **PREP mode** (before/between scenes): the Campaign → Mission → Area → Map navigator
  with thumbnails; click a map to preview it *in the GM window only*, then **Stage**
  (optionally behind a blackout). Facility management lives here too.
- **LIVE mode** (running a scene): a compact, fixed **operator HUD** — no scrolling
  for the things you spam. Left: the projector preview (drag tokens). Right, pinned:
  1. **Now Staged** strip — mission ▸ area ▸ map, current time-of-day/season/music
     tier, with quick-jump buttons to the map's **`adjacent`** neighbors (move to the
     next room in one tap).
  2. **Event bar** — big buttons/hotkeys: Combat ⏱, Blackout ⬛, Reveal 🖼, Ping ◎.
  3. **Combat HUD** (only when combat is active) — Next Turn, round, initiative rail
     mirror, and the selected combatant's HP/FP/status inline.
  4. **Selected token** inspector (opens on selection, collapses otherwise).
  5. **Live lighting sliders** — time-of-day + season, for on-the-fly adjustment.

Collapsible/pinnable sections everywhere else. The principle: **the three controls
you touch every 30 seconds are never more than one glance away and never require a
scroll.**

### 6.2 Navigation

- Campaign dropdown → Mission dropdown → Area list → Map tiles (thumbnails + a
  one-line gm_note). Selecting a map shows a **preview panel** (what the projector
  *will* look like) before you commit.
- **Stage** commits it live; **Stage behind blackout** commits it hidden.
- Within an area, a map's `adjacent` neighbors surface as quick-jump buttons so
  moving around a town is one tap, not a drill-down.
- Keep the "one click stages the whole scene" property — it's the best thing in the
  current design. The stageable unit is now the **Map**.

### 6.3 Interaction principles (fixes from the stress-test)

- **Hotkeys for spam actions:** Space = Next Turn, B = Blackout/Resume toggle,
  P = Ping (then click), C = Combat start/end. Mouse-hunting a fight is the enemy.
- **Click a token on the preview selects it** in the inspector (today it only drags;
  sectors already select on click — make tokens consistent).
- **Confirm/undo destructive actions:** confirm on End Combat and Remove Token;
  ideally a small undo stack for token add/remove/move.
- **Token identity by id, not label.** Store the id in the list item's metadata; the
  current "match rows to tokens by label text" breaks the instant you have two
  "Goblin"s — i.e. every combat with a mob. This is a correctness bug, not polish.
- **Mob ergonomics:** "Add N tokens" scatters them (not all stacked at center), and
  the color palette extends/varies so a 10-token mob isn't indistinguishable.
- **Manual initiative control:** drag-to-reorder for DX tiebreaks, plus a
  Delay/Wait action (a real GURPS maneuver) — today order is pure Basic-Speed with
  no manual override.
- **Low-light legibility:** the GM works in a dim room. Bump hint text above 11px
  grey-on-grey; color-code section headers so the eye jumps to "Combat" instantly.

### 6.4 The projector (players' view) — unchanged principles

Full-bleed map, crossfade transitions, hex overlay, tokens, combat rail, effects.
Close button stays inert (GM closes from the main window). Everything GM-only
(gm_notes, sector inspector, prep preview, handout picker) **never** renders here.

---

## 7. Migration from what exists today

What's already real (don't rebuild — extend):

- `SessionState` autoload as single source of truth + signal fan-out. ✅ Keep.
- Mission → Location scan (`index.json` / `mission.json` / location files) and
  `apply_location_staging(map, music{suite,tier}, mood, hex_grid)`. ✅ Extend to the
  Campaign→Mission→Area→Map tree and the fuller `scene` schema.
- Map sidecars with `hex_radius_px`, `overlays.sectors`, `overlays.ambient`, and
  per-effect tunables. ✅ Keep; a scene's `effects` reference the same effect ids.
- Scene moods (tint + particles), combat layer (HP/FP/statuses/initiative), sector
  overlays + facility progression, music suites + tiers, singles/SFX. ✅ All keep.

Incremental path (each step ships independently, never breaks the table):

1. **Lighting model** — add `lighting.json` (time-of-day + season anchors), keep the
   old moods as preset bundles that expand to it. Parser reads either form.
2. **Tree** — insert the Campaign level (`campaigns/index.json`) and rename per-location
   files to per-**area** files listing **maps** (old single-scene files ⇒ one default
   map; old `missions/` folder ⇒ default Atlantis campaign via a shim).
3. **Formalize the `scene` block** + boot-time content validator + manifest report.
4. **Event system**: extract `combat_start/end` to auto-drive music tier; add
   `blackout/resume`, `reveal/hide_handout`, `ping`, and the `on_enter` sequence runner.
5. **Split persistence** into `session.json` (per-night) + `campaign.json` (keyed by
   campaign id; facility/sectors across nights).
6. **UI: Prep/Live modes** + pinned operator HUD + live lighting sliders + adjacency
   quick-jump; fold in the interaction fixes.
7. **Polish:** hotkeys, token-id fix, mob scatter, initiative reorder/delay,
   cinematic transitions.

---

## 8. Roadmap (supersedes README §Planned)

- **v0.9 — Content model.** lighting/effects decomposition, Areas, full `scene`
  schema, validator + manifest report.
- **v0.10 — Events.** combat auto-music, blackout/resume, handout reveals, ping.
  (Enables staging-behind-blackout and the "trigger" half of the app.)
- **v0.11 — Operator UI.** Prep/Live modes, pinned HUD, hotkeys, preview-select,
  confirm/undo. (Where the app starts to *feel* good to run.)
- **v0.12 — Combat depth.** initiative reorder + Delay, mob ergonomics, token-id fix.
- **v0.13 — Map-relative content + fog of war** (per-map token/annotation sets;
  paint-to-reveal). Prereq: tokens anchored to map, not world space.
- **v0.14 — Physical-table calibration** (align projected grid to a physical mat).
- **v0.15 — Cinematic transitions** (shader wipes/dissolves into scenes & handouts).
  *Lighting-transition foundation landed:* `SessionState.transition_lighting()`
  tweens the whole lighting model (tod/season + a cinematic grade/energy + an
  additive `bloom`) over a duration, re-emitting `scene_lighting_changed` /
  `scene_bloom_changed` each frame so projector + LEDs move together with no
  hard snap. Projector `BloomLayer` renders the additive wash; authored scenes
  drive it via a `lighting` sequence step (`duration_ms`). Verified with an
  overcast→miracle movie capture. Still to do: shader wipes/dissolves for map
  and handout swaps.
- **v0.16 — Physical ambient lighting (WLED).** Mirror the scene lighting model
  onto the rig's LED square above the play area, so the room's ambient light
  matches the map. Extends the "app owns lighting" principle to a physical
  output — one source of truth (`compute_scene_tint`), two surfaces (projector
  tint + LEDs). `WLEDController` autoload; config in `assets/wled.json`
  (ships disabled). Two tiers: **Tier 1** presets/solid colour over the HTTP
  JSON API (per-map ambiance); **Tier 2** realtime per-pixel over UDP
  (DDP/DNRGB) for caustics, day/night sweeps, and DIRECTIONAL glow (light the
  edge the on-screen sun/torch faces). *Foundation landed:* wiring, config,
  packet builders, and the `scene_lighting_changed`/`blackout_changed` bridge
  are in; realtime protocols await validation against real hardware, and the
  overcast→miracle transition (v0.15) should bloom on the LEDs in lockstep.
- **v0.17 — Directional ambient (Philips Hue cardinal spotlights).** Four RGB
  spots at N/E/S/W. **Decision: Philips Hue Bridge** (chosen over a generic
  ZigBee dongle for zero always-on host + dead-simple HTTP; cost not a factor).
  ZigBee is *not* realtime (mesh, ~100–300ms, ~10 cmd/s/light) — so it's driven
  by "set target + native fade", NOT streamed: `SessionState.physical_lighting_
  target(tint, bloom, duration)` fires once per lighting change and each spot
  fades itself via the bulb's `transitiontime`. `HueController` autoload; config
  `assets/hue.json` (ships disabled); Hue v1 REST (plain HTTP), RGB→CIE-xy.
  *Foundation landed:* ambient wash + `set_cardinal` directional primitive +
  bridge probe are in; remaining = pair a real bridge (link-button app key).
  Note the Bridge does NOT control WLED, so the app talks to two endpoints
  (HueController + WLEDController) — fine; generalize a shared **directional-
  lighting** abstraction over both (`set_edge_glow` + `set_cardinal`) so the
  side the on-screen sun/torch faces lights on strip AND spot together.

---

## 9. Resolved decisions (2026-07-13)

Alexandre's answers to the original open questions, now baked into the doc above:

1. **Hierarchy = a plain tree: Campaign → Mission → Area → Map.** An Area is a place;
   it holds multiple **adjacent** maps (a town is the canonical multi-map area — market,
   throne hall, tavern — that players move between). The Map is the stageable unit.
   *(→ §2, §3.3–3.4)*
2. **Lighting = two sliders with named stops.** Time-of-day: `dawn / noon / dusk /
   midnight`. Season: `spring / summer / autumn / winter`. Sliders interpolate between
   stops; the names are for authoring/reference; both adjustable live. *(→ §3.5, §6.1)*
3. **Events: both manual triggers and authored auto-sequences** (`on_enter` etc.), all
   interruptible, sharing one primitive vocabulary. *(→ §5)*
4. **Handouts: full-screen reveals only.** Players use paper character sheets; the
   projector shows an image (a sheet copy, portrait, letter) at discussion beats, not
   during exploration. No corner-pinned overlays. *(→ §5)*
5. **Multiple campaigns supported** (one active now: Atlantis; plus a Calibration /
   testbed campaign). A campaign layer sits above missions; per-campaign save state.
   *(→ §3.1–3.2, §4)*

### Remaining smaller questions (non-blocking)

- **Region-crop vs separate image files** for maps within an area — the schema supports
  both (`image` + optional `region`). Fine to decide per-map as you author; only matters
  for whether we build a region-picker tool later.
- **Slider granularity** — do you want the time-of-day slider to snap to the 4 stops, or
  glide continuously between them? (I've assumed continuous glide with the 4 as labeled
  detents.)
```
