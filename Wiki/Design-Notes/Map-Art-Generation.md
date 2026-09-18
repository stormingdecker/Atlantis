# Map-Art Generation — the Prompt Recipe

How we generate VTT map art for the campaign, distilled from the Carpathian and Fátima builds (2026-07). Use these templates and you get app-ready tiles on the first try instead of fighting the model.

**Tool:** the `generate-image` skill — Gemini 3 Pro Image ("Nano Banana Pro"). Run from `~/fbsource`:
```
buck2 run fbcode//claude-templates/components/skills/generate-image/scripts:generate_image -- \
  --prompt "<prompt>" --aspect-ratio 16:9 --quality 2K --output /tmp/tile.png
```
`--input-images IMG` edits/relights an existing image (used for lighting-variant pairs).

## The one principle

**The art is terrain; the app owns everything else.** The map holds ground, cover, and dressing. The *grid, compass, scale bar, and dynamic lighting/particles are drawn by the app at runtime.* So every play-surface prompt ends by forbidding baked overlays. (This reverses our earlier convention — do **not** ask the generator to bake in a grid or compass anymore.)

## Two output classes

| Class | Angle | Overlays | Use |
|---|---|---|---|
| **Play surface** | true top-down (flat) | none baked (app draws hexes) | miniatures on the projector |
| **Briefing map** | oblique cinematic *or* parchment | compass/scale/labels welcome | the GM/briefing screen, handouts |

Nano's *default* cinematic ¾-aerial makes gorgeous **briefing** art but unusable **play** surfaces — so we deliberately generate both and keep the oblique one as `*_briefing.png`.

## Reusable clauses (paste into prompts)

