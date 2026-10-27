"""Оригинальная партитура фермы: нейлоновые струны, мягкое фортепиано, флейта и камерный фон."""

from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np

from tools.common.paths import project_root

RATE = 24000
ROOT = project_root(__file__)
AUDIO = ROOT / "assets/game/audio"


# Переводит ноту MIDI в частоту равномерно темперированного строя.
def frequency(note: float) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


# Пишет PCM16 без автоматического повышения каждого тихого эффекта до максимума.
def write_wave(path: Path, samples: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    assert np.max(np.abs(samples)) < 0.99, f"Clipping before export: {path}"
    channels = 1 if samples.ndim == 1 else samples.shape[1]
    with wave.open(str(path), "wb") as output:
        output.setnchannels(channels)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(np.rint(samples * 32767).astype("<i2").tobytes())


# Создаёт мягкую акустическую огибающую без прямоугольной волны и частот выше Найквиста.
def voice(note: int, duration: float, instrument: str, velocity: float = 1.0) -> np.ndarray:
    time = np.arange(round(duration * RATE), dtype=np.float64) / RATE
    hz = frequency(note)
    wave_data = np.zeros(len(time))
    if instrument == "flute":
        phase = math.tau * hz * time + 0.017 * np.sin(math.tau * 4.4 * time)
        wave_data = np.sin(phase) + 0.12 * np.sin(2 * phase) + 0.026 * np.sin(3 * phase)
        contour = np.minimum(time / 0.14, 1) * np.minimum((duration - time) / 0.36, 1)
    elif instrument == "pad":
        for detune, gain in [(-0.0011, 0.29), (0.0, 0.34), (0.0013, 0.29)]:
            phase = math.tau * hz * (1 + detune) * time
            wave_data += gain * (np.sin(phase) + 0.13 * np.sin(phase * 2))
        contour = np.minimum(time / 0.65, 1) * np.minimum((duration - time) / 0.85, 1)
    else:
        piano = instrument == "piano"
        for harmonic in range(1, 8):
            if hz * harmonic >= RATE * 0.43:
                continue
            gain = (0.57 if piano else 0.67) ** (harmonic - 1) / harmonic
            decay = np.exp(-time * (0.75 + harmonic * (0.34 if piano else 0.52)))
            stiffness = math.sqrt(1 + 0.000035 * harmonic * harmonic) if piano else 1.0
            wave_data += gain * decay * np.sin(math.tau * hz * harmonic * stiffness * time)
        contour = np.minimum(time / (0.013 if piano else 0.021), 1) * np.minimum((duration - time) / 0.18, 1)
    return wave_data * np.maximum(contour, 0) * velocity


# Помещает звук по кругу композиции: хвост последнего такта продолжается через точку петли.
def place(buffer: np.ndarray, sound: np.ndarray, start: float, volume: float, pan: float = 0.0) -> None:
    begin = round(start * RATE) % len(buffer)
    stereo = sound[:, None] * np.array([math.sqrt((1 - pan) / 2), math.sqrt((1 + pan) / 2)]) * volume
    length = min(len(stereo), len(buffer))
    first = min(length, len(buffer) - begin)
    buffer[begin:begin + first] += stereo[:first]
    if first < length:
        buffer[:length - first] += stereo[first:length]


# Добавляет небольшую комнатную реверберацию без длинного мутного хвоста; отражения замкнуты в петлю.
def room(buffer: np.ndarray) -> np.ndarray:
    output = buffer.copy()
    for delay, gain in [(0.067, 0.11), (0.113, 0.08), (0.173, 0.065), (0.271, 0.038), (0.397, 0.018)]:
        reflected = np.roll(buffer, round(delay * RATE), axis=0)
        output += reflected[:, ::-1] * gain
    return output


# Выравнивает уровень темы, сохраняет запас по пикам и сглаживает только стык петли.
def master_music(buffer: np.ndarray) -> np.ndarray:
    output = room(buffer)
    output -= np.mean(output, axis=0)
    rms = max(float(np.sqrt(np.mean(output ** 2))), 1e-9)
    gain = min(10 ** (-22 / 20) / rms, 10 ** (-9 / 20) / float(np.max(np.abs(output))))
    output *= gain
    # 3 мс на краях устраняют дискретный щелчок без слышимой паузы.
    edge = round(RATE * 0.003)
    output[:edge] *= np.linspace(0, 1, edge)[:, None]
    output[-edge:] *= np.linspace(1, 0, edge)[:, None]
    return output


# Строит связную фразу из аккордов, а не одинаковых мажорных трезвучий на случайных ступенях.
def compose(name: str, chords: list[tuple[int, ...]], melody: list[list[tuple[float, int, float]]], bpm: int,
            meter: int, bars: int, instrument: str = "flute", tint: float = 1.0) -> np.ndarray:
    beat = 60 / bpm
    buffer = np.zeros((round(bars * meter * beat * RATE), 2))
    for bar in range(bars):
        chord = chords[bar % len(chords)]
        start = bar * meter * beat
        phrase = bar // len(chords)
        place(buffer, voice(chord[0] - 12, meter * beat + 0.25, "guitar"), start, 0.20, -0.08)
        for index, note in enumerate(chord[1:]):
            place(buffer, voice(note, meter * beat + 0.55, "pad"), start + index * 0.023, 0.033 * tint, (index - 1) * 0.28)
        pattern = [0, 2, 1, 3, 2, 1, 2, 3] if meter == 4 else [0, 2, 1, 3, 2, 1]
        for pulse, index in enumerate(pattern):
            note = chord[index % len(chord)]
            if phrase % 2 == 1 and pulse in (3, 5):
                continue
            volume = 0.11 if pulse % 2 == 0 else 0.078
            place(buffer, voice(note, beat * 2.3, "guitar"), start + pulse * beat / 2 + 0.012, volume, -0.24)
        for onset, note, beats in melody[bar % len(melody)]:
            if phrase % 4 == 2 and bar % 4 == 3:
                continue
            octave = 12 if instrument == "piano" and phrase % 4 == 3 else 0
            place(buffer, voice(note + octave, beats * beat, instrument), start + onset * beat + 0.025, 0.135, 0.19)
        if phrase % 2 == 1 and bar % 2 == 1:
            place(buffer, voice(chord[2] + 12, beat * 1.8, "piano"), start + (meter - 1) * beat, 0.055, 0.34)
    samples = master_music(buffer)
    write_wave(AUDIO / "music" / f"{name}.wav", samples)
    print(f"COMPOSED {name}: {len(samples) / RATE:.2f}s", flush=True)
    return samples


# Собирает восемь самостоятельных тем с общей палитрой и двумя длинными домашними композициями.
def compose_all() -> None:
    # D-dur / h-moll: домашний вальс с задумчивой серединой и открытой каденцией.
    home = [(50, 62, 66, 69), (47, 62, 66, 71), (43, 62, 67, 71), (45, 61, 64, 69),
            (50, 62, 66, 69), (54, 61, 66, 69), (43, 59, 62, 67), (45, 61, 64, 69)]
    home_melody = [[(0, 74, 1.8), (2, 69, 0.8)], [(0.5, 71, 1.4)], [(0, 74, 1), (1.5, 71, 1.2)],
                   [(0.5, 73, 1.6)], [(0, 69, 1), (1.5, 66, 1.2)], [(0.5, 69, 1.5)],
                   [(0, 67, 1.2), (1.5, 66, 0.9)], [(0, 64, 1.5)]]
    menu = compose("menu", home, home_melody, 72, 3, 32, "piano")
    # G-dur / e-moll: воздух между нотами и диалог флейты с нейлоновой струной.
    village_chords = [(43, 59, 62, 67), (50, 57, 62, 66), (40, 59, 64, 67), (48, 60, 64, 67),
                      (45, 60, 64, 69), (47, 59, 62, 67), (48, 60, 64, 67), (50, 57, 62, 66)]
    village_melody = [[(0.5, 71, 1.3), (2.4, 69, 1.1)], [(0.5, 66, 2.4)], [(0, 67, 1.2), (2, 71, 1.5)],
                      [(0.5, 72, 1.1), (2.3, 71, 1.1)], [(0, 69, 1.7)], [(0.5, 67, 1), (2.2, 62, 1.4)],
                      [(0.5, 64, 1.2), (2.2, 67, 1.0)], [(0, 66, 2.6)]]
    village = compose("village", village_chords, village_melody, 80, 4, 32)
    forest = [(45, 60, 64, 69), (43, 59, 62, 67), (41, 60, 65, 69), (43, 59, 62, 67)]
    forest_melody = [[(0.6, 72, 1.7)], [(0, 71, 1), (2, 67, 1.5)], [(1, 69, 2)], [(0, 67, 2.3)]]
    compose("forest", forest, forest_melody, 74, 4, 16)
    compose("rocky", village_chords, village_melody, 84, 4, 16, "piano", 0.7)
    minor = [(40, 59, 64, 67), (48, 60, 64, 67), (45, 60, 64, 69), (47, 59, 63, 66)]
    minor_melody = [[(0, 67, 1.7)], [(1, 64, 2)], [(0.5, 69, 1.7)], [(0.5, 66, 2)]]
    compose("cave", minor, minor_melody, 64, 4, 16, "piano", 1.2)
    compose("danger", minor, minor_melody, 92, 4, 16, "guitar", 0.65)
    compose("workshop", home, home_melody, 84, 3, 24, "piano", 0.65)
    compose("pirate", forest, forest_melody, 92, 4, 16, "guitar", 0.75)
    # Прослушивание реальных фрагментов тем с безопасными входом/выходом, а не отдельный мастер.
    preview = np.concatenate((menu[RATE * 10:RATE * 25].copy(), np.zeros((RATE, 2)), village[RATE * 16:RATE * 34].copy()))
    fade = np.linspace(0, 1, RATE)
    preview[:RATE] *= fade[:, None]
    preview[14 * RATE:15 * RATE] *= fade[::-1, None]
    preview[16 * RATE:17 * RATE] *= fade[:, None]
    preview[-RATE:] *= fade[::-1, None]
    # Честная громкость нового профиля игры: база −6 dB, music 70%, master 100%.
    preview *= 10 ** (-6 / 20) * 0.7
    write_wave(ROOT / "docs/reports/audio_preview.wav", preview)
