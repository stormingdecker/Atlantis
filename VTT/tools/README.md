# Tools

Developer scripts for the Atlantis VTT. These are NOT part of the running app — they generate test content and (later) build/export helpers.

## Generators

### `generate_test_maps.py`

Writes 6 placeholder maps into `../assets/maps/`. Each map exercises a different aspect ratio, palette, or layout so the VTT's fit-to-viewport, crossfade, and hex-overlay logic can be tested without waiting for AI-generated art.

```
pip install Pillow
python tools/generate_test_maps.py
```

Output:
- `map_01_grassland.png` — 1920×1080, green gradient
- `map_02_dungeon.png` — 1920×1080, dark with room rectangles
- `map_03_coast.png` — 2560×1440, water-to-sand gradient (widescreen)
- `map_04_temple.png` — 1080×1920, portrait with column pillars
- `map_05_starfield.png` — 1920×1080, scattered stars on black
- `map_06_blueprint.png` — 1920×1080, blueprint cyan with grid

All maps include a hex grid baked in, a compass, and a centered label.

### `generate_test_audio.py`

Writes 2 music drones and 2 SFX clips into `../assets/audio/`. Pure stdlib — no extra dependencies.

```
python tools/generate_test_audio.py
```

Output:
- `music/music_01_drone_low.wav` — 18 s A2 drone, loop-friendly
- `music/music_02_drone_mid.wav` — 18 s A3 drone, loop-friendly
- `sfx/sfx_01_beep.wav` — 0.25 s 880 Hz beep
- `sfx/sfx_02_chime.wav` — 1.2 s C major triad chime

Different pitches make the source obvious to the ear during testing.

## Replacing test content with real assets

The placeholders are just for verifying the VTT works. Once we're confident in the engine, swap in real assets:
- Generate real top-down play-surface maps using the prompts in `../../Wiki/Missions/` (Howland v0.1 is fully prompted).
- Source music from Kevin MacLeod / Pixabay / Freesound (verify licenses).
- Source SFX from Freesound or commission.
