# Base Upgrades

The Atlantis facility as a board-game-style progression layer. Sectors start at Tier 1 and can be upgraded to Tier 3 over the course of the campaign by spending mission rewards.

This is one of the campaign's three macro-progression layers:
- **Character XP** (per-PC, per-session)
- **Foundry Mark** (the gear-availability curve, see [../Core-Setting/Orichalcum.md](../Core-Setting/Orichalcum.md))
- **Base Upgrades** (this doc) — the sector-level capability curve

Related: [Temporal-Production.md](Temporal-Production.md) — a cross-sector capability (unlocked via upgrades) that turns the base's mundane sectors into sources of anachronistic mission goods by running time-gated processes downstream.

## The Mechanic

### Currencies

Two currencies feed the upgrade system, both earned from missions:

| Currency | What it is | How it's earned |
|---|---|---|
| **Technology Points (TP)** | Generic upgrade budget | Mission completion, artifact recovery, captured EPOCH gear, decoy detection. See [Mission-Design.md](Mission-Design.md). |
| **Research Upgrades (RU)** | Specific *unlocks* — named breakthroughs | One-shot rewards from specific arcs. Not currency — each RU is a particular thing (e.g., "Cumaean Precog Cooperation," "EPOCH Genetic Screening Protocol"). |

TP buys *quantity*. RU unlocks *capability*. Most T2 upgrades cost TP only. Most T3 upgrades require a relevant RU plus TP.

### The Upgrade Cycle

To upgrade a sector:

1. **Commit the build.** Player spends the required TP (and the required RU, if any) at the end of a session, before the next deployment.
2. **Set the return clock.** The facility starts the upgrade work. The next mission's *return time* is pushed forward by the upgrade's build duration (typically 1–4 months in-fiction). Mechanically: Outfitting programs each agent's [Antikythera device](../Core-Setting/Antikythera-Device.md) with a return coordinate that lands them at base *after* the upgrade completes.
3. **Deploy normally.** Players run the next mission as usual. From their subjective experience, the mission feels normal — but when they drop home, more time has passed at base than they spent in the field.
4. **Return to a changed home.** The completed upgrade is online. Mechanical benefits apply immediately.

Time loss has real cost:
- Reality Log entries accumulate at base in their absence
- Other agents may have run operations during the gap, with consequences
- Personal relationships back home progress without the players
- EPOCH may have made moves that ATA absorbed without the team's involvement

### Parallel Builds

Recommended: **two concurrent build slots.** Players can launch two upgrades in parallel; the longer of the two sets the return-time push. A third upgrade is queued (waits for an existing slot to clear).

This forces strategic prioritization without making the system feel artificially constraining.

### Costs (recommended starting values — tune with playtesting)

| Tier change | TP cost | RU required? | Build duration |
|---|---|---|---|
| T1 → T2 | 5–8 TP | Usually no | 1–2 months |
| T2 → T3 | 12–20 TP | Usually yes | 3–6 months |

Some sectors are cheaper (residential) and some are dramatically more expensive (refinery, transit hub).

## Generic Tier Pattern

For most sectors, the three tiers map to historical recovery stages:

- **Tier 1 — Atlantean Baseline.** The original Bronze-Age facility, repaired and stabilized after the Disruption (~1200 BCE — see [../GM-Secrets/Atlantis-Fall.md](../GM-Secrets/Atlantis-Fall.md)). Functional, limited, period-flavored. Some quaint constraints (slow throughput, manual processes, period-style instrumentation).
- **Tier 2 — Industrial-Modern.** Rebuilt with 19th–20th century technology during ATA's recovery era. Bigger, faster, safer. The "default modern" version of the sector.
- **Tier 3 — ATA Modern.** Bleeding-edge ATA capability, often incorporating captured EPOCH biotech or recovered Bronze-era foundry techniques. Unlocks new capabilities, not just bigger numbers.

A few sectors break this pattern — e.g., the Reality Log Archive is more about retrieval and analysis than industrial scale, and the Commons is about morale rather than throughput. Per-sector specifics below.

## Inner Ring Tier Progressions

### I-1 Command Center

