"""Render Bimbi's bundled alarm loops. No recordings or external libraries."""

from array import array
from math import exp, pi, sin
from pathlib import Path
import sys
import wave


RATE = 24_000
DESTINATION = (
    Path(__file__).resolve().parent.parent / "android/app/src/main/res/raw"
)

# Each tone specifies the loop length, note length, harmonics, and notes.
TONES = {
    "dawn_chime": (
        3.0, 0.75, ((1, 1), (2, 0.14), (3, 0.05)),
        ((0.08, 440), (0.45, 554.37), (0.83, 659.25), (1.51, 880)),
    ),
    "soft_bells": (
        3.0, 0.8, ((1, 1), (2.76, 0.24), (4.07, 0.10)),
        ((0.06, 523.25), (0.66, 392), (1.29, 523.25), (1.74, 659.25)),
    ),
    "morning_pulse": (
        2.6, 0.33, ((1, 1), (2, 0.35), (3, 0.14)),
        ((0.06, 349.23), (0.40, 440), (0.75, 349.23), (1.10, 523.25), (1.60, 440)),
    ),
    # Plus tones (unlocked by a verified Plus or Premium pass).
    "sparkle_rise": (
        2.8, 0.42, ((1, 1), (2, 0.25), (4.01, 0.08)),
        ((0.04, 523.25), (0.30, 659.25), (0.56, 783.99), (0.82, 1046.5), (1.20, 1318.51), (1.58, 1046.5)),
    ),
    "lullaby_glow": (
        3.2, 0.9, ((1, 1), (2.0, 0.18), (3.0, 0.06)),
        ((0.06, 392.0), (0.72, 493.88), (1.38, 587.33), (2.04, 493.88)),
    ),
    "bright_signal": (
        2.6, 0.34, ((1, 1), (2, 0.32), (3, 0.22)),
        ((0.05, 698.46), (0.34, 880), (0.63, 698.46), (1.24, 698.46), (1.53, 880), (1.82, 987.77)),
    ),
}


def render(name, seconds, note_seconds, partials, notes):
    samples = [0.0] * round(RATE * seconds)
    length = round(RATE * note_seconds)
    for start, frequency in notes:
        offset = round(start * RATE)
        for index in range(length):
            time = index / RATE
            attack = min(1.0, time / 0.02)
            release = min(1.0, (length - index) / (RATE * 0.045))
            envelope = attack * release * exp(-2.5 * time / note_seconds)
            samples[offset + index] += envelope * sum(
                level * sin(2 * pi * frequency * multiple * time)
                for multiple, level in partials
            )
    gain = 0.78 * 32767 / max(map(abs, samples))
    pcm = array("h", (round(sample * gain) for sample in samples))
    if sys.byteorder == "big":
        pcm.byteswap()
    with wave.open(str(DESTINATION / f"alarm_{name}.wav"), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(pcm.tobytes())


if __name__ == "__main__":
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for tone, parameters in TONES.items():
        render(tone, *parameters)
