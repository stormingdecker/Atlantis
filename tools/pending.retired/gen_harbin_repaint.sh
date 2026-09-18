#!/bin/bash
# The layout pass came back cel-shaded with heavy ink outlines — right plan,
# wrong style next to harbin_rendezvous.png. Repaint it photoreal (the
# finish_maps.sh REPAINT pattern), then re-derive the after-hours relight from
# the repainted plate so the two layers match.
set -uo pipefail
while pgrep -f "gen_harbin.sh|gen_harbin_extraction.sh" >/dev/null; do sleep 20; done
MAPS="$HOME/gdrive/Atlantis/VTT/assets/maps"
GEN() {
  local try
  for try in 1 2 3 4 5 6; do
    ( cd "$HOME/fbsource-atlantis" && timeout 300 buck2 run \
      fbcode//claude-templates/components/skills/generate-image/scripts:generate_image -- "$@" ) && return 0
    echo "[gen] attempt $try failed; sleeping $((try*45))s"
    sleep $((try*45))
  done
  return 1
}

REPAINT="Re-render this exact top-down tabletop battle map in a photorealistic, grounded, naturalistic style — realistic physically-based materials and textures, gritty but restrained. NOT cartoonish, NO ink outlines, NO cel shading, NO comic-book linework. Keep the EXACT same top-down layout, contents and positions, seen from directly overhead, flat for miniatures, filling the whole 16:9 frame. Absolutely NO grid, NO compass, NO scale bar, NO border, NO text, NO labels, NO UI — pure photographic terrain only."

echo "=== repaint guarded ==="
GEN --input-images /tmp/harbin_epoch_site.png --aspect-ratio 16:9 --quality 2K \
  --output /tmp/harbin_epoch_site_real.png --prompt \
"$REPAINT A 1924 Harbin warehouse floor in deep winter: bare concrete and worn timber, snow drifted through the open loading dock, iron braziers throwing warm firelight, a crystalline apparatus glowing cold teal in a brass cradle with heavy cabling. Cold blue-grey shadow against warm lamp pools."

if [ -f /tmp/harbin_epoch_site_real.png ]; then
  cp /tmp/harbin_epoch_site_real.png "$MAPS/harbin_epoch_site.png"
  echo "epoch_site repaint OK"
  echo "=== re-derive after-hours ==="
  GEN --input-images /tmp/harbin_epoch_site_real.png --aspect-ratio 16:9 --quality 2K \
    --output /tmp/harbin_epoch_site_dark2.png --prompt \
"Relight this EXACT photorealistic top-down scene as an after-hours infiltration. Keep the identical layout, contents and overhead viewpoint. Braziers burned down to embers, lamps out, no guards. Deep shadow and dim cold moonlight; the only strong light is the teal glow of the crystalline apparatus and one small warm lantern on the clerk's desk. Photorealistic, not cartoonish, no ink outlines. No grid, no compass, no text, no UI."
  if [ -f /tmp/harbin_epoch_site_dark2.png ]; then
    cp /tmp/harbin_epoch_site_dark2.png "$MAPS/harbin_epoch_site_dark.png"
    echo "epoch_site_dark OK"
  else echo "epoch_site_dark FAILED"; fi
else
  echo "repaint FAILED (keeping the cel-shaded plate)"
fi
echo "GEN_REPAINT COMPLETE"
