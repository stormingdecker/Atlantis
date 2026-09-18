# Character Themes

Suno music-generation prompts for embedded agents and bosses. Each character has a leitmotif intended to be substituted into the mission music at the appropriate tier (typically the Civilization tier for character moments and the Combat/Boss tier when that character is the focus of a fight).

See [Music-Conventions.md](Music-Conventions.md) for the prompt format, leitmotif engineering notes, and the three-layer faction/character/mission stack. Prompts here follow that format: era + genre, instrumentation, key/mode + tempo, mood + motif. All instrumental unless otherwise noted.

---

## ATA Agents (Player-Side)

### Bast

> Modern cinematic cat-burglar theme, solo oud over light pizzicato strings, finger-snaps and brushed darbuka, D minor Hijaz, 105 bpm. Recurring four-note descending playful motif. Instrumental, sly and unhurried.

**Combat / Chase Variant** — rooftop escape, things going wrong:

> Bast's cat-burglar theme accelerated. Solo oud playing fast, pizzicato strings driving urgent, brushed darbuka hammering, finger-snaps doubled. D minor Hijaz, 145 bpm. Same four-note descending motif, now breathless. Instrumental, sly turned scrambling.

### Chief

> Cool minimalist electronic-orchestral, single glassy piano notes over a low warm pad, distant bowed cello, A minor, 70 bpm. Recurring ascending three-note motif that resolves downward. Instrumental, composed and unreadable.

### Doc (Young) ↔ Doc (Old)

The canonical leitmotif pair. **Same melodic contour** — a rising four-note motif with a cocky upturn — rendered in two completely different orchestrations and tempos. Heard back-to-back, they should land as "the same person, fifty years later."

**Doc (Young)**

> 1940s workshop big-band stripped down: solo trumpet, walking upright bass, brushed snare, honky-tonk piano. F major, 130 bpm. Recurring rising four-note motif with a cocky upturn. Instrumental, restless and grinning.

**Doc (Old)**

> The Doc Young motif slowed to half-tempo and tender — same rising four-note contour, now in solo piano with distant muted trumpet and soft cello. F major, 65 bpm. Instrumental, weary and watchful, the look back across a long life.

**Doc (Young) — Triumphant Variant** — mission cleared, in his element:

> Doc Young's workshop big-band turned up. Solo trumpet leading a full small-band horn section, walking bass, brushed snare, honky-tonk piano. F major, 140 bpm. Same rising four-note cocky motif, answered by the full horns. Instrumental, swaggering.

### Major

> Sparse modern military score, low sustained strings, distant lone trumpet, hand-percussion taps, D minor Dorian, 80 bpm. Recurring two-note descending motif like a slow exhale. Instrumental, composed and unshakable.

**Combat Variant** — militarized for fight sequences:

> Major's military score tightened to a strike. Low sustained strings, sharp lone trumpet stabs, hand-percussion driving fast, sub-bass pulse beneath. D minor Dorian, 110 bpm. Same two-note descending motif, now punctuated. Instrumental, controlled and lethal.

### Sigerson

> Late-Victorian chamber piece, solo violin over pizzicato cello with a thoughtful clavichord pulse, A minor, 95 bpm. Recurring ascending-then-resolved motif that mimics a deduction landing. Instrumental, sharp and faintly amused.

### Mercury

> 1930s aviator-poster theme, warm muted trumpet melody over brushed snare, upright bass, soft strings, C major, 100 bpm. Recurring rising-fifth motif that lifts into a held suspended note. Instrumental, hopeful and unflinching.

**Anxious Variant** — downed plane, last transmission, the moment before extraction:

> Mercury's aviator theme thinned and trembling. Muted trumpet alone, no rhythm section, faint static crackle underneath. C major, 80 bpm. Same rising-fifth motif, now the suspended note doesn't resolve. Instrumental, hopeful then frayed.

---

## EPOCH Bosses

EPOCH character themes layer the [EPOCH faction signature](Music-Conventions.md#faction-signatures) — sub-bass pulse, granular pad, mechanical tempo — under an era-appropriate melodic surface. The collision of ancient instrumentation with brutalist electronics is the EPOCH sonic tell.

### Helen

> Bronze Age Aegean fragment over EPOCH cold-electronic underlay: solo lyre and bone-flute melody, sub-bass pulse beneath, granular synth pad, E Phrygian, 75 bpm. Recurring slow descending three-note motif. Instrumental, ancient and weary.

### Rasputin

> Russian Orthodox bass-chant (deep male vocalise, no words) over EPOCH electronic underlay, low orthodox bells, sub-bass pulse, granular pad, D minor, 60 bpm. Recurring descending stepwise motif. Hypnotic and intent. *(Vocalise — not instrumental.)*

---

## Recurring NPCs

Non-agent historical figures the party encounters repeatedly. Their themes pull from the surrounding mission's palette but carry a distinct contour so the character is identifiable across scenes.

### Prince Yusupov

Host of the Yusupov Cellar 1916 scene; witness aristocrat, neither ATA nor EPOCH but adjacent to both. The theme sits inside the [Yusupov Cellar location signature](Music-Conventions.md#location-signatures) palette and isolates Yusupov himself as a fragile gilded presence.

> Late-Imperial Russian aristocrat. Solo clavichord over distant violin tremolo, faint Orthodox choir vocalise in the deep background, sustained low string pad. F minor, 70 bpm. Recurring descending three-note motif on the clavichord. Vocalise — fragile.

---

## Usage Notes

- **Boss substitution.** When the named character is the boss of a mission, their theme replaces the mission's Boss tier. Helen's Stronghold uses Helen's theme at full intensity for the finale; Rasputin's Cellar uses Rasputin's theme.
- **Civilization substitution.** When a named character drives a significant non-combat scene, their theme replaces the mission's Civilization tier. The wreck scene at Howland uses Mercury's theme (see [Howland-Atoll-1937.md](../Missions/Howland-Atoll-1937.md#music-suite)).
- **Layering.** Character themes can be layered *over* the mission music rather than substituted — e.g., Sigerson present at a parlay in a mission with its own Civilization track. Suno can't do this for us; this is a play-time mixing decision for the GM.
- **Generating variants.** For each character, generate a small bank of mood variants by appending modifiers to the base prompt: "but anxious," "but triumphant," "but slowed and tender," "but militarized." Per [Music-Conventions.md](Music-Conventions.md), this is the most reliable Suno technique for keeping a leitmotif recognizable across emotional registers.
