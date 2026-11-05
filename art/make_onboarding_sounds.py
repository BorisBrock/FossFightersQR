#!/usr/bin/env python3
"""Synthesizes the onboarding sound effects into assets/onboarding/sounds/. Needs only the standard library."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "onboarding" / "sounds"


def bell(t, freq):
    """A struck metal tone: inharmonic partials that fade at different speeds."""
    partials = ((1.0, 1.0, 3.0), (2.01, 0.5, 5.0), (3.02, 0.25, 8.0), (4.17, 0.12, 12.0))
    return sum(gain * math.exp(-t * decay) * math.sin(math.tau * freq * ratio * t) for ratio, gain, decay in partials)


def horn(t, freq, length):
    """A brass-like tone: rich in harmonics, with a soft attack and release."""
    envelope = min(t / 0.03, 1.0) * min(max(length - t, 0.0) / 0.08, 1.0)
    return envelope * sum(math.sin(math.tau * freq * n * t) / n ** 1.3 for n in range(1, 7))


def mix(length, notes):
    """notes are (start, voice), where voice takes the time since the start."""
    samples = [0.0] * int(length * RATE)
    for start, voice in notes:
        for i in range(int(start * RATE), len(samples)):
            samples[i] += voice(i / RATE - start)
    return samples


def save(name, samples):
    peak = max(abs(s) for s in samples)
    fade = int(0.01 * RATE)
    with wave.open(str(OUT / name), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        frames = bytearray()
        for i, sample in enumerate(samples):
            sample *= 0.8 / peak * min((len(samples) - i) / fade, 1.0)
            frames += struct.pack("<h", int(sample * 32767))
        out.writeframes(frames)


def reveal():
    """A rising arpeggio with a shimmer: a card has been recognized."""
    rng = random.Random(7)
    notes = [(0.08 * i, lambda t, f=f: bell(t, f)) for i, f in enumerate((523.25, 659.25, 783.99, 1046.5, 1318.5))]
    notes += [(rng.uniform(0.2, 0.8), lambda t, f=rng.uniform(2200, 4200): 0.08 * bell(t * 2.0, f)) for _ in range(14)]
    return mix(1.4, notes)


def seat():
    """A wooden knock with a coin ringing on top: a hero sits down."""
    knock = lambda t: math.exp(-t * 28.0) * (math.sin(math.tau * 130 * t) + 0.6 * math.sin(math.tau * 215 * t))
    return mix(0.8, [(0.0, knock), (0.02, lambda t: 0.45 * bell(t, 1567.98)), (0.1, lambda t: 0.25 * bell(t, 2093.0))])


def fanfare():
    """Short brass call: the party sets out."""
    parts = ((0.0, 0.14, (392.0,)), (0.16, 0.14, (392.0,)), (0.32, 0.14, (523.25,)), (0.48, 0.8, (523.25, 659.25, 783.99)))
    notes = [(start, lambda t, f=f, n=length: horn(t, f, n) if t < n else 0.0) for start, length, freqs in parts for f in freqs]
    return mix(1.4, notes)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    save("reveal.wav", reveal())
    save("seat.wav", seat())
    save("fanfare.wav", fanfare())
