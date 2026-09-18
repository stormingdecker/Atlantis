# Missions Overview

Mission locations for the Atlantis campaign. Each location is designed to support the three core gameplay pillars — **exploration, puzzle, combat** — with at least one of each per mission, and to render legibly as a **top-down VTT map.**

## Design Pillars

**Every mission delivers all three pillars.** A pure-combat mission is a skirmish, not a mission. A pure-puzzle mission is a riddle, not a mission. The three pillars interleave: the exploration phase plants the puzzle clues, the puzzle phase reveals the combat tactical layout, the combat phase pays off the choices made earlier.

**Top-down readability is a hard constraint.** Locations are designed as floor plans first, then dressed. Vertical interest (multi-level structures, cliff faces, water/sky layers) is handled via separate map tiles per layer, not via isometric rendering.

**Era distinctiveness.** Each location's era should be unmistakable at a glance — Bronze Age palace ≠ 1930s aerodrome ≠ Petrograd cellar ≠ 2200s facility. Players should know *when* they are from the map alone.

**Faction footprint.** ATA-friendly regions feel like home turf (anchor support, embed contacts, fallback routes). EPOCH-dense regions feel hostile from the moment the team inserts (every NPC is potentially a watcher, every anchor placement is contested). See `Factions/ATA.md` and `Factions/EPOCH.md` for the geographic asymmetry.

## VTT Map Conventions

> **Prompt recipe:** copy-paste templates and the full generation workflow live in [Map-Art Generation](../Design-Notes/Map-Art-Generation.md). This section is the *spec*; that doc is the *how*.

Maps come in two distinct visual tiers depending on use:

### Briefing maps — hand-painted parchment cartography
Used for mission briefings, strategic overviews, region maps, GM reference. Stylized, illustrative, evocative. Not designed to hold miniatures. Warm parchment background, painted illustrations, compass rose, scale bar.

### Play-surface maps — painterly-realistic top-down (Mike Schley / WotC house style)
Used for actual tactical play with miniatures or tokens. Painted realism with **strong silhouettes on tactical objects** (walls, doors, cover) and **reduced detail in walkable zones** so minis read clearly. This is the dominant style across the campaign's play surfaces.

