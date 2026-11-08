"""Makes the makeshift sound effects of the fight, in assets/sounds/.

They are synthesized, so they can be remade or tuned at any time:

    .venv/bin/python tools/make_sounds.py

Only the standard library and ffmpeg (for the Ogg Vorbis files) are used. Randomness is seeded, so the files come out the same
every time. See docs/sounds.md for which event plays which sound.
"""

import io
import math
import random
import struct
import subprocess
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


# region Building blocks
def silence(seconds):
    return [0.0] * int(seconds * RATE)


def note(freq, seconds, shape="sine", attack=0.005, decay=None, glide_to=None, vibrato=0.0):
    """One tone. decay: an exponential fall in seconds (None: held, with a short release)."""
    n = int(seconds * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if glide_to is None else freq * (glide_to / freq) ** (t / seconds)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * 5.5 * t)
        phase += 2 * math.pi * f / RATE
        if shape == "sine":
            v = math.sin(phase)
        elif shape == "triangle":
            v = 2 / math.pi * math.asin(math.sin(phase))
        elif shape == "square":
            # Softened, so it does not hurt the ears.
            v = math.tanh(4 * math.sin(phase))
        elif shape == "saw":
            v = 2 * ((phase / (2 * math.pi)) % 1.0) - 1
        else:
            raise ValueError(shape)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        if decay is None:
            release = 0.04
            env *= min(1.0, (seconds - t) / release)
        else:
            env *= math.exp(-t / decay)
        out.append(v * env)
    return out


def bell(freq, seconds, decay=0.35):
    """A bright bell: a few partials, the higher ones dying sooner."""
    out = [0.0] * int(seconds * RATE)
    for ratio, gain, d in ((1.0, 1.0, decay), (2.0, 0.4, decay * 0.6), (3.01, 0.2, decay * 0.4), (4.2, 0.1, decay * 0.25)):
        mix(out, note(freq * ratio, seconds, decay=d, attack=0.002), 0, gain)
    return out


def noise(seconds, seed, attack=0.002, decay=0.1):
    rng = random.Random(seed)
    n = int(seconds * RATE)
    return [rng.uniform(-1, 1) * min(1.0, (i / RATE) / attack) * math.exp(-(i / RATE) / decay) for i in range(n)]


def lowpass(samples, cutoff):
    """One pole. cutoff may be a function of the time in seconds, for sweeps."""
    out = []
    y = 0.0
    for i, x in enumerate(samples):
        c = cutoff(i / RATE) if callable(cutoff) else cutoff
        a = 1 - math.exp(-2 * math.pi * c / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - y for x, y in zip(samples, low)]


def mix(into, samples, at_seconds=0.0, gain=1.0):
    start = int(at_seconds * RATE)
    if len(into) < start + len(samples):
        into.extend([0.0] * (start + len(samples) - len(into)))
    for i, v in enumerate(samples):
        into[start + i] += v * gain
    return into


def seq(*parts):
    out = []
    for part in parts:
        out.extend(part)
    return out


def save(name, samples, peak=0.8):
    # A short fade at both ends, against clicks.
    fade = int(0.003 * RATE)
    for i in range(min(fade, len(samples))):
        samples[i] *= i / fade
        samples[-1 - i] *= i / fade
    top = max(abs(v) for v in samples) or 1.0
    frames = b"".join(struct.pack("<h", int(v / top * peak * 32767)) for v in samples)
    OUT.mkdir(parents=True, exist_ok=True)
    wav = io.BytesIO()
    with wave.open(wav, "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(frames)
    # Mono Ogg Vorbis: a fraction of the WAV's size, and played by Godot as is.
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", "-", "-c:a", "libvorbis", "-q:a", "5", str(OUT / f"{name}.ogg")],
        input=wav.getvalue(), check=True,
    )
    print(f"{name}.ogg  {len(samples) / RATE:.2f} s")
# endregion


