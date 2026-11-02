"""Create deterministic, original offline ambient loops for Open Voice.

Requires numpy. Run from the repository root:
    python3 Tools/generate_soundscapes.py
"""

from pathlib import Path
import wave

import numpy as np


RATE = 22_050
LOOP_SECONDS = 16
FADE_SECONDS = 2
OUTPUT = Path(__file__).resolve().parents[1] / "Resources" / "Soundscapes"


def shaped_noise(rng: np.random.Generator, count: int, cutoff: float, highpass: float = 0) -> np.ndarray:
    white = rng.normal(size=count)
    spectrum = np.fft.rfft(white)
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    gain = 1 / (1 + (frequencies / cutoff) ** 2)
    if highpass:
        gain *= 1 - 1 / (1 + (frequencies / highpass) ** 2)
    sound = np.fft.irfft(spectrum * gain, n=count)
    return sound / (np.std(sound) + 1e-12)


def loop_seam(sound: np.ndarray) -> np.ndarray:
    loop_frames = LOOP_SECONDS * RATE
    fade_frames = FADE_SECONDS * RATE
    result = sound[:loop_frames].copy()
    mix = np.linspace(0, 1, fade_frames, endpoint=False)
    result[:fade_frames] = sound[loop_frames:loop_frames + fade_frames] * (1 - mix) + result[:fade_frames] * mix
    edge_frames = int(0.02 * RATE)
    edge_mix = np.linspace(0, 1, edge_frames)
    result[-edge_frames:] = result[-edge_frames:] * (1 - edge_mix) + result[0] * edge_mix
    return result


def save(name: str, sound: np.ndarray) -> None:
    sound = loop_seam(sound)
    sound -= np.mean(sound)
    sound *= 0.24 / max(np.max(np.abs(sound)), 1e-12)
    samples = np.asarray(np.round(sound * 32767), dtype="<i2")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(samples.tobytes())


def main() -> None:
    count = (LOOP_SECONDS + FADE_SECONDS) * RATE
    time = np.arange(count) / RATE

    rain_rng = np.random.default_rng(1042)
    rain = 0.65 * shaped_noise(rain_rng, count, 7000, highpass=700)
    rain += 0.28 * shaped_noise(rain_rng, count, 1700, highpass=250)
    rain *= 0.72 + 0.18 * np.sin(2 * np.pi * time / 5.2) ** 2
    for start in rain_rng.integers(0, count - int(0.12 * RATE), size=190):
        length = int(0.12 * RATE)
        local = np.arange(length) / RATE
        droplet = np.sin(2 * np.pi * (650 + 210 * local) * local) * np.exp(-42 * local)
        rain[start:start + length] += droplet * rain_rng.uniform(0.18, 0.35)
    save("Rain", rain)

    wave_rng = np.random.default_rng(2042)
    swell = (0.5 + 0.5 * np.sin(2 * np.pi * time / 7.8 - 1.0)) ** 2
    waves = shaped_noise(wave_rng, count, 650) * (0.18 + 0.75 * swell)
    waves += shaped_noise(wave_rng, count, 3200, highpass=900) * (0.08 + 0.24 * swell)
    save("Waves", waves)

    breeze_rng = np.random.default_rng(3042)
    gust = 0.35 + 0.38 * (0.5 + 0.5 * np.sin(2 * np.pi * time / 6.3))
    gust += 0.14 * np.sin(2 * np.pi * time / 2.9)
    breeze = shaped_noise(breeze_rng, count, 900) * gust
    breeze += shaped_noise(breeze_rng, count, 3000, highpass=750) * 0.07
    save("Breeze", breeze)


if __name__ == "__main__":
    main()
