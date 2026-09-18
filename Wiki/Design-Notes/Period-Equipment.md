# Period Equipment & Acquire-on-Site Loot

The gear layer. Agents boost into an era carrying almost nothing; they **outfit from the local economy** once they arrive — markets, armories, temples, and the bodies of the people they put down. This doc is the system for that, plus the **equipment-card** format and the per-era rollout.

## Why agents arrive light

It falls out of the [boost economy](../Core-Setting/Temporal-Gradient.md). Climbing the gradient to a distant era costs by **mass × (1 − infusion)** ([Orichalcum grade table](../Core-Setting/Orichalcum.md#what-it-does-mechanically)). An agent's infused body and their [Antikythera](../Core-Setting/Antikythera-Device.md) come cheap; a footlocker of mundane steel does not. So doctrine is:

- **Boost in with:** the agent (infused), their device, maybe one **signature infused item** (a [luminous artifact](../Artifacts/Anachrotech.md) rides free — negative boost cost), and a small purse of period-tradeable valuables (coin, gold, gems that pass in-era).
- **Acquire in-era:** everything else — armor, weapons, tools, mounts, clothing, adventuring gear. Bought, bartered, gifted, stolen, looted, or improvised from what the era actually has.

This is not just economy — it is **cover**. Period-appropriate kit is invisible; anachronistic kit is a flag (see [The anachronism rule](#the-anachronism-rule)). Acquire-on-site is how a team blends in *and* stays cheap to insert.

## The equipment card

Each lootable item is a **card**: an illustration + a stat block. Cards are era-packed (see [rollout](#era-packs--rollout)) so a GM prepping an Ancient Greece mission pulls the Greece pack and knows exactly what's on the market and on the fallen.

A card carries:

| Field | Meaning |
|---|---|
| **Name** | In-era name + plain gloss (e.g., *Xiphos* — short bronze sword) |
| **Type** | Weapon / Armor / Shield / Gear / Consumable / Mount |
| **TL** | Tech Level of the era it comes from ([TL table](#tech-levels-by-era)) |
| **GURPS stats** | Damage/DR/effect + reach, parry, Min ST, weight, cost (see below) |
| **Availability** | Common · Uncommon · Rare · Signature ([tiers](#availability--sources)) |
| **Source** | Where you get it: market, armory, temple, a fallen foe, a ruin |
| **Notes** | Quality, cover value, cultural strings, quirks |

The **art** is a clean museum-style item illustration (see [card-art pipeline](#card-art-pipeline)); the **stats** live here in the wiki so they stay editable. The two are combined into a **printable card** at export time (see below) — text is composited over the art, never baked into it.

### Rarity & the printable card

Cards are printable (750×1050 px = 2.5×3.5 in @ 300 dpi, standard card-sleeve size), composed from item art + a stat block + a **rarity-coloured frame and bottom bar**. Rarity uses the familiar loot-game palette so a player reads value at a glance:

| Rarity | Colour | In-setting meaning |
|---|---|---|
| **Common** | grey `#9d9d9d` | market-standard / any fallen soldier |
| **Uncommon** | green `#3aa84f` | well-made, a specialist's or wealthy household's |
| **Rare** | blue `#2f6fd6` | elite / officer / fine quality |
| **Epic** | purple `#8a2be2` | masterwork / champion's / temple ceremonial |
| **Legendary** | gold `#ff8c1a` | [Signature / artifact](../Artifacts/Anachrotech.md) tier — named, bonded, unique |

Our availability tiers map onto it: Common → Common, Uncommon → Uncommon, Rare → Rare/Epic (by quality), Signature → Legendary. (Epic/purple is the quality step for a masterwork of an otherwise-mundane item.)

**Background:** every card shares a subtle campaign watermark (`assets/equipment/card_bg.png`) — aged parchment with a faint falling-shard-through-temporal-rings motif over a ghosted world map, low-contrast and concentrated in the upper margins, with the lower-center left plain. A translucent title band and a light scrim behind the stat block keep text crisp over it. (Item art carries the era flavor; the background is shared/era-agnostic.)

**Compositor:** `Atlantis/tools/make_card.sh` — builds the card entirely in **ffmpeg** (`drawbox` + `drawtext`; no PIL/SVG/browser on this box). Usage:

```
make_card.sh <art.png> <out.png> <rarity> "<name>" "<typeline>" "<stats \n-separated>" ["<flavor>"]
```

It renders the rarity frame + bottom bar, a title band, the framed art, an italic type line, the stat block, and italic flavor. Keep stats to **≤5 lines** so they clear the flavor + rarity bar. Proof cards (one per rarity): `assets/equipment/greece/card_*.png`.

## GURPS conventions

Stats follow GURPS 4e (Basic Set + Low-Tech), matching the [Character Sheets](Character-Sheets.md).

- **Weapons:** damage as `thr`/`sw` +mods and type (cut/imp/cr/pi), Reach, Parry, Min ST, weight (lbs), cost ($ in a nominal silver-standard — convert to local barter per era).
- **Armor / shields:** DR, body location covered (or shield DB), weight, cost. Layering and coverage matter.
- **Gear/consumables:** effect + skill it supports, weight, cost.
- **Quality axis** (GURPS): *cheap* (−1 to hit / −1 HT to break), *good* (standard), *fine* (+1 damage or +1 to hit), *very fine* (more) — a looted blade from a champion may be *fine*; a market blade is *good*; a conscript's is *cheap*.

> These values are **first-draft, tune to your Low-Tech edition.** As with the character sheets, treat them as playable starting points, not gospel.

### Tech Levels by era

| Era | TL | Notes |
|---|---|---|
| Deep Bronze Age (pre-2300 BCE) | TL1 | ATA-only reach; copper/early bronze |
| Bronze Age Aegean (~1450 BCE, Knossos) | TL1–2 | Bronze, figure-8 shields, boar's-tusk helm, rapiers |
| Classical / Hellenistic Greece | TL2 | Hoplite panoply, iron edging — the [proof pack](#proof-pack--ancient-greece-classicalhoplite-tl2) |
| Iron Age / Roman | TL2 | Steel improving; lorica, gladius |
| Medieval (Camelot era) | TL3 | Mail → plate; the [Excalibur](../Artifacts/Candidates.md#excalibur) arc's backdrop |
| Renaissance | TL4 | Early firearms alongside blades |
| Post-Columbian Mesoamerica (Aztec, 1519) | TL1 (stone) vs TL4 (Spanish) | The [Stone God](../Campaigns/Arc-XX-Stone-God.md) clash — obsidian macuahuitl vs steel |
| Early 20th c. (Long 1910s, Harbin) | TL6 | Bolt rifles, revolvers; the [Ember](../Embedded-Agents/Ember.md) era |
| Modern | TL8 | Present-day ATA baseline |
| EPOCH | TL11+ | Off the loot table — this is the *reward* tier, not the market |

## Availability & sources

Two axes: **how common** and **where you get it.**

- **Common** — any market stall or a typical fallen soldier. The team's default outfitting.
- **Uncommon** — a specialist smith, a wealthy household, a garrison armory. Costs coin or a favor.
- **Rare** — elite/royal/temple gear; a champion's panoply; ceremonial pieces. Usually *taken*, not bought, and taking it has consequences.
- **Signature** — named/unique, bridges into the [Artifacts](../Artifacts/Overview.md) layer. Not "loot" — it's a quest.

Between period loot and signature artifacts sits **[EPOCH standard kit](../Artifacts/EPOCH-Kit.md)** — the Rare/Epic "boss-drop" tier taken from defeated EPOCH agents (better than early ATA gear, self-boosting, but it pings as EPOCH).

**Sources** shape play: *markets* need currency or barter (and a cover story for a stranger buying weapons); *armories/garrisons* need infiltration; *temples* carry the rare/ceremonial and the heaviest cultural strings; *the fallen* give you whatever they were carrying (the fastest, bloodiest resupply); *ruins/tombs* yield aged, sometimes anachronistic finds.

## The anachronism rule

You cannot loot *up* the tech tree. A team in 1450 BCE can't buy a rifle; more importantly, **carrying out-of-era gear is a cover risk** — mundane observers find it strange, and any [infused agent](../Core-Setting/Orichalcum.md#agent-sense) or EPOCH operative reads anachronism as an intelligence tell. This is the same principle that makes a [glowing artifact a beacon](../Artifacts/Anachrotech.md#the-glow-is-a-beacon--concealment-is-a-permanent-player-problem): power that doesn't belong in the era announces you. Acquire-on-site keeps the team *legible* to the century they're standing in.

Corollary: gear you bring home is loot ([the Copper Scroll caches](../Artifacts/Candidates.md#the-copper-scroll-3q15), recovered artifacts); gear you acquire in-era is usually *left behind* at extraction (it's cheap to re-acquire and expensive to boost home).

## Era packs — rollout

Equipment is built **one era-pack at a time** — exactly like [map art](Map-Art-Generation.md). Each pack = a set of printable cards (art + stats) covering the weapons, armor, and gear a team would plausibly find in that place and time. Decks live in `assets/equipment/<pack>/card_*.png`; manifests in `tools/packs/<pack>.txt`.

**Generated (2026-07-17) — 9 packs, 110 cards:**

| Pack | Cards | For |
|---|---|---|
| Ancient Greece (Classical/Hoplite) | 14 | the proof pack |
| Bronze Age Aegean | 12 | [Knossos ~1450 BCE](../Missions/Knossos-Anteroom.md) |
| Aztec / Spanish 1519 | 12 | [the Stone God](../Campaigns/Arc-XX-Stone-God.md) — TL1-obsidian vs TL4-steel |
| Roman Imperial | 12 | Mediterranean legion missions |
| Medieval | 12 | [Camelot / Excalibur](../Artifacts/Candidates.md#excalibur) |
| Feudal Japan | 12 | the [Kusanagi](../Artifacts/Candidates.md#kusanagi-no-tsurugi-japan) arc, EPOCH East Asia |
| Early 20th c. (1920s) | 12 | [Long 1910s](../Campaigns/The-Long-1910s.md) / [Ember](../Missions/Ember-Extraction.md) |
| Modern | 12 | present-day ATA ops |
| [EPOCH standard kit](../Artifacts/EPOCH-Kit.md) | 12 | boss-drop tier (Rare/Epic) |

Add a new era by dropping a `tools/packs/<era>.txt` manifest and running `gen_pack.sh` (Renaissance, deep-future, etc., as arcs land).

## Card-art pipeline

Item illustrations use the [generate-image](Map-Art-Generation.md) tool with a **consistent template** so a pack reads as a matched set — a single item, centered on aged parchment, museum-plate style, no baked text:

> `A single <item>, <material/era detail>, museum illustration / painterly realism, centered and isolated on a soft aged-parchment background with a subtle drop shadow and faint vignette. Accurate to <era/culture>. No text, no labels, no border, no UI.`

Square (1:1) framing suits cards. Text (name/stats) is composed later or read from this doc — never baked into the art (unreliable, and stats change).

## Proof pack — Ancient Greece (Classical/Hoplite, TL2)

The exemplar. A hoplite's panoply plus adventuring basics — what a team would buy in an agora, lift from a garrison, or strip from a fallen phalanx. *(Stats first-draft; tune to Low-Tech.)*

### Weapons

| Item | Damage | Reach | Parry | Min ST | Wt | Cost | Avail. | Source |
|---|---|---|---|---|---|---|---|---|
| **Xiphos** (short leaf-blade sword) | sw cut / thr imp | 1 | 0 | 8 | 2 | $400 | Common | market · fallen hoplite |
| **Kopis** (forward-curved chopper) | sw+1 cut | 1 | 0 | 9 | 3 | $500 | Uncommon | smith · cavalry dead |
| **Dory** (thrusting spear, 1-handed w/ shield) | thr+2 imp | 1–2 | 0U | 9 | 4 | $40 | Common | market · armory · fallen |
| **Composite bow** | thr imp (per bow) | — | — | 10 | 4 | $900 | Uncommon | Cretan archers · market |
| **Sling** + lead shot | sw pi | — | — | 7 | 0.5 | $20 | Common | any market · skirmishers |

### Armor & shields

| Item | DR | Covers | Wt | Cost | Avail. | Source |
|---|---|---|---|---|---|---|
| **Aspis / Hoplon** (round shield) | DB 3 | shield | 18 | $90 | Common | armory · fallen |
| **Linothorax** (glued-linen cuirass) | 2* | torso, groin | 8 | $315 | Common | market · fallen |
| **Bronze muscle cuirass** | 5 | torso | 18 | $1,300 | Rare | officer/champion · temple |
| **Corinthian helm** (bronze) | 4 | skull, face | 5 | $340 | Common | armory · fallen |
| **Greaves** (bronze, pair) | 3 | shins | 4 | $220 | Uncommon | armory · officer dead |

*Linothorax counts as flexible; layered linen — treat as DR 2 (some tables run 1–3).*

### Adventuring gear & consumables

| Item | Effect | Wt | Cost | Avail. | Source |
|---|---|---|---|---|---|
| **Oil lamp** + flask | light ~2-yd radius, ~a few hrs/flask | 1 | $20 | Common | any market |
| **Rope, hemp** (30 ft) | Climbing/utility, holds ~300 lbs | 5 | $25 | Common | market · docks |
| **Wineskin** (water/wine) | 1 day's fluid; morale | 1 | $10 | Common | any market |
| **Physician's kit** (herbs, linen, probe) | First Aid at no penalty; Surgery basics | 3 | $200 | Uncommon | healer · temple of Asclepius |
| **Traveler's himation & chiton** | period cover / cold layer | 3 | $30 | Common | market |

**Cover note:** buying a full panoply as an unknown foreigner draws attention in most poleis — hoplites were citizen-soldiers who *owned* their gear. Better to arrive as a plausible mercenary, a xenos with a patron, or to strip the fallen after the fact.

## Cross-references

- [Core-Setting/Temporal-Gradient.md](../Core-Setting/Temporal-Gradient.md) & [Orichalcum.md](../Core-Setting/Orichalcum.md) — why agents boost light.
- [Artifacts/Anachrotech.md](../Artifacts/Anachrotech.md) — the *reward*-tier gear that rides free and breaks the loot rules (glowing, self-powered, bonded).
- [Design-Notes/Character-Sheets.md](Character-Sheets.md) — the GURPS builds this equips.
- [Missions/Overview.md](../Missions/Overview.md) — which era-pack each mission needs.

## Design decisions (canon)

- **Printable cards with rarity frames.** The deliverable is composed printable cards (art + stat block + rarity-coloured frame/bar), built by [`make_card.sh`](#rarity--the-printable-card). Stats stay editable in-wiki; the card is generated from them.
- **Tight packs — 10–20 iconic items per era.** No exhaustive catalogs; expand only where a specific mission leans on it.

## Open questions

- **Currency & barter.** How granular should in-era purchasing be? A simple "wealth level → what you can outfit" abstraction, or itemized coin? (Recommend abstract, with named big-ticket exceptions.)
- **Looting friction.** Is stripping the fallen free (grab-and-go) or a time/skill cost under pressure? Affects combat pacing.
- **Quality drops.** Should fallen-foe gear roll for quality (cheap/good/fine → Common/Uncommon/Epic frame), making a champion's blade a real prize? A fun, light loot-table option that plugs straight into the rarity palette.
- **In-app cards.** Do we also want these cards surfaced in the VTT (a loot/handout panel), or are they print/PDF handouts only?