- **STYLE (play surfaces — grounded/photoreal, 2026-07-20):** `Photorealistic top-down tabletop battle map in a grounded, naturalistic style — realistic physically-based materials and textures (true sand, stone, timber, cloth, water), soft even overhead daylight, gritty and cinematic but restrained. NOT cartoonish, NO thick ink outlines, NO cel shading, NO stylized illustration.` *(This replaces the earlier "Mike Schley / WotC" clause, which read too cartoony. Briefing maps still use the parchment/painterly look below — they're handouts, not play surfaces.)*
- **FLAT** (every play surface): `seen from DIRECTLY overhead at a perfect 90-degree bird's-eye top-down angle like a satellite or orthophoto — absolutely NO perspective, NO horizon, NO visible sides or facades, only the tops of things visible, everything flattened onto the ground plane so miniatures can stand on it.`
- **FILL:** `wide 16:9 framing filling the whole frame edge to edge.`
- **NOUI** (every play surface — strengthened): `absolutely NO grid, NO grid lines, NO hexes, NO compass rose, NO scale bar, NO legend, NO border or frame, NO text, NO numbers, NO labels, NO icons, NO watermark, NO UI of any kind — pure photographic terrain only.`
- **CLARITY:** `walkable surfaces kept smooth and muted so miniatures read clearly; reduced detail in open zones.`

## Templates

### A — Open natural terrain (caves, deserts, wilderness)
The easy case; Nano stays top-down when there's mostly floor.
> {STYLE} {FLAT} {FILL} <describe the terrain, cover as silhouettes, a couple of landmarks, palette, "baked lighting from the upper-left (NW)">. {CLARITY} {NOUI}

### B — Populated / crowd field
The trick: describe people **from directly above** so the model draws tops, not standing figures.
> {STYLE} {FLAT} {FILL} <the ground>. Crowds seen from straight above as **a dense pattern of round umbrella-tops and hatted heads**, packed around the edges, leaving the center open for miniatures. <landmarks: a tree as a round canopy, a wall as a grey band, cart-tops/tent-tops>. {CLARITY} {NOUI}

### C — Interior building (the roofs-off floor plan)
Never accept roof-tops for a building you fight in.
> Top-down tabletop RPG battle map of <building>, {FLAT} The **ROOFS ARE REMOVED so you see INTO the rooms from above** — a cutaway floor plan in the Mike Schley dungeon-map style: interior walls, floors, and furniture revealed from directly overhead. <rooms + furniture + yard/outbuildings>. {CLARITY} {NOUI}

### D — Briefing map (choose one flavor)
Overlays are *fine* here.
- *Parchment:* `Top-down hand-painted parchment cartography map, fantasy TTRPG mission-briefing style, north-up. <region + pictograph markers + a dashed red route>. Painted gold-leaf compass rose top-left, scale bar bottom-right, weathered burnt edges, hand-lettered title "<title>". Muted watercolor palette.`
- *Cinematic:* just run the Template-A/B/C content **without** {FLAT}/{NOUI} — Nano's default ¾-aerial is the briefing art.

### E — Lighting / state variant (relight, don't regenerate)
Keeps the layout identical across a lit/dark or overcast/miracle pair.
> `--input-images <base.png>` + `Relight this exact scene as <new state>. Keep the identical layout — <list the fixed features> — completely unchanged and still seen from directly overhead. Now <describe the new light>. No grid, no compass, no scale bar, no text.`

### E2 — Repaint a placeholder while PRESERVING layout (for overlay-aligned maps)
When a map has app overlays authored to its pixel layout (sector polygons, hex origin), a fresh generation desyncs them. Instead repaint the existing tile: feed it as `--input-images` and **match its aspect ratio** (e.g. `--aspect-ratio 1:1` for a square base — a default 16:9 reframe would shift everything).
> `--input-images <placeholder.png>` + `Repaint this exact schematic as <beautiful version>, seen from directly overhead. CRITICAL: keep the identical layout — <rings/wedges/core/dividers> — at their exact current positions, sizes and proportions. Transform <flat shapes> into <painterly content>. {NOUI}`
Nano may still re-subdivide fine internal detail, so verify the overlay still lands (stage it, screenshot). Used to turn the flat Atlantis facility schematic into the painterly underwater base with the 16 sector polygons still aligned.

### F — Particle sprite (Nano can't emit alpha)
Generate on flat chroma-green, then key it:
> `<subject>, soft painterly, centered and isolated on a solid flat uniform bright chroma-key green background (pure RGB 0,255,0, completely flat, no gradient, no pattern, no checkerboard), no shadow. The <subject> contains no green.`
```
ffmpeg -y -i in.png -vf "chromakey=0x00FF00:0.32:0.12,despill=type=green,format=rgba,crop=..." out.png
# pad with a transparent margin so it doesn't clip as a square:
ffmpeg -y -i keyed.png -vf "pad=900:900:(ow-iw)/2:(oh-ih)/2:color=0x00000000,format=rgba" sprite.png
```
Use art sprites for **shaped/large** particles (leaves, snowflakes); use a **procedural additive soft-dot** (in `projector.gd`) for small glowy motes (dust, embers) — cleaner, and it actually glows.

## Gotchas

- **Perspective drift** on buildings/crowds even with "90° orthographic" — that's what the FLAT clause is for.
- **Sunken features (pits, trenches, dig cuttings) drift to oblique** — the depth tempts Nano into an isometric 3D view with visible walls. Beat it the Template-C way: "you look STRAIGHT DOWN INTO the <pit>; it reads as a shallow sunken area with only a thin dark rim, NO visible walls or sides, only the flat floor from overhead." (Tarim excavation needed this; first pass came back beautifully isometric but unusable as a play surface — great as a briefing though.)
- **No true alpha** from Nano (it paints a checkerboard) — always chroma-key.
- **No PIL / ImageMagick** on this box and **pip is blocked** — resize/pad/key with **ffmpeg**.
- **2752×1536** is the native 16:9 @2K size; full-res is fine for the app (Godot handles it).

## Backdrops (filling 16:9 behind a non-16:9 map)
A square/circular map (e.g. the round Atlantis city) leaves bars when projected 16:9. Instead of black bars, give the sidecar a `backdrop` (a full 16:9 environment tile — seabed, crater rim, etc.) and a `map_fit` (0..1) that shrinks the map so it nestles inside the backdrop. The app draws the backdrop cover-filled behind the map; sector polygons scale WITH the map sprite, so they stay aligned. Crop the map to its silhouette (circle) via ffmpeg `geq` alpha so the backdrop shows around it. Tune `map_fit` by screenshot until the map sits inside the backdrop's framing (crater rim). See `atlantis.json` (`backdrop`, `map_fit`).

## Wiring & clips
App tiles → `VTT/assets/maps/`; the campaign JSON tree carries per-map `image`, `hex_grid`, `time_of_day`, `season`, `effects`, `lights`, `music` (see [Base-Upgrades](Base-Upgrades.md)-adjacent app docs). Short motion clips (particles/flicker/lighting) via `VTT/tools/iterate.sh movie <label> <stage>` (deterministic `--fixed-fps` capture → ffmpeg mp4).

See the [Missions Overview VTT conventions](../Missions/Overview.md#vtt-map-conventions) for the play-surface spec this recipe feeds.
