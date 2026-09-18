#!/bin/bash
# remap_all.sh — repaint every existing play-surface map in the photoreal style,
# preserving layout via --input-images. Archives originals to maps/_archive/cartoony/.
# Sequential (buck2 contention). Run backgrounded; poll /tmp/remap.log.
set -uo pipefail
MAPS="$HOME/gdrive/Atlantis/VTT/assets/maps"
BACK="$HOME/gdrive/Atlantis/VTT/assets/backdrops"
ARCH="$MAPS/_archive/cartoony"; mkdir -p "$ARCH"
GEN() { cd "$HOME/fbsource" && timeout 260 buck2 run fbcode//claude-templates/components/skills/generate-image/scripts:generate_image -- "$@" >/dev/null 2>&1; }

REPAINT="Re-render this exact top-down tabletop battle map in a photorealistic, grounded, naturalistic style — realistic physically-based materials and textures, soft even overhead daylight, gritty but restrained. NOT cartoonish, NO ink outlines, NO cel shading, NO stylized illustration. Keep the EXACT same top-down layout, contents and composition — every feature in the same place, still seen from directly overhead with no perspective, everything flat so miniatures can stand on it. Absolutely NO grid, NO hexes, NO compass, NO scale bar, NO border, NO text, NO labels, NO icons, NO watermark, NO UI — pure photographic terrain only."

# 1) Uniform photoreal repaints (file|aspect). Archive original, repaint from archive → overwrite.
for entry in \
  "cache_approach.png|16:9" "cache_chamber.png|16:9" "cache_den.png|16:9" \
  "fatima_cova.png|16:9" "fatima_ridge.png|16:9" \
  "harbin_rendezvous.png|16:9" "harbin_epoch_site.png|16:9" \
  "knossos.png|1:1" "labyrinth.png|1:1"; do
  f="${entry%|*}"; ar="${entry#*|}"; src="$MAPS/$f"
  [ -f "$src" ] || { echo "[remap] MISSING $f"; continue; }
  cp "$src" "$ARCH/$f"
  echo "[remap] $f ($ar)..."
  GEN --input-images "$ARCH/$f" --prompt "$REPAINT" --aspect-ratio "$ar" --quality 2K --output "$src"
  echo "[remap] $f $([ -f "$src" ] && echo OK || echo FAIL)"
done

# 2) Relights derived from the NEW photoreal bases (keep matched pairs matched).
cp "$MAPS/cache_den_dark.png" "$ARCH/cache_den_dark.png" 2>/dev/null
echo "[remap] cache_den_dark (relight)..."
GEN --input-images "$MAPS/cache_den.png" --aspect-ratio 16:9 --quality 2K --output "$MAPS/cache_den_dark.png" \
  --prompt "Relight this exact photorealistic top-down scene as a dark, lamps-out infiltration. Keep the identical layout and contents, still seen from directly overhead. Deep shadow, dim cold light, a single small warm lantern pool. Photorealistic, naturalistic, not cartoonish. No grid, no compass, no text, no UI."
echo "[remap] cache_den_dark done"

cp "$MAPS/fatima_cova_storm.png" "$ARCH/fatima_cova_storm.png" 2>/dev/null
echo "[remap] fatima_cova_storm (relight)..."
GEN --input-images "$MAPS/fatima_cova.png" --aspect-ratio 16:9 --quality 2K --output "$MAPS/fatima_cova_storm.png" \
  --prompt "Relight this exact photorealistic top-down scene as the Miracle of the Sun. Keep the identical layout and contents (the crowd, the hollow), still seen from directly overhead. Now flooded with intense golden-white radiance from above, dramatic warm light breaking through overcast, long shadows across the ground. Photorealistic, naturalistic, not cartoonish. No grid, no compass, no text, no UI."
echo "[remap] fatima_cova_storm done"

# 3) Atlantis — special: repaint the SQUARE underwater source (preserves ring/sector layout),
#    re-crop to a circle, and repaint the seabed backdrop. Old atlantis.png/backdrop archived.
SQ="$MAPS/_archive/atlantis_underwater_square.png"
if [ -f "$SQ" ]; then
  echo "[remap] atlantis city (square repaint)..."
  GEN --input-images "$SQ" --aspect-ratio 1:1 --quality 2K --output /tmp/atlantis_sq_real.png \
    --prompt "$REPAINT Underwater Atlantean facility: keep the identical ring layout, the same central reactor core, the same two concentric rings of wedge modules, the same radial corridors and ring gap, all at their exact current positions and proportions. Deep-sea, photorealistic materials, glowing core, bioluminescent accents. Seen from directly overhead."
  if [ -f /tmp/atlantis_sq_real.png ]; then
    cp "$MAPS/atlantis.png" "$ARCH/atlantis.png"
    ffmpeg -y -i /tmp/atlantis_sq_real.png -vf "format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='clip((1024-hypot(X-1024\,Y-1024))/20*255,0,255)'" "$MAPS/atlantis.png" >/dev/null 2>&1
    echo "[remap] atlantis city re-cropped to circle $([ -f "$MAPS/atlantis.png" ] && echo OK)"
  else echo "[remap] atlantis city FAIL"; fi
else echo "[remap] atlantis square source missing, skipping city"; fi

echo "[remap] atlantis backdrop..."
cp "$BACK/atlantis_backdrop.png" "$ARCH/atlantis_backdrop.png" 2>/dev/null
GEN --input-images "$ARCH/atlantis_backdrop.png" --prompt "$REPAINT Deep-sea abyssal floor with a central rocky crater rim, shipwreck, kelp and coral. Keep the identical layout." --aspect-ratio 16:9 --quality 2K --output "$BACK/atlantis_backdrop.png"
echo "[remap] atlantis backdrop done"

echo "REMAP_ALL COMPLETE"
