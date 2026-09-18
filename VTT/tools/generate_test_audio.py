#!/usr/bin/env python3
"""Generate placeholder test audio for Atlantis VTT.

Run with no arguments to write 2 music drones into ../assets/audio/music/
and 2 SFX clips into ../assets/audio/sfx/. Existing files are overwritten.

Pure stdlib — no Pillow, numpy, etc. Just Python 3.10+ for the type hints.
"""

import math
import struct
import wave
from pathlib import Path


OUT_BASE = Path(__file__).resolve().parent.parent / "assets" / "audio"
SAMPLE_RATE = 44100


def write_mono_wave(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray(len(samples) * 2)
    for i, s in enumerate(samples):
        v = max(-1.0, min(1.0, s))
        struct.pack_into("<h", frames, i * 2, int(v * 32767))
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(bytes(frames))


def make_drone(fundamental_hz: float, duration_s: float, amplitude: float = 0.22) -> list[float]:
    """A sustained tone with detuned partials, fading at the seams for loops."""
    n = int(SAMPLE_RATE * duration_s)
    fade_samples = int(n * 0.04)  # 4% fade in/out to hide loop seam
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        v = (
            math.sin(2 * math.pi * fundamental_hz * t) * 0.6
            + math.sin(2 * math.pi * fundamental_hz * 1.005 * t) * 0.25
            + math.sin(2 * math.pi * fundamental_hz * 2.0 * t) * 0.15
        )
        if i < fade_samples:
            v *= i / fade_samples
        elif i > n - fade_samples:
            v *= (n - i) / fade_samples
        samples[i] = v * amplitude
    return samples


def make_beep(frequency: float, duration_s: float, amplitude: float = 0.4) -> list[float]:
    n = int(SAMPLE_RATE * duration_s)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 5.0)
        samples[i] = math.sin(2 * math.pi * frequency * t) * env * amplitude
    return samples


def make_chime(frequencies: list[float], duration_s: float, amplitude: float = 0.3) -> list[float]:
    n = int(SAMPLE_RATE * duration_s)
    samples = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 2.5)
        v = sum(math.sin(2 * math.pi * f * t) for f in frequencies) / len(frequencies)
        samples[i] = v * env * amplitude
    return samples


def main() -> None:
    # Singles — long enough that the loop seam is barely perceptible.
    write_mono_wave(
        OUT_BASE / "music" / "music_01_drone_low.wav",
        make_drone(110.0, 18.0),  # A2
    )
    write_mono_wave(
        OUT_BASE / "music" / "music_02_drone_mid.wav",
        make_drone(220.0, 18.0),  # A3
    )
    # Sample 4-tier mission suite for testing the suite UI. Each tier gets
    # a distinct pitch so the crossfade between tiers is audibly obvious.
    suite_dir = OUT_BASE / "music" / "missions" / "test_mission"
    write_mono_wave(suite_dir / "01_exploration.wav", make_drone(110.0, 12.0, amplitude=0.18))    # A2
    write_mono_wave(suite_dir / "02_civilization.wav", make_drone(146.83, 12.0, amplitude=0.20))  # D3
    write_mono_wave(suite_dir / "03_combat.wav", make_drone(220.0, 12.0, amplitude=0.24))         # A3
    write_mono_wave(suite_dir / "04_boss.wav", make_drone(329.63, 12.0, amplitude=0.28))          # E4
    # SFX — short and recognizable, useful for testing trigger overlap.
    write_mono_wave(
        OUT_BASE / "sfx" / "sfx_01_beep.wav",
        make_beep(880.0, 0.25),
    )
    write_mono_wave(
        OUT_BASE / "sfx" / "sfx_02_chime.wav",
        make_chime([523.25, 659.25, 783.99], 1.2),  # C major triad
    )
    print(f"Wrote test audio into {OUT_BASE}")
    print("  music/music_01_drone_low.wav                     A2 drone, 18 s")
    print("  music/music_02_drone_mid.wav                     A3 drone, 18 s")
    print("  music/missions/test_mission/01_exploration.wav   A2 drone, 12 s")
    print("  music/missions/test_mission/02_civilization.wav  D3 drone, 12 s")
    print("  music/missions/test_mission/03_combat.wav        A3 drone, 12 s")
    print("  music/missions/test_mission/04_boss.wav          E4 drone, 12 s")
    print("  sfx/sfx_01_beep.wav                              880 Hz beep, 0.25 s")
    print("  sfx/sfx_02_chime.wav                             C major chime, 1.2 s")


if __name__ == "__main__":
    main()