- **T1 — Single Watch Station.** One Chronograph operator at a time. Readings produce *only* Magnitude + Epicenter — Signature, Aftershocks, and Propagation Delay properties are noisy or absent. Mission briefings frequently leave the team underspecified.
- **T2 — Full Watch Floor.** Multi-operator analytical center. Readings produce all five properties from [Chronograph.md](../Core-Setting/Chronograph.md). Reliable mission specs.
- **T3 — Precog-Augmented Operations.** *Requires RU: Cumaean Cooperation.* The aged Cumaean precog (or successor) is integrated into the watch floor. Team gains *preempt* opportunities — occasional advance warning of EPOCH ripples before the Chronograph itself registers them. Mission types unlocked: **Preempt** (see Chronograph.md Mission Types table).

### I-2 Refinery

- **T1 — Atlantean Process.** Stone-and-bronze refining. Slow throughput. Produces basic refined fuel charges and Trace-grade orichalcum powder only. The agency runs in constant fuel scarcity.
- **T2 — Industrial Process.** Modern chemistry-based refining. Faster throughput, larger reserves, can produce Standard-grade powder. Fuel stops being the bottleneck on routine ops.
- **T3 — Reactor-Assisted.** *Requires RU: EPOCH Refinery Schematics.* Hybrid reactor with EPOCH-derived containment tech. Can produce Saturated-grade powder. Heavy-equipment boost transits become routine.

### I-3 Foundry

- **T1 — Recovered Bronze Tier.** Limited to Atlantean Mark I–II metal infusion (bronze, iron). Most modern weapons cannot be infused at all.
- **T2 — Modern Foundry (Mark III–IV).** Steel, alloy steels, titanium, basic composites. Standard ATA modern gear is producible. The baseline modern facility.
- **T3 — Composite Foundry (Mark V).** *Requires RU: either Atlantean Foundry Recipe (recovered from antiquity dig) or EPOCH Composite Sample (captured from operative).* Bio-compatible matrices, neural-interface alloys, ceramic-composite armor. Bleeding-edge ATA gear becomes available.

### I-4 Geothermal Plant

- **T1 — Atlantean Steam Loop.** Powers basic facility functions. Limited surplus. Distilled water output meets bare needs.
- **T2 — Modern Turbines + Desalination.** Full facility power with comfortable surplus. Surplus water exported to surface front operations.
- **T3 — Direct Meteor-Tap.** *Requires RU: Meteor Energy Harness Protocol (high-risk research arc).* Extracts energy directly from meteor radiance instead of via steam intermediary. Massive surplus. Enables high-energy operations: anchor-jamming arrays, large-scale transit hub operations, experimental dome-shielding fields. Risk: meteor behavior under direct extraction is *not modeled* — see [../GM-Secrets/](../GM-Secrets/).

### I-5 Reality Log Archive

- **T1 — Tablet & Scroll Library.** Atlantean inscription tablets plus paper records. Lookup is manual. Cross-referencing a complex ripple chain takes a research analyst days.
- **T2 — Indexed Modern Archive.** Card catalog + microfiche + early digital indexing. Lookup is fast; cross-referencing is reliable.
- **T3 — Searchable + Pattern-Detection.** Modern digital archive with ATA-built pattern-detection analytics. Instant retrieval; the system flags possible ripple correlations the analysts missed. *Detects EPOCH operational patterns the agency wouldn't otherwise see.*

The Reality Log is also the home of **Timeline Attention** — the running tally of how much the agency's own edits are drawing notice or accruing paradox pressure (see [Timeline-Model.md](../Core-Setting/Timeline-Model.md)), including the anachronistic goods produced via [Temporal-Production.md](Temporal-Production.md). Tier scales how well it's tracked: T1 notices only after the fact, T2 keeps a reliable ledger, and T3's pattern-detection *forecasts* attention spikes — flagging when a planned exploit is likely to cross a threshold before the team commits to it.

### I-6 Genetic Engineering Lab

