# Temporal Production (Temporal Maturation)

A **cross-sector production capability**, not a new sector. It lets the facility
run any process that is gated by *elapsed time* — aging, culturing, growth,
crystallization — by doing it downstream in the past and retrieving the finished
result. It turns the base's mundane sectors (kitchen, farm, forge, lab) into
sources of anachronistic goods that become mission tools.

See [Base-Upgrades.md](Base-Upgrades.md) for the sector/tier system this rides on.

## The key insight: it's the mechanic the base already runs on

The [Base-Upgrades](Base-Upgrades.md) cycle already dilates time: an upgrade's
build runs while the team is deployed, and the [Antikythera device](../Core-Setting/Antikythera-Device.md)
sets each agent's *return coordinate* so they arrive home **after** the work
completes. Temporal Production is the same move applied to **objects and
processes** instead of people:

> Send a thing into the past, let real years act on it, retrieve it transformed.

Because the return coordinate is controllable, the batch can be scheduled to
"be ready" when the team gets back — so it costs no real session time. What it
costs is **inputs, transit throughput, a secure aging site, and paradox
attention.**

## What it's good for: the "long-process" class

Anything whose only real barrier is *time* becomes practical:

| Process type | Examples | Typical payoff |
|---|---|---|
| **Aging / maturation** | wine, spirits, cheese, cured meats, seasoned wood | bribes, gifts, social leverage, forgeries |
| **Crystallization** | slow-forming compounds, certain drugs that only crystallize over years | medicines impractical to make any other way |
| **Culturing / fermentation** | antibiotic cultures, antivenins, vinegars, engineered bacterial/fungal strains | field cures, poisons, bio-agents |
| **Growth / breeding** | extinct heirloom crops, selectively bred lines, pearls, special timbers | rare botanicals, trade goods, mission consumables |
| **Weathering / patination** | artificially "genuine" antiques, aged documents | forged provenance, cover props |

The unifying pitch to players: *"We can't wait 40 years for that penicillin
culture to mature — so we won't. We'll grow it in 40 years that already
happened."*

## Cross-sector: which sectors produce what

Temporal Production is a **mode** the relevant sectors gain at higher tiers, not
its own sector:

- **Commons (O-5)** — wines, spirits, delicacies. Social leverage: bribes,
  gifts, the impossibly-perfect vintage that opens a duke's door.
- **Farm & Agri-Tech (O-4)** — extinct/heirloom crops, fast-bred cultivars, slow
  botanicals. Feeds Commons and Medical; introduces plants to eras.
