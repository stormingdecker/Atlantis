# Asset Organization

Where things live in the `Atlantis/` project, and the one rule that keeps it clean: **durable authored assets never live in `captures/`.**

## The four roots

| Root | What | Loaded by the app? |
|---|---|---|
| **`VTT/assets/`** | The Godot app's asset tree — `maps/` (play tiles + `_briefing` maps), `backdrops/`, `audio/` (music, sfx, `ambience/`), `campaigns/` (the mission JSON tree), `handouts/`, `particles/`, and the `*.json` configs (`wled`, `hue`, `lighting`). | **Yes** — `res://assets/...` |
| **`assets/`** | Durable authored campaign assets *not* loaded by the app — print/handout material. `equipment/` (per-pack `card_*.png` + `art_*.png` + shared `card_bg.png`), `voices/` (TTS lines). | No |
| **`tools/`** | Scripts + their inputs — `make_card.sh`, `gen_pack.sh`, `iterate.sh`, `packs/*.txt` manifests, `build_site.py` lives at repo root. | No |
| **`captures/`** | **Ephemeral only** — iterate-harness screenshots (`*_gm.png` / `*_projector.png`), movie `*.mp4`, `clips/`, per-mission capture-frame dirs. Safe to delete anytime. | No |

Plus **`Wiki/`** (the campaign wiki source; `build_site.py` → `Wiki-Site/`) and **`_archive/`** subfolders for superseded originals (e.g. `VTT/assets/maps/_archive/cartoony/`).

## The rule

- **Authoring an asset you'll keep?** → `assets/` (handout art, cards, voice lines) or `VTT/assets/` (anything the Godot app loads).
- **A screenshot, render, or clip from the harness?** → `captures/`. Treat it as disposable.

This split was made 2026-07-20 — the equipment card decks (~700 MB) had accumulated in `captures/equipment/` alongside screenshots; they now live in `assets/equipment/`, and the tooling (`gen_pack.sh`, `make_card.sh`) writes there.

## Pointers

- Maps & tiles pipeline → [Map-Art-Generation.md](Map-Art-Generation.md)
- Equipment cards → [Period-Equipment.md](Period-Equipment.md) (`assets/equipment/`)
- App content wiring (campaign→mission→area→map JSON) → [Map-Art-Generation.md](Map-Art-Generation.md#wiring--clips)
