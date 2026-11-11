#!/usr/bin/env python3
"""Brings the sound effects in assets/sounds/ to one consistent loudness (docs/sounds.md).

Each sound belongs to a tier (TIERS) with a target loudness: the loudest 400 ms of the
sound (EBU R128 maximum momentary loudness), measured as Godot plays it (mono on both
speakers, at volume 0 dB). A sound is turned up or down to its tier's target; if that
pushes its peak above PEAK_LIMIT, a limiter catches the peak. Sounds already within
TOLERANCE of their target are left alone, so running this again does not re-encode them.

    python3 tools/normalize_sounds.py            # report and fix
    python3 tools/normalize_sounds.py --check    # only report; exit code 1 if a sound is off

Needs ffmpeg. Standard library only.
"""

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SOUNDS = Path(__file__).resolve().parent.parent / "assets" / "sounds"

# Target maximum momentary loudness (LUFS) per tier. They sit between 15 and 20 LU above
# the music as it plays with the default settings (about -34.5 LUFS on average, -31 at
# its loudest; the music is kept low so the players can talk over it).
TIERS = {
    # Button clicks and taps: heard all the time, so they stay in the background.
    "ui": (-26.0, ["click", "select"]),
    # Cues and notices: someone has to act, a card was read, a message pops up.
    "cue": (-22.0, ["turn", "choose", "seat", "reveal", "card_scanned", "rejected", "round"]),
    # Hits that come in quick volleys (arrows, bolts, a shield counting down): they add up.
    "volley": (-21.0, ["magic_hit", "arrow_hit", "shield_block", "tack"]),
    # The fight's effects.
    "effect": (-19.0, ["hit", "slash", "slam", "shield_break", "shields_up", "poison", "protect",
                       "lightning", "heal", "hurt"]),
    # The big moments: the boss appears, attacks and dies, the fight is won or lost.
    "event": (-16.0, ["boss_appears", "boss_attack", "victory", "defeat", "fanfare", "boss_*"]),
}
PEAK_LIMIT = -1.0  # dBFS
TOLERANCE = 0.5  # LU
SILENT = -70.0  # LUFS: below this a sound counts as silent (a broken file)


def tier_of(name: str) -> tuple[str, float] | None:
    for tier, (target, names) in TIERS.items():
        for pattern in names:
            if name == pattern or (pattern.endswith("*") and name.startswith(pattern[:-1])):
                return tier, target
    return None


def measure(path: Path) -> tuple[float, float]:
    """(maximum momentary loudness in LUFS, sample peak in dBFS) as Godot plays it."""
    channels = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels",
         "-of", "csv=p=0", str(path)], capture_output=True, text=True, check=True).stdout.strip()
    upmix = "pan=stereo|c0=c0|c1=c0," if channels == "1" else ""
    # The padding gives a short sound a full 400 ms window.
    log = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-loglevel", "verbose", "-i", str(path),
         "-af", f"{upmix}apad=pad_dur=0.5,ebur128=peak=sample", "-f", "null", "-"],
        capture_output=True, text=True, check=True).stderr
    momentary = [float(m) for m in re.findall(r"\bM:\s*(-?\d+\.\d+)", log)]
    peak = re.search(r"Sample peak:\s*Peak:\s*(-?(?:\d+\.\d+|inf))", log)
    return max(momentary, default=-120.0), float(peak.group(1)) if peak else float("-inf")


def apply_gain(path: Path, gain: float, peak: float) -> None:
    rate = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=sample_rate",
         "-of", "csv=p=0", str(path)], capture_output=True, text=True, check=True).stdout.strip()
    filters = f"volume={gain:.2f}dB"
    if peak + gain > PEAK_LIMIT:
        limit = 10 ** (PEAK_LIMIT / 20)
        filters += f",alimiter=limit={limit:.4f}:level=disabled:attack=1:release=50"
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / path.name
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path), "-af", filters,
             "-ac", "1", "-ar", rate, "-c:a", "libvorbis", "-q:a", "5", str(out)], check=True)
        shutil.move(out, path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="only report, change nothing")
    args = parser.parse_args()

    off = 0
    for path in sorted(SOUNDS.glob("*.ogg")):
        name = path.stem
        tier = tier_of(name)
        loudness, peak = measure(path)
        if tier is None:
            print(f"{name:32} {loudness:6.1f} LUFS  NO TIER: add it to TIERS")
            off += 1
            continue
        tier_name, target = tier
        line = f"{name:32} {loudness:6.1f} LUFS  peak {peak:5.1f}  {tier_name:6} {target:5.1f}"
        if loudness < SILENT:
            print(f"{line}  SILENT: the file has no sound")
            off += 1
            continue
        gain = target - loudness
        if abs(gain) <= TOLERANCE:
            print(f"{line}  ok")
            continue
        off += 1
        if args.check:
            print(f"{line}  off by {-gain:+.1f}")
            continue
        apply_gain(path, gain, peak)
        loudness, peak = measure(path)
        print(f"{line}  {gain:+.1f} dB -> {loudness:6.1f} LUFS, peak {peak:5.1f}")
    return 1 if args.check and off else 0


if __name__ == "__main__":
    sys.exit(main())
