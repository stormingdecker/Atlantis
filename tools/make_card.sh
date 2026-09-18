#!/bin/bash
# make_card.sh — compose a printable equipment card from item art + stats.
# No PIL/SVG/browser on this box, so we build it entirely in ffmpeg
# (drawbox + drawtext/libfreetype). 750x1050 = 2.5x3.5in @300dpi (card-sleeve size).
#
# Usage:
#   make_card.sh <art.png> <out.png> <rarity> "<name>" "<typeline>" "<stats(\n-separated)>" ["<flavor>"]
#   rarity ∈ common | uncommon | rare | epic | legendary   (frame + bottom bar colour)
#
# The rarity colour shows as the outer frame AND the bottom bar (classic loot palette).
set -uo pipefail

ART="$1"; OUT="$2"; RARITY="$3"; NAME="$4"; TYPELINE="$5"; STATS="$6"; FLAVOR="${7:-}"

SERIF="/usr/share/fonts/liberation-serif/LiberationSerif-Regular.ttf"
SERIF_B="/usr/share/fonts/liberation-serif/LiberationSerif-Bold.ttf"
SERIF_I="/usr/share/fonts/liberation-serif/LiberationSerif-Italic.ttf"
BG="$HOME/gdrive/Atlantis/assets/equipment/card_bg.png"   # shared campaign background watermark

case "$RARITY" in
  common)    COL="0x9d9d9d"; WORD="COMMON" ;;
  uncommon)  COL="0x3aa84f"; WORD="UNCOMMON" ;;
  rare)      COL="0x2f6fd6"; WORD="RARE" ;;
  epic)      COL="0x8a2be2"; WORD="EPIC" ;;
  legendary) COL="0xff8c1a"; WORD="LEGENDARY" ;;
  *)         COL="0x9d9d9d"; WORD="COMMON" ;;
esac

TMP="$(mktemp -d)"
printf '%s' "$NAME"     > "$TMP/name.txt"
printf '%s' "$TYPELINE" > "$TMP/type.txt"
printf '%b' "$STATS"    > "$TMP/stats.txt"   # %b so \n in the arg becomes real newlines
printf '%b' "$FLAVOR"   > "$TMP/flavor.txt"

ffmpeg -y -i "$BG" -i "$ART" -filter_complex "
[0]scale=750:1050:force_original_aspect_ratio=increase,crop=750:1050,setsar=1,
   drawbox=0:0:750:1050:$COL:18,
   drawbox=18:18:714:1014:0x241d16:3,
   drawbox=24:24:702:68:0xEDE2C6@0.72:fill,
   drawbox=24:26:702:2:0x241d16:fill,
   drawbox=24:92:702:2:0x241d16:fill,
   drawbox=30:636:690:322:0xF2E8CE@0.45:fill,
   drawbox=115:112:520:520:0x241d16:4,
   drawbox=24:980:702:46:$COL:fill,
   drawbox=24:978:702:2:0x241d16:fill [bg];
[1]scale=512:512:force_original_aspect_ratio=decrease[art];
[bg][art]overlay=(750-overlay_w)/2:120[c];
[c]drawtext=fontfile=$SERIF_B:textfile=$TMP/name.txt:fontcolor=0x2a2018:fontsize=36:x=(w-text_w)/2:y=38,
   drawtext=fontfile=$SERIF_I:textfile=$TMP/type.txt:fontcolor=0x5b4a30:fontsize=25:x=(w-text_w)/2:y=648,
   drawtext=fontfile=$SERIF:textfile=$TMP/stats.txt:fontcolor=0x2a2018:fontsize=25:x=48:y=696:line_spacing=9,
   drawtext=fontfile=$SERIF_I:textfile=$TMP/flavor.txt:fontcolor=0x6b5a3e:fontsize=21:x=48:y=902:line_spacing=7,
   drawtext=fontfile=$SERIF_B:text='$WORD':fontcolor=white:fontsize=28:x=(w-text_w)/2:y=990
" -frames:v 1 "$OUT" 2>"$TMP/ff.log"
RC=$?
rm -rf "$TMP"
[ $RC -eq 0 ] && echo "card -> $OUT" || { echo "FAILED (rc=$RC)"; }
exit $RC
