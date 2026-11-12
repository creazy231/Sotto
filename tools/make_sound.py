"""Synthesise Sotto's notification chime: two soft bell notes (C6, then E6).

Usage: python3 -I tools/make_sound.py <addon-folder>
Writes Media/Sounds/chime.ogg (Vorbis, via ffmpeg). Pure Python synthesis,
no samples from anywhere else.
"""
import math
import os
import struct
import subprocess
import sys
import tempfile
import wave

RATE = 44100


def bell(freq, start, length, amp, total):
    """Additive bell: fundamental plus soft partials, fast attack, exponential decay."""
    partials = [(1.0, 1.0, 0.42), (2.0, 0.28, 0.24), (3.01, 0.08, 0.16), (4.2, 0.03, 0.10)]
    out = [0.0] * total
    s0 = int(start * RATE)
    n = int(length * RATE)
    attack = int(0.006 * RATE)
    for i in range(n):
        j = s0 + i
        if j >= total:
            break
        t = i / RATE
        env = (i / attack) if i < attack else 1.0
        v = 0.0
        for mult, a, tau in partials:
            v += a * math.exp(-t / tau) * math.sin(2 * math.pi * freq * mult * t)
        out[j] += amp * env * v
    return out


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    total = int(1.0 * RATE)
    a = bell(1046.50, 0.00, 0.9, 0.55, total)   # C6
    b = bell(1318.51, 0.11, 0.85, 0.50, total)  # E6
    mix = [x + y for x, y in zip(a, b)]
    peak = max(abs(x) for x in mix) or 1.0
    gain = 0.45 / peak                          # about -7 dBFS: calm, not loud
    fade = int(0.08 * RATE)
    frames = bytearray()
    for i, x in enumerate(mix):
        if i > total - fade:
            x *= (total - i) / fade
        frames += struct.pack("<h", int(max(-1.0, min(1.0, x * gain)) * 32767))

    out_dir = os.path.join(root, "Media", "Sounds")
    os.makedirs(out_dir, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "chime.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(bytes(frames))
        ogg = os.path.join(out_dir, "chime.ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "vorbis", "-strict", "-2",
                        "-ac", "2", "-b:a", "96k", ogg], check=True)
    print("wrote", ogg)


if __name__ == "__main__":
    main()
