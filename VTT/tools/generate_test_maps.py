#!/usr/bin/env python3
"""Generate placeholder test maps for Atlantis VTT.

Run with no arguments to write a default suite of 6 maps into
../assets/maps/. Existing files are overwritten.

The maps are intentionally not pretty — they exist to exercise the VTT
across a range of aspect ratios, palettes, and resolutions. Each map is
clearly labeled so it's easy to identify in the GM panel list.

Requires Pillow:
    pip install Pillow
"""

import math
import random
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "maps"


def _get_font(size: int):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ]
    for c in candidates:
        if Path(c).exists():
            try:
                return ImageFont.truetype(c, size)
            except OSError:
                continue
    return ImageFont.load_default()


def _vertical_gradient(width: int, height: int, top, bottom) -> Image.Image:
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / max(height - 1, 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    return img


def _draw_hex_grid(img: Image.Image, radius: float, color) -> None:
    draw = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    hx = math.sqrt(3) * radius
    vy = 1.5 * radius
    rows = int(h / vy) + 2
    cols = int(w / hx) + 2
    for row in range(rows):
        for col in range(cols):
            x_off = hx / 2 if row % 2 == 1 else 0
            cx = col * hx + x_off
            cy = row * vy
            points = []
            for i in range(6):
                angle = math.pi / 3 * i - math.pi / 2  # pointy-top
                points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
            points.append(points[0])
            draw.line(points, fill=color, width=1)


def _draw_compass(img: Image.Image, color=(255, 255, 255, 200)) -> None:
    draw = ImageDraw.Draw(img, "RGBA")
    radius = 50
    cx, cy = radius + 30, radius + 30
    draw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        outline=color,
        width=2,
    )
    draw.polygon(
        [
            (cx, cy - radius + 6),
            (cx - 10, cy),
            (cx + 10, cy),
        ],
        fill=color,
    )
    draw.text((cx - 7, cy - radius - 22), "N", fill=color, font=_get_font(20))


def _draw_label(img: Image.Image, text: str, color=(255, 255, 255)) -> None:
    draw = ImageDraw.Draw(img, "RGBA")
    font = _get_font(72)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (img.size[0] - tw) // 2 - bbox[0]
    y = (img.size[1] - th) // 2 - bbox[1]
    draw.text((x + 3, y + 3), text, fill=(0, 0, 0, 180), font=font)
    draw.text((x, y), text, fill=color, font=font)


def map_01_grassland() -> Image.Image:
    img = _vertical_gradient(1920, 1080, (95, 135, 75), (60, 95, 50))
    _draw_hex_grid(img, 40, (255, 255, 255, 60))
    _draw_compass(img)
    _draw_label(img, "MAP 01 — GRASSLAND")
    return img


def map_02_dungeon() -> Image.Image:
    img = Image.new("RGB", (1920, 1080), (30, 30, 38))
    draw = ImageDraw.Draw(img)
    for (x, y, w, h) in [
        (200, 200, 400, 300),
        (800, 380, 500, 360),
        (1400, 180, 350, 280),
        (650, 800, 350, 200),
    ]:
        draw.rectangle([x, y, x + w, y + h], fill=(75, 75, 92), outline=(160, 160, 180), width=4)
    _draw_hex_grid(img, 40, (255, 255, 255, 50))
    _draw_compass(img)
    _draw_label(img, "MAP 02 — DUNGEON")
    return img


def map_03_coast() -> Image.Image:
    img = _vertical_gradient(2560, 1440, (40, 90, 140), (210, 190, 140))
    _draw_hex_grid(img, 50, (255, 255, 255, 60))
    _draw_compass(img)
    _draw_label(img, "MAP 03 — COAST")
    return img


def map_04_temple() -> Image.Image:
    img = _vertical_gradient(1080, 1920, (180, 165, 130), (140, 120, 90))
    draw = ImageDraw.Draw(img)
    for col_x in [200, 540, 880]:
        for col_y in range(220, 1800, 280):
            draw.ellipse(
                [col_x - 45, col_y - 45, col_x + 45, col_y + 45],
                fill=(90, 75, 55),
                outline=(50, 40, 30),
                width=3,
            )
    _draw_hex_grid(img, 40, (255, 255, 255, 60))
    _draw_compass(img)
    _draw_label(img, "MAP 04 — TEMPLE")
    return img


def map_05_starfield() -> Image.Image:
    rng = random.Random(42)
    img = Image.new("RGB", (1920, 1080), (5, 5, 15))
    draw = ImageDraw.Draw(img)
    for _ in range(450):
        x = rng.randint(0, 1920)
        y = rng.randint(0, 1080)
        r = rng.choice([1, 1, 1, 2, 2, 3])
        b = rng.randint(120, 255)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(b, b, b))
    _draw_hex_grid(img, 40, (255, 255, 255, 30))
    _draw_compass(img, color=(255, 255, 255, 150))
    _draw_label(img, "MAP 05 — STARFIELD")
    return img


def map_06_blueprint() -> Image.Image:
    img = Image.new("RGB", (1920, 1080), (25, 75, 130))
    draw = ImageDraw.Draw(img, "RGBA")
    for x in range(0, 1920, 30):
        c = (220, 220, 230, 200) if x % 300 == 0 else (220, 220, 230, 90)
        draw.line([(x, 0), (x, 1080)], fill=c, width=1)
    for y in range(0, 1080, 30):
        c = (220, 220, 230, 200) if y % 300 == 0 else (220, 220, 230, 90)
        draw.line([(0, y), (1920, y)], fill=c, width=1)
    _draw_compass(img, color=(220, 220, 230, 200))
    _draw_label(img, "MAP 06 — BLUEPRINT", color=(220, 220, 230))
    return img


GENERATORS: Iterable[tuple[str, callable]] = [
    ("map_01_grassland.png", map_01_grassland),
    ("map_02_dungeon.png", map_02_dungeon),
    ("map_03_coast.png", map_03_coast),
    ("map_04_temple.png", map_04_temple),
    ("map_05_starfield.png", map_05_starfield),
    ("map_06_blueprint.png", map_06_blueprint),
]


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, gen in GENERATORS:
        img = gen()
        path = OUT_DIR / name
        img.save(path)
        w, h = img.size
        print(f"  wrote {name:30s}  {w}x{h}")
    print(f"\nDone. {len(list(GENERATORS))} test maps in {OUT_DIR}")


if __name__ == "__main__":
    main()