**Hard technical specs for play surfaces:**
- **Scale.** 5-foot squares for indoor/tactical, 10-foot for compound/exterior, 30-foot for wilderness approach maps.
- **Resolution.** 140 pixels per 5-foot square at generation time — downscales cleanly to Roll20 (70 px) standard and prints at 1 inch per square.
- **Camera.** True 90° top-down, orthographic, zero tilt. Generators drift to a cinematic ¾-aerial the moment a scene has **buildings or crowds** — forbid it explicitly (the recipe's FLAT clause). **Buildings** must be drawn **roofs-off, as floor plans** (you see into the rooms with their furniture), never as roof-tops; **crowds** read top-down as **umbrella-tops and heads as circles, seen from directly above**.
- **Lighting.** Baked into the map: a single consistent sun from the **top-left (northwest)** across all play surfaces — shadows fall to the bottom-right. *Dynamic* lighting (time-of-day / season tint, blackout, torch flicker) is layered by the app at runtime on top of this baked base.
- **No baked overlays.** Do **not** bake a grid, compass rose, scale bar, or labels into a play surface — the app draws the grid (a dark **hex** overlay) and owns compass/scale. Generate *pure terrain*. Baked overlays belong only on **briefing maps**, which are illustration, not play surfaces.
- **Walkable zones.** Smooth muted floor textures (planks, stone tiles, packed earth, sand) without competing with minis. A 5-foot square needs ~25mm of clear visual space.
- **Cover legibility.** Hard cover (walls, vehicles, columns) drawn with **strong dark outlines**. Soft cover (crates, brush, furniture) drawn as filled silhouettes with subtle edges. Players must distinguish at a glance.
- **Layers.** Indoor maps ship with two passes: lit (normal play) and dark (infiltration / blackout / power-cut sequences).
- **Tokens.** Each named NPC at the location gets a distinct top-down token (separate asset from the map, generated at 140×140 px). EPOCH mooks share a token set per era.

### Boss-sequence escalation
Boss-sequence maps escalate to **full photorealistic painterly** (Czepeku / Forgotten Adventures style) as a deliberate "this fight matters" visual cue. Heavier texture, richer lighting, more atmospheric depth. Same top-down / 90° / single-light-source rules apply — only the detail density changes.

## Mission Roster

### Stage 1 — Recruitment & Training

- **[Arc 00 — The Cryo Train](../Campaigns/Arc-00-The-Cryo-Train.md)** *(designed)* — the campaign opener: the [Carpathian cache-cave](Carpathian-Cache-Cave.md) (scratch-signal, the bear, the hollowed boulder, the recruits' own Antikythera devices) and the cryo-train heist to rescue Sigerson, ending in the escape-*by-transit* to Atlantis — the home-base reveal, and the first captured EPOCH prisoner.
- **[The Origin Vault](Origin-Vault.md)** *(draft)* — ATA HQ in the eastern Mediterranean. The onboarding tour that immediately follows Arc-00's arrival. Briefing rooms, training simulators, the meteor chamber. The reveal moment for new agents.

### Stage 2 — Field Missions

- **[Howland Atoll, 1937](Howland-Atoll-1937.md)** — Pacific. The Mercury extraction. Beach insertion, downed Electra, EPOCH ambush camp. The mission that established the Reichenbach Protocol's second successful use.
- **[Reichenbach Falls, 1891](Reichenbach-Falls-1891.md)** *(draft)* — Swiss Alps. Vertical map. Either a re-visit (anomaly investigation at the extraction site) or a flashback training mission re-running Sigerson's original extraction. Cliff path, waterfall ledges, mountain lodge.
- **[Tunguska Impact, June 30 1908](Tunguska-1908.md)** *(draft)* — Siberian taiga. Wilderness exploration map plus a downed-object crater zone. Anomaly investigation. Open question: what *was* the impact, and which faction's operation went wrong?
- **[The Tarim Foothold](Tarim-Foothold.md)** *(draft)* — the Taklamakan desert, NW China. An early-20th-c. archaeology insert (with a deep-Bronze-Age follow-up) into EPOCH's *oldest* foothold — the out-of-place Tarim mummies. Desert survival, an excavation puzzle, and a preserved-operative prize. The built-out version of the [Historical Anomalies](Historical-Anomalies.md) Tarim seed.

### Stage 3 — High-Stakes Operations

- **[The Yusupov Cellar, December 1916](Yusupov-Cellar-1916.md)** *(draft)* — Petrograd palace. EPOCH is executing the Rasputin sublimation tonight. ATA inserts to interdict — or to witness, document, and withdraw. Tense urban infiltration, social cover, hard timing windows. EPOCH home-field disadvantage (Mediterranean-dense ATA reaching into Eastern Europe).
- **[Fátima, 13 October 1917](Fatima-1917.md)** *(draft)* — Portugal. The "Miracle of the Sun": a mass-observed psi/Mark broadcast before ~70,000 witnesses. The campaign's most *public* anomaly — impossible to quietly sanitize, the ultimate Timeline-Attention spike. Capstone of [The Long 1910s](../Campaigns/The-Long-1910s.md).
- **[Knossos Anteroom, ~1450 BCE](Knossos-Anteroom.md)** *(draft)* — Cretan palace complex during the Mycenaean intrusion period. Maze-like fresco corridors, ritual chambers, a contested anchor site. ATA home turf — this is the era and region where they're strongest. Puzzle-heavy with Bronze Age cultural challenges. Playable location for [Arc 01](../Campaigns/Arc-01.md).
- **[The Stone God, 1519](../Campaigns/Arc-XX-Stone-God.md)** *(designed arc)* — Aztec highlands on the eve of the Spanish arrival. An EPOCH autonomous-recovery unit, venerated by a local cult as a stone god, must be found and neutralized before contact. Fully designed; the write-up lives in Campaigns/.

- **[The Camelot Arc — Recovering Excalibur](Camelot-Excalibur.md)** *(draft)* — post-Roman Britain, late 5th–6th c. The flagship legendary-artifact arc: the sword-in-the-stone / Lady of the Lake / Merlin legend reframed as a botched EPOCH god-king op. Insert into the court, map the two rival embeds, and win the [luminous Mark VI blade](../Artifacts/Candidates.md#excalibur) (or deny it to EPOCH) — the gear-up spine's blade. Multi-session.
- **[Coming In From the Cold — the Ember Extraction](Ember-Extraction.md)** *(draft)* — Harbin, Manchuria ~1924 (EPOCH home turf). Recover the EPOCH defector [Ember](../Embedded-Agents/Ember.md): verify she's not a plant, cut her tracked device, and drop her home as a passenger before EPOCH reclaims-or-erases her. Turning point of the [artifact gear-up curve](../Artifacts/Anachrotech.md#the-gear-up-spine--arming-for-epoch) — she unlocks the research that closes the Mark IV→VI gap. Adds a mid-campaign playable character.

### Stage 4 — Boss Sequence

- **[Helen's Stronghold](Helens-Stronghold.md)** *(draft, candidate)* — Late Bronze Age, location TBD. Helen as field-deployed Grade-III generalist. Multi-phase encounter: approach, social/puzzle, combat. Survivable but punishing.
- **[A 2200s EPOCH Facility](EPOCH-Facility-22C.md)** *(draft, candidate)* — Deep-future EPOCH HQ. Maximum spatial-temporal cost to reach. The campaign's reverse-Mediterranean: ATA inserting as the away team into EPOCH's home era. Final boss sequence candidate.

Final boss location should be chosen once the campaign's narrative arc settles — Helen feels right for a "confront the seductive face of EPOCH" climax, the 2200s facility feels right for a "strike at the root" climax. We can also stage both: Helen as Act II climax, 2200s as Act III finale.

### Mission Seeds & Cross-Cutting Arcs

- **[Historical Anomalies](Historical-Anomalies.md)** *(draft)* — a catalog of real unexplained events (the Tarim mummies, the Bronze Age Collapse, the Dancing Plague of 1518, the Roanoke / Mary Celeste vanishings) reframed as shard-falls, extractions, and EPOCH operations. A holding page for self-contained missions and arc threads.
- **[The Long 1910s — the Belle-Époque Surge](../Campaigns/The-Long-1910s.md)** *(draft arc)* — ties the early-20th-c. missions (Reichenbach 1891, Tunguska 1908, Yusupov 1916, Fátima 1917) into one meta-arc: a hinge era where EPOCH pushes hard while ATA is transit-stretched reaching forward to it.

## Open Design Questions

- Do we want a recurring **safe house** location per era for between-mission downtime, or do agents always return to the Origin Vault?
- How many distinct EPOCH-controlled era-stronghold maps do we need? (Probably 1–2 per major era they operate in.)
- Should the Origin Vault itself ever be **attacked** — i.e., does EPOCH ever bring the war home, and what does that map look like?