def hz(name):
    """The frequency of a note such as "A4" or "F#5"."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        semis += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        semis -= 1
        rest = rest[1:]
    return 440.0 * 2 ** ((semis + (int(rest) - 4) * 12) / 12)


# region The sounds
def turn():
    """A hero's turn: they have to show a card. Two bright notes, up."""
    out = []
    mix(out, bell(hz("E5"), 0.5, 0.25), 0.0)
    mix(out, bell(hz("A5"), 0.7, 0.35), 0.12)
    return out


def choose():
    """The players have to choose: tap a hero, or a button. A questioning three-note call."""
    out = []
    for i, (n, length) in enumerate((("G5", 0.25), ("G5", 0.25), ("D6", 0.55))):
        mix(out, note(hz(n), length, "triangle", decay=0.18 if i < 2 else 0.3), i * 0.11, 0.8)
    return out


def select():
    """A hero or a button was tapped: a short wooden tick."""
    out = note(1800, 0.07, "sine", attack=0.001, decay=0.012, glide_to=900)
    mix(out, lowpass(noise(0.03, 1, decay=0.006), 4000), 0, 0.5)
    return out


def rejected():
    """A card cannot be played now: a low double buzz."""
    buzz = lowpass(note(150, 0.13, "square", attack=0.004), 1200)
    return seq(buzz, silence(0.05), lowpass(note(120, 0.18, "square", attack=0.004), 1200))


def lightning():
    """Lightning: another action. A crackling zap, falling."""
    out = note(2400, 0.4, "saw", attack=0.001, decay=0.12, glide_to=180)
    out = lowpass(out, lambda t: 6000 * math.exp(-t / 0.15) + 300)
    rng = random.Random(7)
    crackle = [v if rng.random() < 0.15 else v * 0.15 for v in noise(0.4, 8, decay=0.1)]
    mix(out, highpass(crackle, 2000), 0, 0.9)
    return out


def hit():
    """The boss takes damage: a heavy thump."""
    out = note(160, 0.35, "sine", attack=0.001, decay=0.09, glide_to=45)
    mix(out, lowpass(noise(0.12, 2, decay=0.025), 2500), 0, 0.8)
    return out


def shield_block():
    """A shield takes the damage: a metallic clank."""
    out = []
    for f, gain, d in ((523, 1.0, 0.12), (1231, 0.6, 0.08), (1817, 0.45, 0.06), (2654, 0.3, 0.04), (3911, 0.2, 0.03)):
        mix(out, note(f, 0.45, decay=d, attack=0.001), 0, gain)
    mix(out, highpass(noise(0.05, 3, decay=0.008), 3000), 0, 0.8)
    return out


def shield_break():
    """A shield is broken: a clank, then glass shattering."""
    out = shield_block()
    rng = random.Random(4)
    for i in range(14):
        at = 0.04 + rng.random() * 0.45
        shard = note(rng.uniform(2500, 6500), 0.2, decay=rng.uniform(0.02, 0.06), attack=0.001)
        mix(out, shard, at, rng.uniform(0.15, 0.4))
    mix(out, highpass(noise(0.7, 5, decay=0.18), 2500), 0.02, 0.7)
    return out


def shields_up():
    """The boss raises its shields: a rising, wavering shimmer."""
    n = 0.75
    out = note(260, n, "triangle", attack=0.15, glide_to=780, vibrato=0.01)
    mix(out, note(390, n, "sine", attack=0.2, glide_to=1170), 0, 0.5)
    trem = [v * (0.75 + 0.25 * math.sin(2 * math.pi * 14 * i / RATE)) for i, v in enumerate(out)]
    mix(trem, bell(hz("E6"), 0.5, 0.25), 0.55, 0.5)
    return trem


def poison():
    """Poison: bubbles."""
    out = []
    rng = random.Random(6)
    at = 0.0
    for i in range(7):
        f = rng.uniform(300, 650)
        mix(out, note(f, 0.09, attack=0.004, decay=0.035, glide_to=f * 2.2), at, rng.uniform(0.5, 1.0))
        at += rng.uniform(0.05, 0.11)
    return lowpass(out, 3000)


