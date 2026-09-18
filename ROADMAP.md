# Atlantis — Recommendations, 2026-08-19

Written after the 2026-08-13→17 audit and fix pass. Everything here is grounded in
something I measured or looked at; where it's a taste call I say so.

Ranked by **table impact per unit of work**, not by how interesting it is to build.

---

> **Status 2026-08-20:** P0 items 1, 2 and 3 are **done**, and the symmetry check
> from #2 shipped with it. #4 (music) is still yours. P1 onward untouched.

## P0 — things that will bite you in an actual session

### 1. Harbin rail yard projects as blue mud — ✅ DONE 2026-08-20
Settled on `light_energy: 1.85` + `light_grade: [1.24, 1.02, 0.72]`. YAVG 25.4 → 46.7,
in band with its siblings. **The energy knob alone was not enough** — see the note at the
end of this item. No re-render needed; the plate underneath was fine.

`harbin_extraction` staged capture measures **YAVG 37.9** against 54.2 / 61.6 / 55.8 for
its three sibling tiles — ~35% darker than anything else in the mission. Looking at the
render rather than the number: the locomotive in the centre of the frame is barely
distinguishable from the snow around it, and the *hex strokes are the most legible thing
on screen*. That is backwards for the map the chase scene happens on.

Cause is boring: it's the one Harbin tile with no `light_energy` key, so it takes the
0.72 night grade at full strength on a plate that was already rendered dark.

**Do the cheap thing first** — and that was right, but incomplete. Lifting
`light_energy` on its own gives you *brighter blue mud*: at `time_of_day: 0.72` the tint
is roughly `(0.58, 0.62, 0.82)`, the winter bias pushes it further blue, and the plate
was **generated** as a night scene so it carries its own cast underneath. Energy scales
that whole stack uniformly and never touches the ratio. `light_grade` pushed warm at the
same time is what actually recovers the frame. Recorded here because the next dark plate
will hit the same wall.

### 2. Harbin has a one-way door — ✅ DONE 2026-08-20
`rendezvous` added to `epoch_site_dark.adjacent`, and `validate_content.py` now warns on
any one-way link. Verified the check fires by reintroducing the bug.

`rendezvous → epoch_site_dark` is listed, but `epoch_site_dark` does not list
`rendezvous`. If the party goes to the compound after hours and then wants to walk back
to the river, the GM has no adjacency button for it. Mine, from the wiring pass.

Fix: add `"rendezvous"` to `epoch_site_dark.adjacent`, **and** add a symmetry check to
`tools/validate_content.py` so this class of slip can't recur. I ran the check ad hoc —
Harbin is the only offender today, so the check will pass everywhere else immediately.

### 3. `harbin.json` `gm_notes` lies to the GM — ✅ DONE 2026-08-20
It says "snow effects and the winter-wind bed run on every tile". Both compound tiles
carry `"effects": []` — deliberately, they're interiors. The GM reads that note at the
table and expects weather that won't come.

### 4. Music is 100% placeholder
All 16 authored scenes are `"suite": "test_mission"`, and `assets/audio/music/missions/`
contains exactly that one directory. This is the single biggest gap between "the VTT
works" and "the VTT is good at the table", and it's yours (Suno) — I'm not filling it in.

What I *can* usefully do is make the drop-off trivial: document the expected suite
layout (`missions/<suite>/<tier>.ogg` for the four tiers) in DESIGN.md and add a
validator warning when a mission's suite is `test_mission`, so placeholder scenes are
visible in the report instead of silently shipping.

---

## P1 — clear quality wins, bounded scope

### 5. Hex overlay is tuned for bright maps only
`HexOverlay` in `projector.gd` is hardcoded `LINE_COLOR = Color(0, 0, 0, 0.42)`,
`LINE_WIDTH = 1.5`. On `fatima_cova` and `harbin_extraction` the grid stops being a
reference and becomes the subject — pure black on an already-dark plate is the highest
local contrast in the frame.

Two options, in order of preference:

1. **Per-scene keys** `hex_color` / `hex_opacity`, defaulted to today's values. Same
   shape as `light_energy` — author-time control over something that was a constant.
   Cheap, explicit, and consistent with how the rest of the scene block works.
2. Luminance-adaptive stroke (sample the plate, go white-ish on dark maps). Cleverer,
   but it's one more thing that can surprise you mid-session, and this is a
   never-crash-at-the-table product.

I'd ship (1).

### 6. Turn the luma check into a tool
I found #1 by hand: stage each map headless, run `ffmpeg -vf signalstats`, compare YAVG.
That should be a verb — `iterate.sh luma` — that walks every authored scene, stages it,
and flags anything outside a sane band (say 45–75) or more than ~20% off its area's
median. This is the "look at the thing before you say it works" discipline turned into
something that runs unattended.

It is also the only way the map count scales. At 16 maps I can eyeball them all; at 50 I
can't.

