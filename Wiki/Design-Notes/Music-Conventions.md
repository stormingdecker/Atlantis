# Music Conventions

How we score the campaign. Designed around Suno-generated tracks with intentional leitmotif structure across characters, missions, and factions.

## The Four-Tier Mission Music Structure

Every mission ships with a **4-piece music suite**. The four tiers are:

1. **Exploration** — outdoor approach, wilderness, the long walk in. Atmospheric, sparse, breathing room. Plays during the insertion phase and any travel/investigation in open terrain.
2. **Civilization** — social/encounter music. Plays when the party reaches a populated area, parlays with NPCs, gathers intel in a settlement, OR meets a significant non-combat NPC in any setting. For missions without a populated zone (uninhabited atolls, dungeons, deep wilderness), this slot covers the **significant social/character moments** — the wreck scene with Earhart, the cellar parlay with Yusupov, the audience with the queen, etc.
3. **Combat** — minor encounters. Mooks, ambushes, tactical fights against rank-and-file opposition. Driving, tense, but not maxed out.
4. **Boss** — climactic encounter. The mission's apex fight or confrontation. Full intensity, full orchestration. Reserved exclusively for the moment — overuse kills the dramatic weight.

**The four pieces share a sonic palette** — same key/mode, same instrumentation family, same era-flavored production. They are heard as variants of a single mission identity, not as four unrelated tracks. The shift from Exploration to Boss should feel like one piece building over an hour, not a playlist change.

## Suno Prompt Conventions

Each prompt is written as 1–3 sentences in this structure:

1. **Era + genre** — e.g. "1930s big-band torch song stripped to," "late-Victorian chamber piece"
2. **Instrumentation** — name the instruments explicitly
3. **Key/mode + tempo** — e.g. "D minor Phrygian, 90 bpm"
4. **Mood + motif notes** — what emotion, what's the recurring melodic/harmonic hook

Always mark **instrumental** (Suno toggle + reinforce in prompt) unless we specifically want vocalise/chant. Keep prompts under 250 characters for compatibility across Suno's prompt modes.

**Leitmotif engineering in Suno.** Suno will not literally reproduce a melody across separate generations — it's not that kind of tool. What we *can* control is:

- **Consistent palette.** Same instruments + same key + same era stay recognizable across variants.
- **Motif description.** Explicitly describing a melodic shape ("recurring three-note descending motif," "ascending fifth then a held suspended note") shapes the generation toward that contour. Use this to seed a theme.
- **Same prompt + different mood modifiers.** The most reliable leitmotif technique: write a base prompt for a character/faction, then generate variants by appending mood modifiers ("but anxious," "but triumphant," "but slowed half-tempo and tender").