def protect():
    """An attack is lowered, or every attack blocked: a warm, solid block."""
    out = note(hz("G3"), 0.45, "triangle", attack=0.003, decay=0.15)
    mix(out, note(hz("D4"), 0.45, "sine", attack=0.003, decay=0.15), 0, 0.6)
    mix(out, note(hz("G4"), 0.45, "sine", attack=0.003, decay=0.12), 0, 0.4)
    mix(out, lowpass(noise(0.08, 9, decay=0.02), 1500), 0, 0.6)
    return out


def round_start():
    """A new round: a deep drum with a gong."""
    out = note(85, 1.3, "sine", attack=0.002, decay=0.22, glide_to=60)
    for f, gain, d in ((110, 0.5, 0.7), (167, 0.35, 0.5), (231, 0.25, 0.4), (349, 0.15, 0.3)):
        mix(out, note(f, 1.3, attack=0.02, decay=d, vibrato=0.003), 0.0, gain)
    mix(out, lowpass(noise(0.1, 10, decay=0.03), 800), 0, 0.7)
    return out


def boss_attack():
    """The boss strikes: a swish, then a growl."""
    swish = lowpass(noise(0.3, 11, attack=0.12, decay=0.1), lambda t: 500 + 6000 * t / 0.3)
    out = list(swish)
    growl = note(70, 0.7, "saw", attack=0.03, decay=0.35, glide_to=50, vibrato=0.06)
    rng = random.Random(12)
    rough = [v * (0.6 + 0.4 * rng.random()) for v in growl]
    mix(out, lowpass(rough, 900), 0.22, 1.0)
    mix(out, hit(), 0.22, 0.6)
    return out


def hurt():
    """A hero loses health: a falling 'oof'."""
    return lowpass(note(420, 0.32, "square", attack=0.005, decay=0.15, glide_to=160), 1800)


def heal():
    """Healing: a sparkling arpeggio, up."""
    out = []
    for i, n in enumerate(("C6", "E6", "G6", "C7")):
        mix(out, bell(hz(n), 0.6, 0.25), i * 0.07, 0.7)
    rng = random.Random(13)
    for i in range(10):
        mix(out, note(rng.uniform(4000, 8000), 0.1, decay=0.03), 0.1 + rng.random() * 0.4, 0.15)
    return out


def victory():
    """The boss is beaten: a short jingle."""
    out = []
    steps = (("C5", 0.0, 0.18), ("E5", 0.13, 0.18), ("G5", 0.26, 0.18), ("C6", 0.39, 0.9))
    for n, at, length in steps:
        mix(out, note(hz(n), length, "triangle", attack=0.005, vibrato=0.004 if length > 0.5 else 0), at, 0.8)
        mix(out, bell(hz(n), length + 0.3, 0.2), at, 0.3)
    for n in ("E5", "G5"):
        mix(out, note(hz(n), 0.9, "triangle", attack=0.01, vibrato=0.004), 0.39, 0.4)
    return out


def defeat():
    """The heroes lost: falling, sad notes."""
    out = []
    steps = (("G4", 0.0, 0.35), ("F#4", 0.32, 0.35), ("F4", 0.64, 0.35), ("E4", 0.96, 1.0))
    for n, at, length in steps:
        mix(out, note(hz(n), length, "triangle", attack=0.01, vibrato=0.008), at, 0.8)
    mix(out, note(hz("E3"), 1.0, "sine", attack=0.05), 0.96, 0.5)
    return lowpass(out, 2500)


def boss_appears():
    """The boss appears: a swelling rumble."""
    n = 1.5
    rumble = lowpass(noise(n, 14, attack=0.6, decay=0.7), 180)
    out = [v * 3 for v in rumble]
    mix(out, note(45, n, "sine", attack=0.6, decay=0.6), 0, 0.7)
    mix(out, note(67, n, "saw", attack=0.7, decay=0.5, vibrato=0.02), 0, 0.15)
    return lowpass(out, 600)