### 7. Mission-scope briefings don't exist in the code
`cache_briefing.png` (8.2 MB) and `fatima_briefing.png` (8.1 MB) are unreachable. They
were authored at *mission* scope; the code only knows map-scope briefings
(`<map_base>_briefing.png` by convention, or an explicit per-scene `briefing` key).
Harbin works around it by repeating the same explicit `briefing` on all four maps.

Add `briefing` to `mission.json` as a fallback when a scene doesn't specify one. That
recovers 16 MB of already-paid-for art, kills the workaround, and is maybe 15 lines in
`session_state.gd`.

### 8. Ambience library is thinner than the content
Four beds across 16 scenes, and one is miscast: `fatima_ridge` plays
`amb_desert_wind.wav` under rain on an autumn Portuguese hillside. `tools/gen_ambience.py`
exists now and is quick to extend — `amb_hillside_wind`, `amb_night_forest`,
`amb_machine_room` (for the compound interiors, which currently play outdoor wind).

### 9. Docs have drifted off the contract
`IMPLEMENTATION.md` (last touched Jul 13) still lists v0.9 as future work. `DESIGN.md`
(Jul 16) uses Camelot/Excalibur for its examples — a mission that isn't wired — and
neither document mentions Harbin, `tools/gen_ambience.py`, or the ambience/briefing
validator checks. `light_energy` I did add.

These two files are explicitly the "so a fresh session doesn't reinvent decisions"
contract. Drifted, they actively cause the thing they exist to prevent.

---

## P2 — content, where the real leverage is

### 10. The Wiki is nine missions ahead of the VTT
14 mission write-ups in `Wiki/Missions/`; **4** are wired (Carpathian Cache, Fátima,
Tarim, Ember Extraction). Unwired: Camelot/Excalibur, EPOCH Facility 22C, Helen's
Stronghold, Howland Atoll 1937, Knossos Anteroom, Origin Vault, Reichenbach Falls 1891,
Tunguska 1908, Yusupov Cellar 1916.

Wiring one mission is now a well-worn path (canon → mission.json + area.json → art →
lighting → stage-and-look). Harbin took one evening including four regenerated plates.

**Start with Knossos Anteroom** — its art already exists (`knossos.png`, `labyrinth.png`
in the legacy tree), so it's a migration rather than a generation job, and it retires the
legacy tree as a side effect (see #12). **Then Yusupov Cellar 1916** — a single interior
room, one plate, and it's the strongest scene in the write-up.

Avoid Origin Vault and EPOCH Facility 22C for now; both want interiors with multiple
floors, and the strict-nadir prompt is least reliable exactly there.

### 11. Every mission wants a second lighting state
The pattern that's working (`cache_den`/`cache_den_dark`,
`tarim_excavation`/`_dark`, `harbin_epoch_site`/`_dark`, `fatima_cova`/`_storm`) is one
plate with an authored alternate. It's the cheapest drama the VTT has: same geometry, the
players immediately read that something changed. `cache_approach`, `cache_chamber`,
`tarim_desert` and `harbin_rendezvous` have no alternate. Add one each.

---

## P2 — cleanup

### 12. Retire the legacy `assets/missions/` tree
`assets/missions/index.json` still registers `arc01_knossos` with five files
(`01_staging`, `02_knossos`, `03_labyrinth`, `04_debrief`, `mission.json`), and
`scripts/main.gd:36 DEMO_MAP_PATH` points at `atlantis.png` through it. The validator
walks both formats, which means two code paths and two authoring conventions live
forever.

Sequence: migrate Knossos to `assets/campaigns/` (#10) → repoint `DEMO_MAP_PATH` →
`mv assets/missions assets/missions.retired` → drop `validate_legacy()`. Move, don't
delete; Drive is shared and addressed by folder ID.

Note the legacy plates are **2048×2048**, against the 2752×1536 house standard — they'll
pillarbox on a 16:9 projector. Migrating them means re-rendering or accepting bars.

### 13. 287 MB of PNGs, 24 maps
~12 MB apiece. It's photoreal art so some of that is real, but these are projector
plates, not print. A quality-90 WebP pass would plausibly take this under 60 MB with no
visible difference at throw distance, and Godot loads WebP natively. Worth measuring on
one plate before committing.

Also off-standard: the two orphan briefings are 2528×1696 (aspect 1.491) against the
house 1.792. If #7 lands and they become reachable, they'll letterbox in the GM pane.

---

## P3 — parked, on purpose

### 14. WLED
`wled_controller.gd:339` still carries the HARDWARE-TODO and the feature is disabled by
default. That's the right state — but DESIGN.md should say "deferred pending hardware"
rather than describing it in the present tense, so it stops reading as half-finished
work someone should pick up.

---

## Suggested order

If you want a single thread to pull: **1 → 2 → 3** tonight (an hour, all three are
Harbin polish and #1 might be one JSON key), then **5 → 6** (grid legibility plus the
luma tool, which is what stops #1 recurring), then **10** (Knossos, which drags #12
along behind it).

Music (#4) sits outside that thread and is worth more than any of it.
