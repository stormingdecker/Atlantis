#!/bin/bash
# harbin_extraction v2. v1 came back 3/4 isometric — locomotive, water tower and
# signal box all showing their sides, which is unusable under tokens. "Top-down"
# alone doesn't hold for train subjects; nadir/drone-photo language does.
set -uo pipefail
while pgrep -f "gen_harbin_repaint.sh" >/dev/null; do sleep 20; done
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

NADIR="STRICT NADIR AERIAL VIEW: photographed from a drone hovering directly above and pointing straight down at 90 degrees. You see ONLY THE TOPS of everything — carriage roofs, the top of the boiler, the flat top of the water tank, the roof of the signal hut. NOT ONE SIDE OR FACE of any object is visible anywhere in the frame. No horizon, no sky, no vanishing point, no isometric or three-quarter angle. Perfectly orthographic, flat, like a satellite photograph, suitable for placing miniatures on. Painterly realism, grounded materials, no ink outlines, no cel shading. Fills the entire 16:9 frame edge to edge. Absolutely NO grid, NO compass, NO scale bar, NO text, NO labels, NO UI."

echo "=== harbin_extraction v2 (nadir) ==="
GEN --aspect-ratio 16:9 --quality 2K --output /tmp/harbin_extraction2.png --prompt \
"$NADIR A snowbound Harbin rail yard at midnight in deep winter, 1924. Straight parallel rails run left-to-right across the frame through trodden snow and coal grit. A steam locomotive with its tender and three passenger carriages stands on the centre track — seen purely from above as a long dark spine of roofs, with steam drifting sideways off it. Beside the tracks: the circular top of a water tower, the rectangular roof of a small signal hut, stacks of sleepers, black coal heaps, snow-drifted switch levers, three burning oil drums throwing circular pools of orange light on the snow, a loading platform with crates and barrels, and a chain-link fence with an open gate along one edge. Deep blue snow shadow, footprints and cart tracks between the rolling stock, wide open ground for movement."

if [ -f /tmp/harbin_extraction2.png ]; then
  cp /tmp/harbin_extraction2.png "$MAPS/harbin_extraction.png"
  echo "extraction v2 OK"
else
  echo "extraction v2 FAILED (keeping v1)"
fi
echo "GEN_EXTRACTION2 COMPLETE"
