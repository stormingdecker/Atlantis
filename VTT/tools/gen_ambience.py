#!/usr/bin/env python3
"""Procedural ambience beds for the VTT (24s seamless stereo loops, 48kHz/16-bit).

The four original beds (amb_cave / amb_crowd_rain / amb_desert_wind /
amb_underwater) were made ad hoc and have no generator. This script is where new
ones go, so the next bed is a two-line addition instead of an archaeology dig.

Beds are deliberately quiet and featureless — they sit under the table talk, they
are not a soundtrack. Music is Alexandre's job (Suno); this is weather and room.

Seamlessness: every layer is built from sinusoidal LFOs whose periods divide the
loop length exactly, and the noise itself is cross-faded head-to-tail, so the
join is inaudible.

    python3 tools/gen_ambience.py                 # write any missing beds
    python3 tools/gen_ambience.py --force winter_wind
"""

from __future__ import annotations

import argparse
import math
import random
import struct
from pathlib import Path

SR = 48000
LOOP_S = 24.0
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "ambience"


def _write_stereo(path: Path, left: list[float], right: list[float]) -> None:
    n = len(left)
    data = bytearray()
    for i in range(n):
        for ch in (left, right):
            v = int(max(-1.0, min(1.0, ch[i])) * 32767)
            data += struct.pack("<h", v)
        # (interleaved L,R)
    hdr = b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVEfmt "
    hdr += struct.pack("<IHHIIHH", 16, 1, 2, SR, SR * 4, 4, 16)
    hdr += b"data" + struct.pack("<I", len(data))
    path.write_bytes(hdr + bytes(data))


def _noise(n: int, seed: int) -> list[float]:
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def _lowpass(sig: list[float], cutoff_hz: float) -> list[float]:
    """One-pole lowpass. Cheap, and exactly the character wind wants."""
    a = math.exp(-2.0 * math.pi * cutoff_hz / SR)
    out, y = [0.0] * len(sig), 0.0
    for i, x in enumerate(sig):
        y = a * y + (1.0 - a) * x
        out[i] = y
    return out


def _highpass(sig: list[float], cutoff_hz: float) -> list[float]:
    lo = _lowpass(sig, cutoff_hz)
    return [s - l for s, l in zip(sig, lo)]


def _seamless(sig: list[float], fade_s: float = 1.5) -> list[float]:
    """Cross-fade the tail over the head so the loop point is inaudible."""
    f = int(fade_s * SR)
    out = list(sig[: len(sig) - f])
    head = sig[:f]
    tail = sig[len(sig) - f :]
    for i in range(f):
        t = i / f
        out[i] = tail[i] * (1.0 - t) + head[i] * t
    return out


def winter_wind() -> tuple[list[float], list[float]]:
    """Harbin in January: steady cold wind with slow gusts, no detail.

    Two decorrelated noise beds (one per ear) keep it wide; the gust LFOs use
    whole-cycle periods over the loop so the swell lines up at the join.
    """
    n = int(LOOP_S * SR)
    chans = []
    for ch, seed in enumerate((7717, 4231)):
        base = _lowpass(_lowpass(_noise(n, seed), 420.0), 420.0)
        # A touch of hiss on top so it isn't a pure rumble — snow on gravel.
        # Two poles on the top end: one is too gentle and leaks tape-hiss all
        # the way to 20 kHz (visible as a red ceiling on the spectrogram).
        hiss = _highpass(_lowpass(_lowpass(_noise(n, seed + 1), 4200.0), 4200.0), 1800.0)
        out = [0.0] * n
        for i in range(n):
            t = i / SR
            # 3 gusts + 7 gusts + 2 gusts per loop; all integer cycles.
            g = (
                0.55
                + 0.28 * math.sin(2 * math.pi * 3 * t / LOOP_S + ch * 1.1)
                + 0.11 * math.sin(2 * math.pi * 7 * t / LOOP_S + ch * 2.3)
                + 0.14 * math.sin(2 * math.pi * 2 * t / LOOP_S)
            )
            g = max(0.05, g)
            out[i] = (base[i] * 3.2 * g + hiss[i] * 1.6 * g * g) * 0.30
        chans.append(_seamless(out))
    return chans[0], chans[1]


def rail_yard() -> tuple[list[float], list[float]]:
    """Idling steam locomotive in a snowbound yard: low chuff, distant hiss."""
    n = int(LOOP_S * SR)
    chans = []
    for ch, seed in enumerate((9111, 3372)):
        rumble = _lowpass(_noise(n, seed), 90.0)
        steam = _highpass(_lowpass(_noise(n, seed + 1), 4000.0), 900.0)
        out = [0.0] * n
        for i in range(n):
            t = i / SR
            # 48 chuffs over the loop = a slow 2 Hz idle, integer cycles.
            chuff = max(0.0, math.sin(2 * math.pi * 48 * t / LOOP_S)) ** 3
            breathe = 0.6 + 0.4 * math.sin(2 * math.pi * 2 * t / LOOP_S + ch * 0.7)
            out[i] = (
                rumble[i] * 5.0 * (0.5 + 0.5 * chuff)
                + steam[i] * 0.55 * breathe * (0.25 + 0.75 * chuff)
            ) * 0.26
        chans.append(_seamless(out))
    return chans[0], chans[1]


BEDS = {
    "winter_wind": winter_wind,
    "rail_yard": rail_yard,
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("beds", nargs="*", default=[], help="bed names (default: all)")
    ap.add_argument("--force", action="store_true", help="overwrite existing")
    args = ap.parse_args()

    names = args.beds or list(BEDS)
    for name in names:
        if name not in BEDS:
            raise SystemExit(f"unknown bed {name!r}; known: {', '.join(BEDS)}")
        path = OUT / f"amb_{name}.wav"
        if path.exists() and not args.force:
            print(f"skip (exists): {path.name}")
            continue
        left, right = BEDS[name]()
        _write_stereo(path, left, right)
        print(f"wrote {path.name} ({path.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
