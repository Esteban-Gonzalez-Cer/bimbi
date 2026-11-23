"""Render Bimbi's Focus chimes. No recordings or external libraries.

focus_done:   a rising, sparkling arpeggio with a shimmer tail for the end of a session.
focus_window: two soft bell notes between windows of a split session.
"""

from array import array
from math import exp, pi, sin
from pathlib import Path
import random
import sys
import wave

RATE = 24_000
DESTINATION = Path(__file__).resolve().parent.parent / "android/app/src/main/res/raw"


def bell(samples, start, frequency, seconds, level, partials=((1, 1), (2.0, 0.3), (3.01, 0.12), (4.2, 0.05))):
    offset = round(start * RATE)
    length = round(seconds * RATE)
    for index in range(length):
        if offset + index >= len(samples):
            break
        time = index / RATE
        attack = min(1.0, time / 0.006)
        envelope = attack * exp(-4.2 * time / seconds)
        samples[offset + index] += level * envelope * sum(
            gain * sin(2 * pi * frequency * multiple * time) for multiple, gain in partials
        )


def write(name, samples, peak):
    gain = peak * 32767 / max(map(abs, samples))
    pcm = array("h", (round(s * gain) for s in samples))
    if sys.byteorder == "big":
        pcm.byteswap()
    with wave.open(str(DESTINATION / f"{name}.wav"), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(pcm.tobytes())


def done():
    samples = [0.0] * round(RATE * 2.2)
    # C major arpeggio up two octaves, then a bright final chord.
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5, 1318.51, 1567.98)):
        bell(samples, 0.02 + i * 0.075, f, 0.9, 0.55 + i * 0.05)
    for f in (1046.5, 1318.51, 1567.98, 2093.0):
        bell(samples, 0.52, f, 1.6, 0.45)
    # Sparkles: short high pings scattered over the tail (fixed seed, same file every run).
    rng = random.Random(22)
    for _ in range(26):
        bell(samples, 0.5 + rng.random() * 1.2, rng.choice((2637.0, 3135.96, 3520.0, 4186.0)),
             0.18, 0.12 + rng.random() * 0.1, ((1, 1),))
    write("focus_done", samples, 0.8)


def window():
    samples = [0.0] * round(RATE * 1.2)
    bell(samples, 0.02, 659.25, 0.9, 0.8)
    bell(samples, 0.24, 987.77, 0.95, 0.7)
    write("focus_window", samples, 0.6)


if __name__ == "__main__":
    DESTINATION.mkdir(parents=True, exist_ok=True)
    done()
    window()