The **Doc Young / Doc Old** pair (see [Character-Themes.md](Character-Themes.md#doc-young--doc-old)) is the canonical leitmotif example — same melodic contour described, totally different orchestration and tempo, yields the "same person, fifty years later" effect.

## Character vs Mission vs Faction Music

Three layers stack:

- **Faction signatures** — ATA and EPOCH each have a sonic identity that can be hinted at in mission music when one faction's presence dominates. (See *Faction Signatures* below.)
- **Character themes** — each named NPC has a leitmotif. When that character is present and active in a scene, their theme can be substituted for or layered over the mission piece appropriate to the tier. (E.g., the Boss tier becomes Helen's Theme — Combat Variant during Helen's Stronghold finale.)
- **Mission suite** — the four-tier default for the location, used when no overriding character is dominant.

In practice: most scenes use mission music. Boss scenes typically use the boss character's combat theme. Significant character moments (Civilization tier) typically use the character's theme directly.

## Faction Signatures

**ATA** — warm orchestral, French horns prominent, hope-tinted melancholy. Modal harmony leaning Aeolian or Dorian. Real-instrument production, organic, breathing. The sound of preservation, of carrying something fragile through history.

> Warm orchestral, prominent French horns, string quartet underneath, organic and breathing, Aeolian mode, hope-tinted melancholy. The ATA faction signature.

**EPOCH** — cold orchestral + electronic hybrid. Granular synth pads + sub-bass + restrained brass stabs. Brutalist precision. Tempo is mechanical, never *rubato*. The sound of consolidation, of certainty, of a future that has already been decided.

> Brutalist orchestral-electronic hybrid, granular synth pads, sub-bass pulse, restrained brass stabs, mechanical 90 bpm tempo, no rubato. The EPOCH faction signature.

These signatures can be quoted inside mission music — a mission heavily contested by EPOCH might layer the EPOCH signature's sub-bass pulse under the Combat and Boss tiers, even if the rest of the orchestration is mission-specific.

## Location Signatures

Some places carry campaign-wide thematic weight and get their own quotable identity — not a four-tier mission suite, but a single thematic piece that can be substituted into any tier when that location's gravity dominates the scene (a flashback to Atlantis, a deep-EPOCH-territory infiltration, etc.). When those places eventually anchor full missions, the four-tier suite is generated as variations on the signature.

**Atlantis** — the foundational myth. Submerged, vast, beautiful, half-remembered. Wordless choir over deep sustained strings and water-resonant percussion. Lydian mode for the otherworldly beauty; the dissolving motif because the city itself is a memory that won't fully resolve.

> Ancient submerged-city theme, wordless female choir over deep sustained low strings, distant bowl-gongs and water-resonant hand percussion, bowed double-bass drone, D Lydian, 50 bpm. Recurring slow ascending three-note motif that dissolves. Vocalise — luminous and mournful.

**EPOCH Base (Facility 22C)** — the [EPOCH faction signature](#faction-signatures) taken to its logical extreme. No melody, just architecture. The sound of a place that has already decided what happens next.

> Brutalist EPOCH headquarters theme, sub-bass pulse on every beat, layered granular synth pads, cold brass stabs in tight rhythm, mechanical 90 bpm with zero rubato, D minor, recurring three-note descending stab figure repeated like a metronome. Instrumental, oppressive and certain.

**Origin Vault** — the ATA HQ in the eastern Mediterranean. The recurring "home base" cue: between-mission downtime, briefings, the place agents return to. Ancient-modern fusion that signals *safety + lineage* without being saccharine.

> Eastern Mediterranean ancient-modern fusion. Oud over warm French horn, low cello drone, distant cicadas. D Dorian, 60 bpm. Recurring four-note ascending motif settling into a sustained chord. Instrumental, calm and rooted.

**Reichenbach Falls (1891)** — Swiss Alps. Sigerson's extraction site, and a recurring poetic anchor for the campaign's "borrowed from death" motif. Sublime, vertical, the sound of a place that almost killed someone.

> Late-Victorian mountain mysticism. Solo violin, sparse harp arpeggios, distant alpine horn, sustained string pad, water-sheet white noise. G minor, 70 bpm. Recurring two-note descending motif like a held breath. Instrumental, sublime and vertiginous.

**Tunguska Impact (1908)** — Siberian taiga at the moment of the anomaly. Wilderness that has just been disturbed by something it can't name.

> Russian Romantic forest theme cracked open. Sparse balalaika tremolo, low contrabassoon, hand-percussion taps, sub-bass swell. B minor, 55 bpm. Recurring rising-then-broken three-note motif. Instrumental, vast and uneasy.

**Yusupov Cellar (Petrograd 1916)** — gilded Imperial Russian decadence with the EPOCH underlay creeping in beneath it. The two factions audibly contesting the same room.

> Imperial Russian chamber piece with EPOCH underlay. Solo violin and clavichord, Orthodox bell tolling beneath, faint sub-bass pulse, granular pad. F minor, 75 bpm. Recurring descending four-note motif. Instrumental, gilded decadence over cold.

**Knossos Anteroom (~1450 BCE)** — Bronze Age Cretan palace, ATA home turf. The era and region where the faction is strongest; the music should feel *welcoming* in a way most missions don't.

> Bronze Age Aegean palace, ATA home. Solo lyre and bone flute over warm low strings, distant ceremonial drum, soft female wordless choir in the distance. E Phrygian, 80 bpm. Recurring ascending three-note motif. Vocalise — bright and ancient.

**ATA Safe House — Travel Cue** — an era-flexible underscore for between-mission downtime, transit, and quiet character beats. Not tied to a specific era so it can sit under any setting.

> Generic warm travel cue, ATA-flavored. Low French horns over brushed snare, sustained string pad, soft pizzicato cello pulse. C minor Dorian, 90 bpm. Recurring two-note descending motif, settled and patient. Instrumental — catching your breath.

Location signatures live as flat files (see *File Organization* below). In the VTT they appear in the **Singles** list and can also be referenced as a tier within any mission suite.

## File Organization

Music files live in `VTT/assets/audio/music/` organized by:

```
music/
  factions/
    ata_signature.ogg
    epoch_signature.ogg
  locations/
    atlantis.ogg
    epoch_base.ogg
  characters/
    sigerson_theme.ogg
    mercury_theme.ogg
    ...
  missions/
    howland_1937/
      01_exploration.ogg
      02_civilization.ogg
      03_combat.ogg
      04_boss.ogg
    yusupov_1916/
      ...
```

The VTT's GM panel surfaces two music modes:

- **Mission Suites** — each subfolder under `music/missions/` is a four-tier suite. The GM picks a suite from a dropdown and switches tiers via Exploration / Civilization / Combat / Boss buttons. Tier mapping is by filename: any file whose lowercased name contains the tier word is mapped to that tier (so `01_exploration.ogg`, `boss.ogg`, `04_boss_climax.ogg` all work).
- **Singles** — every music file anywhere under `music/` (recursive). Faction signatures, location signatures, character themes, and any ad-hoc cue all live here, accessible by name as a one-off override.