The agency's bio-research hub. Runs the infusion protocol (the lab's most visible and politically important function — it is still the rate-limiting step on agency growth), plus EPOCH biotech sample analysis, captured myth-asset post-mortems, engineered psi induction for role-locked assets, recruit pre-screening, and the Bio-Anomaly Division.

- **T1 — Post-Fall Recovery Bench.** Infusion protocol only — ~6-month process, 70% washout rate, Standard saturation only. Recruitment is a permanent bottleneck. Other bio-research functions are essentially offline; recovered EPOCH biotech samples must be shipped to surface labs for analysis (slow, leaky, security-fraught).
- **T2 — Modern Bio-Research Wing.** Infusion: ~4-month process, 50% washout, Standard-to-high saturation reliably achievable. Plus full in-house EPOCH biotech sample analysis, captured myth-asset autopsy, recruit pre-screening labs, and basic engineered psi induction (high failure rate). **Prerequisite for most bio-related Research Upgrades to be applied** — see [RU Dependency Graph](#ru-dependency-graph) below.
- **T3 — EPOCH-Parity Genetics.** *Requires RU: EPOCH Genetic Screening Protocol.* Infusion: ~2-month process, 25% washout, Saturated-grade infusion routine. Engineered psi induction with reliable yield (Oracle Program can be reconstituted; Sphinx-tier assets become feasible). EPOCH biotech analysis at parity with EPOCH's own labs, two generations behind in raw technique but caught up in interpretation. Recruitment ceases to be a campaign-pacing bottleneck.

### I-7 Artifact Vault

- **T1 — Basic Secure Storage.** Limited capacity. Some artifacts cannot be safely housed (radiance leakage, unstable infusion). Storage incidents occasionally damage adjacent vaults.
- **T2 — Climate-Controlled & Shielded.** Comfortable capacity. Most artifacts safely storable. Periodic inspection cycles.
- **T3 — Active Containment.** *Requires RU: Per-Artifact Stabilization Fields.* Individual per-artifact containment fields. Even unstable artifacts (raw Philosopher's Stone fragments, live EPOCH bioweapons, paradox-generating items) can be held indefinitely without risk to facility.

The Vault also administers **temporal caches** — the secure past-era aging sites where [Temporal-Production.md](Temporal-Production.md) batches sit while they mature. Cache reliability scales with tier: T1 caches are improvised and occasionally *disturbed* (a lost or altered batch — a ready mission hook); T2 caches are catalogued and inspected; T3 extends per-artifact stabilization out to the off-site caches, making them dependable.

### I-8 Transit Hub

- **T1 — Single Chamber.** One transit operation at a time (boost OR drop). Re-charge cycle between transits is long. Team deployments are sequential — first the team boosts out, then later the extraction team boosts to follow, etc.
- **T2 — Three Chambers.** Parallel transit operations. Re-charge cycle shorter. Full teams can deploy/extract together.
- **T3 — Six Chambers + Anchor-Defense Array.** *Requires RU: Anchor-Jamming Technology.* Six concurrent transit channels. Plus an outbound anchor-jamming array that can disrupt EPOCH extraction attempts — captured EPOCH agents can be *prevented* from dropping home for the first time. This shifts the entire EPOCH-capture meta of the campaign.

## Outer Ring Tier Progressions

### O-1 Surface Access & Docks

- **T1 — Single Airlock + Period Boats.** Surface operations are slow and risky. Small fleet of unobtrusive boats. Submarine access limited.
- **T2 — Multi-Airlock + Modern Submarine Pen.** Quick surface operations. Modern subs available for clandestine transport.
- **T3 — Stealth Docks + Acoustic Countermeasures.** *Requires RU: Captured EPOCH Stealth Tech.* Nearly undetectable surface operations. The facility becomes essentially invisible to all surface ASW capability.

### O-2 Residential — North (Multi-Generational)

- **T1 — Cramped Family Quarters.** High attrition. Families leave the facility within years. Agent loyalty suffers.
- **T2 — Comfortable Apartments.** Family-friendly amenities. Lower attrition. Multi-generational families become viable.
- **T3 — Luxury w/ Psi-Shielded Sleep.** *Requires RU: Psi-Shielded Architecture.* Private gardens (hydroponic), psi-shielded sleeping spaces. Children raised here develop better — those born to two infused parents have measurably higher latent-psi rates *and* tolerate infusion with much lower washout when they enlist.

### O-3 Factory

- **T1 — Atlantean Crafting.** Hand-forged gear from Foundry output. Slow production. Limited inventory keeps the agency operating just-in-time.
- **T2 — Modern Manufacturing.** Full production lines. Standard ATA equipment in stock at all times. Custom orders for special missions feasible.
- **T3 — EPOCH-Replication Capability.** *Requires RU: any reverse-engineered EPOCH artifact.* Can replicate captured EPOCH gear (one design per RU spent). Each replicated design opens a new branch of gear capability — and changes ATA's strategic relationship with EPOCH (the asymmetry shrinks).

### O-4 Farm & Agri-Tech

- **T1 — Basic Hydroponic.** Standard crops. Infusion-supplement cultivars exist but are inefficient (high-volume consumption needed during infusion protocol).
- **T2 — Multi-Tier + Aquaculture.** Efficient supplement cultivars. Full food autonomy. Agents in training need less supplement volume.
- **T3 — Programmed Bio-Reactor.** *Requires RU: Targeted Crop Genetics. Also requires I-6 Genetics Lab at T2+ to develop crop strains.* Specialized agent nutrition programs — strains tailored for specific operational needs (e.g., crops that boost short-term psi sensitivity, crops that accelerate post-mission recovery, crops that accelerate active infusion in late-stage recruits).

### O-5 Commons

- **T1 — Single Canteen + Bare Pub.** Limited recreation. Off-shift social life thin. Morale baseline is *low* — small but persistent debuff.
- **T2 — Multiple Restaurants + Gym + Theater.** Off-shift social life normal. Morale baseline is *neutral*. The gym + theater here absorb light combat-sim and recreation functions from the eliminated Training sector.
- **T3 — Recreation Floor + Therapy Suites.** Arcade, virtual environments, professional therapy. Morale baseline is *positive* — small but persistent buff to all mission rolls (clear-headed agents perform better).

### O-6 Medical Center

Clinical counterpart to the Genetics Lab. Trauma care, surgery, ICU, post-mission recovery wards, cellular regeneration suites, psi-medicine. Also houses the physical conditioning and combat-rehab programs that used to live in the dedicated Training sector — the medical staff supervise both.

- **T1 — Field Clinic.** Trauma care, infection control, surgical capability for routine mission injuries. Period-appropriate equipment retrofitted to modern standards. Serious wounds put a PC out for *weeks of in-fiction down-time* — mission cadence suffers.
- **T2 — Modern Hospital.** Full surgical suites, ICU, post-mission recovery wards. Bone and tissue regeneration available. Cuts down-time meaningfully — most mission injuries heal between sessions instead of bleeding into them.
- **T3 — Augmented Recovery + Psi-Med.** *Requires RU: Cellular Regeneration Protocol (from Grail Quest arc).* Cellular-regen baths reverse-engineered from the Grail. Psi-medicine for combat trauma psychology. Agents who would have been benched for months are deployable in days. Direct mission-cadence buff — the team can run consecutive heavy missions without forced pauses.

### O-7 Museum & Library

Houses the era-immersion language and tradecraft training programs that used to live in the dedicated Training sector — surrounded by primary-source material, the natural home for them.

- **T1 — Modest Collection + Reference Library.** Limited loan system. Reference library has gaps. Mission research is slow. Era-immersion language training is book-and-tutor.
- **T2 — Curated Collection + Comprehensive Library.** Structured loan system. Agents can check out historical artifacts for missions (cover provenance, era-appropriate currency, props). Era-immersion language training accelerated (VR-style + native-speaker simulations).
- **T3 — Simulation Chambers.** *Requires RU: Holographic Mission Rehearsal System.* Period-accurate environment simulation chambers built from museum artifact provenance. Teams can rehearse insertions in reconstructions of their actual target era before going. Holographic adversarial AI trained on captured EPOCH operational patterns. *Major mission-prep buff* — pre-mission Sim training adds a meaningful modifier to insertion-phase and reaction rolls.

### O-8 Residential — South (Transient Agent Bunks)

- **T1 — Bunkhouse.** Minimal privacy. Transient stress accumulates. Agents arrive for missions already fatigued.
- **T2 — Private Rooms.** Shared facilities, private sleep. Better rest = better mission performance (small but real bonus on first-mission rolls).
- **T3 — Premium Quarters.** Private suites with personalized amenities, post-mission decompression rooms, sound-isolated sleeping spaces. Morale and rest buffs stack with O-5 T3. No RU requirement — this is a TP-only sink, suitable for late-game completionists or campaigns where the PCs grow attached to their bunks.

## Research Upgrades (Examples)

RU drops are arc-specific. The list below shows what kinds of RU exist and what they unlock.

| RU | Source (typical) | Unlocks |
|---|---|---|
| **Cumaean Cooperation** | ATA Reality Analysis arc | Command Center T3 |
| **EPOCH Refinery Schematics** | Captured from EPOCH facility raid | Refinery T3 |
| **Atlantean Foundry Recipe** | Recovered from antiquity archaeological dig | Foundry T3 (Atlantean branch) |
| **EPOCH Composite Sample** | Captured from EPOCH operative | Foundry T3 (EPOCH branch) — *requires Lab T2+ to analyze biotech component* |
| **Meteor Energy Harness Protocol** | Long, dangerous research arc | Geothermal T3 |
| **Per-Artifact Stabilization Fields** | Vault-specialist research arc | Vault T3 |
| **Anchor-Jamming Technology** | Reverse-engineered from captured EPOCH gear | Transit Hub T3 |
| **EPOCH Genetic Screening Protocol** | Captured EPOCH medical archive | Genetics Lab T3 |
| **Captured EPOCH Stealth Tech** | Specific EPOCH equipment recovery | Surface Access T3 |
| **Psi-Shielded Architecture** | Psi-research arc | Residential North T3 |
| **Cellular Regeneration Protocol** | Grail Quest arc (canonical artifact recovery) | Medical Center T3 — *requires Lab T2+ to reverse-engineer regen tech* |
| **Targeted Crop Genetics** | Modern biotech research arc | Farm T3 — *requires Lab T2+ to develop strains* |
| **Holographic Mission Rehearsal System** | Modern engineering research arc | Museum T3 |
| **Reverse-Engineered EPOCH Artifact** | Each captured EPOCH design | One Factory T3 replication branch |
| **Object Return-Anchoring** | Antikythera R&D arc | Unlocks [Temporal Production](Temporal-Production.md) — the cross-sector capability to send objects/processes downstream and retrieve them matured (a capability unlock, not a single sector's T3) |

Designed so that *most* T3 upgrades require players to deliberately pursue an RU arc — making the macro-progression deeply tied to mission choices rather than just TP accumulation.

### RU Dependency Graph

The Genetics Lab (I-6) is the prerequisite hub for most bio-related Research Upgrades. Even when an RU is *acquired* from a mission arc (e.g., the Grail Quest yielding Cellular Regeneration Protocol), the agency cannot *apply* the RU without a functional research wing to reverse-engineer it. This forces strategic prioritization of Lab upgrades early in the campaign.

Bio-related RUs requiring Lab T2+ to apply:

- **Cellular Regeneration Protocol** → Medical Center T3
- **Targeted Crop Genetics** → Farm T3
- **EPOCH Composite Sample** → Foundry T3 (EPOCH branch) — the biotech-carrier component, not the metallurgy
- **EPOCH Genetic Screening Protocol** → Genetics Lab T3 itself (recursive — needs Lab T2 to be analyzed, then unlocks Lab T3; this is the gate's intended shape)

Non-bio RUs that do *not* require the Lab include all metallurgical, computational, fuel-handling, and operational-tactics RUs. The Lab is a bio bottleneck, not a universal one.

## Cost Tuning Suggestions

Default values for a campaign expected to run ~20–30 sessions before reaching mid-late game:

| Sector category | T1 → T2 | T2 → T3 |
|---|---|---|
| **High-impact infrastructure** (Refinery, Foundry, Transit Hub, Genetics Lab, Medical Center) | 8 TP, 2 months | 20 TP + RU, 6 months |
| **Standard infrastructure** (Command, Reality Log, Vault, Geothermal, Factory) | 6 TP, 1.5 months | 15 TP + RU, 4 months |
| **Soft infrastructure** (Residential, Commons, Farm, Museum, Surface Access) | 4 TP, 1 month | 10 TP + RU (often), 3 months |

**TP earnings per session** (recommended): 1–3 TP for normal mission; +1 per minor artifact recovered; +2–5 per major artifact; +1 for decoy detection; +2 for tactical-defeat-strategic-win outcomes.

So a 25-session campaign at ~2 TP/session = ~50 TP total. That's enough for roughly 4–5 sector upgrades across the campaign — meaningful but constrained. Players cannot upgrade everything; they must choose.

## Display Suggestion

Maintain a one-page **Base Status Sheet** the GM updates between sessions:

```
ATLANTIS FACILITY STATUS
========================
Tech Points: 12  |  Build Slots Used: 1/2

INNER RING
  I-1 Command Center        [T2]  Full Watch Floor
  I-2 Refinery              [T1]  Atlantean Process
  I-3 Foundry               [T2]  Modern Foundry (III–IV)
  I-4 Geothermal Plant      [T1]  Atlantean Steam Loop
  I-5 Reality Log Archive   [T2]  Indexed Modern Archive
  I-6 Genetics Lab          [T1]  Post-Fall Recovery Bench  ⚙ UPGRADING T2 (3 weeks remain)
  I-7 Artifact Vault        [T1]  Basic Secure Storage
  I-8 Transit Hub           [T2]  Three Chambers

OUTER RING
  O-1 Surface Access        [T1]  Single Airlock
  O-2 Residential — N       [T2]  Comfortable Apartments
  O-3 Factory               [T2]  Modern Manufacturing
  O-4 Farm & Agri-Tech      [T2]  Multi-Tier + Aquaculture
  O-5 Commons               [T1]  Single Canteen + Bare Pub
  O-6 Medical Center        [T1]  Field Clinic
  O-7 Museum & Library      [T2]  Curated Collection
  O-8 Residential — S       [T1]  Bunkhouse

RESEARCH UPGRADES OWNED
  ✓ Cumaean Cooperation       (unused — unlocks I-1 T3)
  ✓ EPOCH Genetic Screening   (held — will apply to I-6 once T2 complete)
```

This sheet IS the player-facing macro-progression interface. Hand it to them, let them plan.

## Open Questions

- **Tier 4?** User decision was 3 tiers. Late-campaign material could introduce a hypothetical T4 ("Atlantean Restoration" — recovering pre-Disruption Bronze-era capability that even modern ATA doesn't have), but might be over-design. Hold for now.
- **Downgrade risk.** Can a sector be *damaged* and lose a tier? E.g., EPOCH sabotage of the Refinery during a major arc could knock it from T3 → T2 temporarily. Adds drama but also subtraction-without-fault-of-PCs frustration. Maybe sparingly.
- **Cross-sector dependencies.** Should some tier-ups require *other* sectors to also be at a certain tier? (E.g., Factory T3 requires Foundry T3 because you can't manufacture what you can't infuse.) Adds depth but adds bookkeeping.
- **PC personal-quarter upgrades.** Should PCs get to upgrade *their own quarters* in O-2 or O-3 as a personal investment? Cosmetic + small personal-buff like Residential T3 effect.
- **Negative-TP debt?** Can the team take an *advance* against future TP to launch an urgent upgrade? Adds strategic risk-taking but complicates accounting.
- **EPOCH base upgrades.** Symmetric problem — does EPOCH's Shambhala also have a tier curve? If yes, do players ever *see* it shift mid-campaign (e.g., "EPOCH's foundry just went to Mark VII — captured gear is now even more advanced")?
- **Build duration vs. real-world session pacing.** A 6-month in-fiction build is one session of return-time push. Does this *feel* heavy enough to be a real cost? Tune with playtesting.

