# Retired — Harbin image-gen jobs (queued 2026-08-13, completed 2026-08-14)

Both jobs ran successfully; nothing here is outstanding. Kept as worked examples
of the prompt shapes that actually hold:

- `gen_harbin_repaint.sh` — repaint an off-style plate photoreal from itself,
  then re-derive a relight from the repaint (the `finish_maps.sh` REPAINT
  pattern) . Fixed `harbin_epoch_site.png` + `harbin_epoch_site_dark.png`.
- `gen_harbin_extraction2.sh` — **strict nadir** wording. "Top-down" alone does
  not hold for trains or interiors; v1 came back 3/4 isometric. What worked:
  "photographed from a drone hovering directly above at 90 degrees... NOT ONE
  SIDE OR FACE of any object is visible anywhere in the frame."
- `gen_harbin.sh` — the first layout pass, plus the Vertex 429 retry-with-backoff
  wrapper worth reusing (`PB-VERTEX-THROTTLING` throttled everything that night).

All three `cd ~/fbsource-atlantis`, NOT `$HOME/fbsource` (Decker's checkout).
Superseded plates are in `VTT/assets/maps/_archive/offspec/`.
