#!/usr/bin/env python3
"""Generate a 2048x2048 placeholder atlantis.png that lines up with
assets/maps/atlantis_sectors.json. Pure stdlib: writes PNG via struct+zlib.

Run once from the repo root:
    python3 tools/gen_atlantis_placeholder.py
Output: assets/maps/atlantis.png
"""

import json
import math
import os
import struct
import zlib

W = H = 2048
CENTER = (1024, 1024)

OCEAN = (12, 26, 48)
RING_TINT_INNER = (28, 56, 92)
RING_TINT_OUTER = (20, 42, 72)
SECTOR_FILL = (60, 90, 130)
SECTOR_EDGE = (140, 175, 215)
METEOR_CORE = (255, 220, 150)
METEOR_RIM = (220, 110, 35)

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SECTORS_PATH = os.path.join(REPO, "assets", "maps", "atlantis_sectors.json")
OUT_PATH = os.path.join(REPO, "assets", "maps", "atlantis.png")


def fill(buf, color):
    row = bytes(color) * W
    for y in range(H):
        off = y * W * 3
        buf[off:off + W * 3] = row


def set_px(buf, x, y, color):
    if 0 <= x < W and 0 <= y < H:
        off = (y * W + x) * 3
        buf[off:off + 3] = bytes(color)


def blend_px(buf, x, y, color, alpha):
    if not (0 <= x < W and 0 <= y < H):
        return
    off = (y * W + x) * 3
    inv = 1.0 - alpha
    buf[off] = int(buf[off] * inv + color[0] * alpha)
    buf[off + 1] = int(buf[off + 1] * inv + color[1] * alpha)
    buf[off + 2] = int(buf[off + 2] * inv + color[2] * alpha)


def filled_disc(buf, cx, cy, r, color, alpha=1.0):
    r2 = r * r
    x0 = max(0, int(cx - r))
    x1 = min(W - 1, int(cx + r))
    y0 = max(0, int(cy - r))
    y1 = min(H - 1, int(cy + r))
    for y in range(y0, y1 + 1):
        dy = y - cy
        for x in range(x0, x1 + 1):
            dx = x - cx
            if dx * dx + dy * dy <= r2:
                if alpha >= 1.0:
                    set_px(buf, x, y, color)
                else:
                    blend_px(buf, x, y, color, alpha)


def ring_band(buf, cx, cy, r_inner, r_outer, color, alpha=1.0):
    r_out2 = r_outer * r_outer
    r_in2 = r_inner * r_inner
    x0 = max(0, int(cx - r_outer))
    x1 = min(W - 1, int(cx + r_outer))
    y0 = max(0, int(cy - r_outer))
    y1 = min(H - 1, int(cy + r_outer))
    for y in range(y0, y1 + 1):
        dy = y - cy
        for x in range(x0, x1 + 1):
            dx = x - cx
            d2 = dx * dx + dy * dy
            if r_in2 <= d2 <= r_out2:
                if alpha >= 1.0:
                    set_px(buf, x, y, color)
                else:
                    blend_px(buf, x, y, color, alpha)


def fill_polygon(buf, pts, color):
    # Scanline fill for a convex/simple polygon.
    ys = [p[1] for p in pts]
    ymin, ymax = max(0, int(min(ys))), min(H - 1, int(max(ys)))
    n = len(pts)
    for y in range(ymin, ymax + 1):
        xs = []
        for i in range(n):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % n]
            if (y0 <= y < y1) or (y1 <= y < y0):
                t = (y - y0) / (y1 - y0)
                xs.append(x0 + (x1 - x0) * t)
        xs.sort()
        for k in range(0, len(xs), 2):
            if k + 1 >= len(xs):
                break
            xa = max(0, int(xs[k]))
            xb = min(W - 1, int(xs[k + 1]))
            off = (y * W + xa) * 3
            row = bytes(color) * (xb - xa + 1)
            buf[off:off + len(row)] = row


def stroke_polygon(buf, pts, color):
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        line(buf, x0, y0, x1, y1, color)


def line(buf, x0, y0, x1, y1, color):
    x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        set_px(buf, x0, y0, color)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def meteor(buf, cx, cy, r_outer):
    # Soft radial gradient from rim color out to ocean, with a bright core.
    r2_outer = r_outer * r_outer
    x0 = max(0, int(cx - r_outer))
    x1 = min(W - 1, int(cx + r_outer))
    y0 = max(0, int(cy - r_outer))
    y1 = min(H - 1, int(cy + r_outer))
    for y in range(y0, y1 + 1):
        dy = y - cy
        for x in range(x0, x1 + 1):
            dx = x - cx
            d2 = dx * dx + dy * dy
            if d2 > r2_outer:
                continue
            d = math.sqrt(d2)
            t = d / r_outer  # 0 at centre, 1 at rim
            # Two-stop gradient: METEOR_CORE -> METEOR_RIM at t≈0.45, then fade to 0 alpha
            if t < 0.45:
                u = t / 0.45
                col = (
                    int(METEOR_CORE[0] * (1 - u) + METEOR_RIM[0] * u),
                    int(METEOR_CORE[1] * (1 - u) + METEOR_RIM[1] * u),
                    int(METEOR_CORE[2] * (1 - u) + METEOR_RIM[2] * u),
                )
                alpha = 1.0
            else:
                u = (t - 0.45) / 0.55
                # Falloff curve so the meteor doesn't have a hard ring.
                alpha = (1.0 - u) ** 1.6
                col = METEOR_RIM
            blend_px(buf, x, y, col, alpha)


def main():
    with open(SECTORS_PATH) as f:
        data = json.load(f)
    sectors = data["sectors"]

    print("allocating %dx%d buffer..." % (W, H))
    buf = bytearray(W * H * 3)

    print("filling ocean...")
    fill(buf, OCEAN)

    print("painting ring bands...")
    # Ocean tint bands sit under the sector wedges; radii match the wedge
    # layout in gen_sectors.py (inner 320-600, outer 650-950) so the baked art
    # reads as one facility. Re-run this after changing the sector radii.
    ring_band(buf, CENTER[0], CENTER[1], 640, 960, RING_TINT_OUTER, alpha=0.65)
    ring_band(buf, CENTER[0], CENTER[1], 310, 610, RING_TINT_INNER, alpha=0.70)

    print("painting %d sectors..." % len(sectors))
    for s in sectors:
        poly = s["polygon"]
        # Slight per-ring color variation so inner vs outer reads.
        if s["ring"] == "inner":
            col = (74, 108, 148)
        else:
            col = (58, 92, 130)
        fill_polygon(buf, poly, col)
        stroke_polygon(buf, poly, SECTOR_EDGE)

    print("painting meteor...")
    meteor(buf, CENTER[0], CENTER[1], 260)

    print("encoding PNG to %s..." % OUT_PATH)
    write_png(OUT_PATH, buf, W, H)
    print("done.")


def write_png(path, rgb_buf, w, h):
    # Prepend a 0 filter byte to each scanline.
    raw = bytearray()
    stride = w * 3
    for y in range(h):
        raw.append(0)
        off = y * stride
        raw.extend(rgb_buf[off:off + stride])
    compressed = zlib.compress(bytes(raw), level=6)

    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return out + struct.pack(">I", crc)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)  # 8-bit RGB
    with open(path, "wb") as f:
        f.write(sig)
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", compressed))
        f.write(chunk(b"IEND", b""))


if __name__ == "__main__":
    main()