def magic_hit():
    """A bolt of magic hits the boss: a rising whoosh, then a sparkling splash."""
    out = []
    swell = lowpass(noise(0.16, 15, attack=0.12, decay=0.2), lambda t: 900 + 7000 * t / 0.16)
    mix(out, swell, 0, 0.5)
    mix(out, note(380, 0.18, "sine", attack=0.1, glide_to=1500), 0, 0.35)
    # The splash: a hollow pop, a shimmering chord, and sparkles.
    mix(out, note(900, 0.25, "sine", attack=0.001, decay=0.05, glide_to=260), 0.15, 0.8)
    mix(out, highpass(noise(0.5, 16, decay=0.09), 2200), 0.15, 0.55)
    for n, gain in (("E6", 0.5), ("B6", 0.35), ("G#6", 0.3)):
        shimmer = note(hz(n), 0.7, "sine", attack=0.004, decay=0.22, vibrato=0.012)
        mix(out, shimmer, 0.15, gain)
    rng = random.Random(17)
    for i in range(9):
        mix(out, note(rng.uniform(3500, 9000), 0.08, decay=0.02, attack=0.001), 0.17 + rng.random() * 0.4, 0.18)
    return out


def arrow_hit():
    """An arrow hits the boss: a short whistle, a wooden thunk and the shaft quivering."""
    out = []
    whistle = highpass(lowpass(noise(0.1, 18, attack=0.08, decay=0.2), lambda t: 2500 + 5000 * t / 0.1), 1500)
    mix(out, whistle, 0, 0.45)
    at = 0.09
    mix(out, note(240, 0.18, "sine", attack=0.001, decay=0.035, glide_to=80), at, 1.0)
    mix(out, lowpass(highpass(noise(0.05, 19, decay=0.01), 900), 5000), at, 0.9)
    # The shaft quivering: a low twang that wobbles away.
    twang = note(170, 0.35, "triangle", attack=0.002, decay=0.09, vibrato=0.05)
    trem = [v * (0.6 + 0.4 * math.sin(2 * math.pi * 26 * i / RATE)) for i, v in enumerate(twang)]
    mix(out, lowpass(trem, 1600), at + 0.01, 0.45)
    return out


def slash():
    """A sword slashes across the boss: a fast swish, a ringing blade and a cut."""
    out = []
    n = 0.32
    swish = noise(n, 20, attack=0.14, decay=0.12)
    swish = lowpass(swish, lambda t: 600 + 9000 * math.sin(math.pi * min(1.0, t / n)) ** 2)
    mix(out, highpass(swish, 400), 0, 1.0)
    # The blade rings: high, inharmonic, long.
    at = 0.13
    for f, gain, d in ((2637, 0.5, 0.35), (3953, 0.35, 0.25), (5274, 0.25, 0.18), (6912, 0.15, 0.12)):
        mix(out, note(f, 0.8, attack=0.002, decay=d, vibrato=0.002), at, gain)
    # The cut: a tearing burst and a heavy thump.
    mix(out, highpass(noise(0.18, 21, decay=0.04), 1200), at, 0.8)
    mix(out, note(130, 0.3, "sine", attack=0.001, decay=0.07, glide_to=45), at, 0.9)
    return out
# endregion


SOUNDS = {
    "turn": turn,
    "choose": choose,
    "select": select,
    "rejected": rejected,
    "lightning": lightning,
    "hit": hit,
    "shield_block": shield_block,
    "shield_break": shield_break,
    "shields_up": shields_up,
    "poison": poison,
    "protect": protect,
    "round": round_start,
    "boss_attack": boss_attack,
    "hurt": hurt,
    "heal": heal,
    "victory": victory,
    "defeat": defeat,
    "boss_appears": boss_appears,
    "magic_hit": magic_hit,
    "arrow_hit": arrow_hit,
    "slash": slash,
}


# Quieter than the rest, as they come often.
PEAKS = {"select": 0.4, "rejected": 0.6, "poison": 0.65, "magic_hit": 0.6, "arrow_hit": 0.65}


if __name__ == "__main__":
    for sound_name, make in SOUNDS.items():
        save(sound_name, make(), PEAKS.get(sound_name, 0.8))
