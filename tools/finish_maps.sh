#!/bin/bash
# finish_maps.sh — complete the 3 maps left unfinished by the 2026-07-20 image-gen
# outage: the two relights + the Atlantis city (+ its backdrop). Run once gen is back.
set -uo pipefail
MAPS="$HOME/gdrive/Atlantis/VTT/assets/maps"
BACK="$HOME/gdrive/Atlantis/VTT/assets/backdrops"
ARCH="$MAPS/_archive/cartoony"; mkdir -p "$ARCH"
# Optional model override: export GENMODEL=<name> if the default preview model was
# renamed at GA (heartbeat detects this and passes the live image model through).
GEN() { cd "$HOME/fbsource" && timeout 260 buck2 run fbcode//claude-templates/components/skills/generate-image/scripts:generate_image -- ${GENMODEL:+--model "$GENMODEL"} "$@" >/dev/null 2>&1; }
REPAINT="Re-render this exact top-down tabletop battle map in a photorealistic, grounded, naturalistic style — realistic physically-based materials and textures, soft even overhead daylight, gritty but restrained. NOT cartoonish, NO ink outlines, NO cel shading. Keep the EXACT same top-down layout and contents, seen from directly overhead, flat for miniatures. Absolutely NO grid, NO compass, NO scale bar, NO border, NO text, NO labels, NO UI — pure photographic terrain only."

# 1) cache_den_dark — relight of the new photoreal cache_den
[ -f "$ARCH/cache_den_dark.png" ] || cp "$MAPS/cache_den_dark.png" "$ARCH/cache_den_dark.png"
GEN --input-images "$MAPS/cache_den.png" --aspect-ratio 16:9 --quality 2K --output "$MAPS/cache_den_dark.png" \
  --prompt "Relight this exact photorealistic top-down scene as a dark, lamps-out infiltration. Keep the identical layout and contents, seen from directly overhead. Deep shadow, dim cold light, a single small warm lantern pool. Photorealistic, not cartoonish. No grid, no compass, no text, no UI."
echo "cache_den_dark $([ "$MAPS/cache_den_dark.png" -nt "$ARCH/cache_den_dark.png" ] && echo OK || echo CHECK)"

# 2) fatima_cova_storm — Miracle relight of the new photoreal fatima_cova
[ -f "$ARCH/fatima_cova_storm.png" ] || cp "$MAPS/fatima_cova_storm.png" "$ARCH/fatima_cova_storm.png"
GEN --input-images "$MAPS/fatima_cova.png" --aspect-ratio 16:9 --quality 2K --output "$MAPS/fatima_cova_storm.png" \
  --prompt "Relight this exact photorealistic top-down scene as the Miracle of the Sun. Keep the identical layout and contents (the crowd, the muddy hollow), seen from directly overhead. Now flooded with intense golden-white radiance from above, dramatic warm light breaking through overcast, long shadows. Photorealistic, not cartoonish. No grid, no compass, no text, no UI."
echo "fatima_cova_storm $([ "$MAPS/fatima_cova_storm.png" -nt "$ARCH/fatima_cova_storm.png" ] && echo OK || echo CHECK)"

# 3) Atlantis city (repaint square source, preserve rings) -> re-crop to circle; + backdrop
GEN --input-images "$MAPS/_archive/atlantis_underwater_square.png" --aspect-ratio 1:1 --quality 2K --output /tmp/atlantis_sq_real.png \
  --prompt "$REPAINT Underwater Atlantean facility: keep the IDENTICAL ring layout — the same central reactor core, the same two concentric rings of wedge modules, the same radial corridors and ring gap, at their exact positions and proportions. Deep-sea photorealistic materials, glowing molten core, bioluminescent accents, seen from directly overhead."
if [ -f /tmp/atlantis_sq_real.png ]; then
  [ -f "$ARCH/atlantis.png" ] || cp "$MAPS/atlantis.png" "$ARCH/atlantis.png"
  ffmpeg -y -i /tmp/atlantis_sq_real.png -vf "format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='clip((1024-hypot(X-1024\,Y-1024))/20*255,0,255)'" "$MAPS/atlantis.png" >/dev/null 2>&1
  echo "atlantis city OK (re-cropped)"
else echo "atlantis city CHECK (gen failed)"; fi
GEN --input-images "$ARCH/atlantis_backdrop.png" --aspect-ratio 16:9 --quality 2K --output "$BACK/atlantis_backdrop.png" \
  --prompt "$REPAINT Deep-sea abyssal floor with a central rocky crater rim, a shipwreck, kelp and coral. Keep the identical layout."
echo "atlantis backdrop done"
echo "FINISH_MAPS COMPLETE"
