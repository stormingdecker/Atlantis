#!/bin/bash
# Regenerate harbin_epoch_site.png on-spec (top-down, roofs-off, full-bleed 16:9)
# and produce the after-hours relight the mission page calls for.
set -uo pipefail
MAPS="$HOME/gdrive/Atlantis/VTT/assets/maps"
ARCH="$MAPS/_archive/offspec"; mkdir -p "$ARCH"
# Vertex throttles (HTTP 429 / PB-VERTEX-THROTTLING) under load; retry with backoff.
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

STYLE="Top-down tabletop battle map seen from DIRECTLY OVERHEAD, perfectly orthographic, flat for miniatures. Roofs and ceilings entirely REMOVED so the floor plan is fully visible; walls read as thin plan-view cuts with NO visible wall height and NO 3/4 or isometric perspective whatsoever. Painterly realism with grounded physically-based materials, soft even light. NO ink outlines, NO cel shading, NO black borders. The scene FILLS THE ENTIRE 16:9 FRAME edge to edge with no empty background, no drop shadow, no floating island. Absolutely NO grid, NO compass, NO scale bar, NO text, NO labels, NO UI."

[ -f "$ARCH/harbin_epoch_site.png" ] || cp "$MAPS/harbin_epoch_site.png" "$ARCH/harbin_epoch_site.png"

echo "=== 1/2 harbin_epoch_site (guarded) ==="
GEN --aspect-ratio 16:9 --quality 2K --output /tmp/harbin_epoch_site.png --prompt \
"$STYLE A clandestine 1924 Harbin warehouse in a Russian-Chinese consulate compound in deep winter, converted into a covert foundry-support workstation. Central hall: a heavy machine bench carrying an anomalous crystalline apparatus in a brass and steel cradle, thick cabling snaking to humming transformer cabinets, a cold teal glow spilling onto the concrete floor. Around it: stacked crates and barrels, canvas tarpaulins, a caged storage bay, workbenches with tools and papers. A side clerk's office with a desk, filing cabinets and a stove. A loading dock at one edge with double doors ajar, drifted snow blown across the threshold, cart tracks and bootprints. Guarded: two lit brazier pools and lamplight at the doors, a sentry post with a chair and rifle rack. Warm oil-lamp pools against cold blue-grey concrete."

if [ -f /tmp/harbin_epoch_site.png ]; then
  cp /tmp/harbin_epoch_site.png "$MAPS/harbin_epoch_site.png"
  echo "epoch_site OK"
  echo "=== 2/2 harbin_epoch_site_dark (after-hours) ==="
  GEN --input-images /tmp/harbin_epoch_site.png --aspect-ratio 16:9 --quality 2K \
    --output /tmp/harbin_epoch_site_dark.png --prompt \
"Relight this EXACT top-down scene as an after-hours infiltration. Keep the identical layout, contents and overhead orthographic viewpoint. Braziers burned down to embers, lamps out, sentry post empty. Deep shadow and dim cold moonlight through the high openings; the only strong light is the teal glow of the crystalline apparatus and one small warm lantern left on the clerk's desk. Painterly realism, no outlines. No grid, no compass, no text, no UI."
  if [ -f /tmp/harbin_epoch_site_dark.png ]; then
    cp /tmp/harbin_epoch_site_dark.png "$MAPS/harbin_epoch_site_dark.png"
    echo "epoch_site_dark OK"
  else echo "epoch_site_dark FAILED"; fi
else
  echo "epoch_site FAILED"
fi
echo "GEN_HARBIN COMPLETE"
