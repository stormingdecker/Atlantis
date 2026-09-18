#!/usr/bin/env python3
"""Generate simple placeholder scene maps for Arc-01 locations so the mission
loader can visibly swap backgrounds. Pure stdlib PNG (struct+zlib). 1024x1024.

Run: python3 tools/gen_scene_maps.py   -> assets/maps/knossos.png, labyrinth.png
"""
import os, struct, zlib

W = H = 1024
HERE = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.join(os.path.dirname(HERE), "assets", "maps")


def buf_new(color):
    row = bytes(color) * W
    b = bytearray(W * H * 3)
    for y in range(H):
        b[y * W * 3:(y + 1) * W * 3] = row
    return b


def rect(b, x, y, w, h, color):
    x0 = max(0, x); y0 = max(0, y)
    x1 = min(W, x + w); y1 = min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    row = bytes(color) * (x1 - x0)
    for yy in range(y0, y1):
        off = (yy * W + x0) * 3
        b[off:off + len(row)] = row


def rect_outline(b, x, y, w, h, t, color):
    rect(b, x, y, w, t, color)              # top
    rect(b, x, y + h - t, w, t, color)      # bottom
    rect(b, x, y, t, h, color)              # left
    rect(b, x + w - t, y, t, h, color)      # right


def write_png(path, b):
    raw = bytearray()
    stride = W * 3
    for y in range(H):
        raw.append(0)
        raw.extend(b[y * stride:(y + 1) * stride])
    comp = zlib.compress(bytes(raw), 6)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", comp))
        f.write(chunk(b"IEND", b""))


def knossos():
    # Warm Bronze-Age palace: terracotta ground + grid of lighter courtyards.
    b = buf_new((150, 96, 58))
    rect(b, 60, 60, W - 120, H - 120, (172, 116, 72))   # inner plaza
    cols, rows = 5, 5
    pad = 110
    cw = (W - pad * 2) // cols
    ch = (H - pad * 2) // rows
    for r in range(rows):
        for c in range(cols):
            x = pad + c * cw + 14
            y = pad + r * ch + 14
            rect(b, x, y, cw - 28, ch - 28, (196, 150, 104))      # courtyard floor
            rect_outline(b, x, y, cw - 28, ch - 28, 6, (120, 74, 44))  # walls
    return b


def labyrinth():
    # Dark stone maze: near-black ground + concentric square corridors.
    b = buf_new((18, 18, 24))
    cx = W // 2
    n = 9
    for i in range(n):
        inset = 70 + i * 52
        size = W - inset * 2
        if size <= 0:
            break
        col = (54, 56, 66) if i % 2 == 0 else (38, 40, 50)
        rect_outline(b, inset, inset, size, size, 10, col)
    # break a few walls so it reads as a maze, not just rings
    rect(b, cx - 16, 70, 32, W - 140, (18, 18, 24))   # vertical corridor
    rect(b, 70, cx - 16, W - 140, 32, (18, 18, 24))   # horizontal corridor
    # glowing center cell (the Minotaur)
    rect(b, cx - 60, cx - 60, 120, 120, (90, 40, 30))
    return b


write_png(os.path.join(MAPS, "knossos.png"), knossos())
write_png(os.path.join(MAPS, "labyrinth.png"), labyrinth())
print("wrote knossos.png + labyrinth.png")