- **Genetics Lab (I-6)** + **Medical (O-6)** — the bio branch: cultured cures,
  antivenins, slow-crystallizing drugs, engineered strains. (Gated by Lab T2+,
  consistent with the [RU dependency graph](Base-Upgrades.md#ru-dependency-graph).)
- **Foundry (I-3)** — objects forged then aged/patinated downstream: a genuinely
  500-year-old blade with real wear and provenance. (This is how you'd make a
  convincing Excalibur.)
- **Museum & Library (O-7)** — the *authenticator*: certifies the provenance of
  matured goods so an expert NPC believes them. Doesn't produce; it launders
  legitimacy.

## The gate

Deliberately RU-gated so it's a chosen campaign direction, not a freebie:

1. **RU: Object Return-Anchoring** — unlocks the capability at all.
   The breakthrough that lets the Antikythera return-anchor a dropped *object*
   rather than a living agent. Sourced from a research arc.
2. **Relevant sector at T2+** — the sector that makes/finishes the good must be
   modern enough to run the batch (bio goods also require Genetics Lab T2+).
3. **Transit Hub (I-8) at T2+** — production occupies a transit channel (see Cost
   model). At T1 (single chamber) a batch would block all mission deployment, so
   production requires the multi-chamber T2+ hub.
4. **A secure aging site** — a stable spot in a controlled past era where the
   batch sits undisturbed for its maturation years. Ties into the **Artifact
   Vault (I-7)** temporal-caching capability; a poorly-chosen site can be
   *discovered or disturbed*, spoiling or altering the batch (a mission hook).

> **Folded into [Base-Upgrades.md](Base-Upgrades.md):** the "Object Return-Anchoring" RU (RU Examples table), the *Timeline Attention* tracker (I-5 Reality Log), and *temporal-caching* / aging sites (I-7 Artifact Vault) are now part of the base-upgrade canon.

## Cost model (proposed — tune in play)

Runs on **Transit Hub throughput + inputs**, NOT the sector-upgrade build slots.
Rationale: upgrades are months-long infrastructure commitments; production is a
recurring, lighter action you want players tempted to use often.

- Each batch consumes **inputs** (a Farm crop, Foundry billet, Lab culture stock).
- Each batch occupies a **Transit Hub channel** for a cycle — so Transit Hub tier
  (chambers) directly caps how much you can produce in parallel. Nice synergy:
  the infrastructure curve and the goods curve reinforce each other.
- No TP cost per batch; the TP investment is upstream (upgrading the sectors that
  enable it).

## Output: goods as concrete consumable assets

Goods are **named items**, not a fungible currency — more flavorful and
mission-specific. Each carries two light ratings:

- **Leverage** (how strong a social/mechanical lever it is — a modifier the GM
  applies to the relevant roll, or a flat "buys one favor of scale X").
- **Anachronism** (how obviously out-of-time it is — see below).

Example goods:

| Good | Sector | Process | Mission use | Anachronism |
|---|---|---|---|---|
| Century Vintage | Commons | 100-yr aging | Bribe/gift a noble; opens a door | High (impossible year) |
| Field Antivenin | Lab+Medical | slow culture | Negate a venom/disease threat in the field | Low (looks like folk medicine) |
| "Ancestral" Heirloom Blade | Foundry | forge + patina | Planted proof of lineage; a gift with a story | Med (provenance can be probed) |
| Extinct Grain Sack | Farm | reclaim + grow | Trade good; famine relief; introduced-species hook | Med |
| Slow-Crystal Cure | Medical | multi-yr crystallization | A medicine that otherwise cannot exist yet | Low-Med |

## The balancing lever: Timeline Attention

Temporal Production is not free power — it spends into the **[Reality Log](Base-Upgrades.md#i-5-reality-log-archive)**'s
paradox-attention. Every good has an **anachronism profile**:

- To a fool, the Century Vintage is a bribe.
- To a connoisseur, it's proof the bearers are not of this time.
- If it becomes *historically famous*, it edits the timeline — Reality Log logs
  the attention, and enough attention draws EPOCH notice, historical
  investigators, or a paradox event.

Track **Timeline Attention** as a rising meter (light but real), on the [Reality Log](Base-Upgrades.md#i-5-reality-log-archive). Subtle
goods add little; blatant ones add a lot. High attention escalates an arc. This
keeps the exploit delicious *and* self-limiting.

## Combos (the good stuff)

The system sings when sectors chain:

> Farm grows the extinct grape → Commons ages it a century overnight → Museum
> certifies its provenance → the team gifts it to a duke who'd have hanged them
> for a forgery. One bottle, four sectors, and a door nobody else could open.

Or the bio chain: *Lab engineers a strain → Farm cultivates it downstream →
Medical crystallizes the extract → the team walks into a plague city immune.*

## Hooks into existing canon

- **Grail Quest / Cellular Regeneration** — regen tech + Temporal Production =
  cultured regenerative compounds at scale.
- **Foundry / Excalibur** — the forge-and-age pipeline is the honest answer to
  "where do legendary artifacts come from?"
- **Genetics Lab bottleneck** — bio goods inherit the Lab-T2 gate, reinforcing
  the existing "upgrade the Lab early" pressure.
- **EPOCH** — do they do this too? An EPOCH-produced anachronism in the field is
  a chilling tell that they've cracked Object Return-Anchoring.

## Open questions

- **Attention accounting.** Flat per-good values, or GM-judged per situation?
  Start GM-judged, formalize if it needs structure.
- **Aging-site jeopardy.** How often should a cached batch be disturbed? Rare
  (a dramatic beat), not routine (bookkeeping tax).
- **Agent maturation (dark variant).** Could an *agent* be sent downstream to
  train/age for years and return older + more skilled? Powerful and grim
  (they lose those years of their life). Probably a one-off character beat, not
  a system. Flagged, held.
- **EPOCH parity.** Is Object Return-Anchoring an ATA breakthrough, or does EPOCH
  already have it (making anachronistic goods a two-way arms race)?
