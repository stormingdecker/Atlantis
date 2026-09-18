#!/bin/bash
# gen_pack.sh <pack_dir> "<era string>" <manifest>
# Generates an equipment-card pack: for each manifest line, generate item art
# (Nano, SEQUENTIAL to avoid buck2 contention crashes) then composite the card
# via make_card.sh. Idempotent — skips art that already exists.
#
# Manifest: pipe-delimited, one item per line (blank / #-comment lines skipped):
#   slug|rarity|name|typeline|art_prompt|stats(\n-escaped)|flavor
set -uo pipefail
PACK="$1"; ERA="$2"; MAN="$3"
DIR="$HOME/gdrive/Atlantis/assets/equipment/$PACK"
TOOLS="$HOME/gdrive/Atlantis/tools"
mkdir -p "$DIR"
cd "$HOME/fbsource" || exit 2

n=0; ok=0
while IFS='|' read -r slug rarity name typeline artp stats flavor; do
  [[ -z "${slug// }" || "$slug" == \#* ]] && continue
  n=$((n+1))
  art="$DIR/art_$slug.png"
  if [[ ! -f "$art" ]]; then
    echo "[$PACK] gen art: $slug"
    timeout 240 buck2 run fbcode//claude-templates/components/skills/generate-image/scripts:generate_image -- \
      --prompt "A single $artp, museum illustration and painterly realism, centered and isolated on a soft aged-parchment background with a subtle drop shadow and faint vignette. Historically accurate to $ERA. No text, no labels, no border, no UI." \
      --aspect-ratio 1:1 --quality 2K --output "$art" >/dev/null 2>&1
    [[ -f "$art" ]] || { echo "[$PACK] ART FAILED: $slug (skipping card)"; continue; }
  else
    echo "[$PACK] art exists: $slug"
  fi
  if bash "$TOOLS/make_card.sh" "$art" "$DIR/card_$slug.png" "$rarity" "$name" "$typeline" "$stats" "$flavor" >/dev/null 2>&1; then
    ok=$((ok+1)); echo "[$PACK] card done: $slug ($ok/$n)"
  else
    echo "[$PACK] CARD FAILED: $slug"
  fi
done < "$MAN"
echo "[$PACK] COMPLETE — $ok/$n cards in $DIR"
