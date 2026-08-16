#!/usr/bin/env python3
"""Создаёт оригинальную ретро-музыку и звуковые эффекты для «Бабушкиной фермы»."""

from __future__ import annotations

import math
import random
import wave
from pathlib import Path

RATE = 11025
ROOT = Path(__file__).resolve().parents[1] / "assets" / "game" / "audio"


# Переводит номер ноты в частоту звука в герцах.
def midi(note: int) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


# Возвращает значение выбранной формы звуковой волны для текущей фазы.
def oscillator(phase: float, shape: str) -> float:
    if shape == "sine":
        return math.sin(phase)
    if shape == "triangle":
        return 2.0 / math.pi * math.asin(math.sin(phase))
    return 1.0 if math.sin(phase) >= 0.0 else -1.0


# Рассчитывает плавную огибающую атаки и затухания отдельной ноты.
def envelope(local: float, duration: float, attack: float = 0.025, release: float = 0.08) -> float:
    return min(local / attack, 1.0, max((duration - local) / release, 0.0))


# Добавляет синтезированную ноту в общий звуковой буфер с учётом громкости и огибающей.
def add_note(buffer: list[float], start: float, duration: float, note: int, volume: float, shape: str) -> None:
    begin = int(start * RATE)
    count = min(int(duration * RATE), len(buffer) - begin)
    frequency = midi(note)
    for offset in range(max(count, 0)):
        local = offset / RATE
        phase = math.tau * frequency * local
        sample = oscillator(phase, shape)
        if shape == "square":
            sample = sample * 0.82 + math.sin(phase * 2.0) * 0.18
        buffer[begin + offset] += sample * volume * envelope(local, duration)


# Добавляет воспроизводимый ударный акцент с локальным генератором случайного шума.
def add_percussion(buffer: list[float], beat: float, strong: bool, seed: int) -> None:
    rng = random.Random(seed)
    begin = int(beat * RATE)
    duration = 0.09 if strong else 0.045
    for offset in range(min(int(duration * RATE), len(buffer) - begin)):
        local = offset / RATE
        decay = math.exp(-local * (32.0 if strong else 48.0))
        tone = math.sin(math.tau * (72.0 - local * 280.0) * local) if strong else 0.0
        noise = rng.uniform(-1.0, 1.0)
        buffer[begin + offset] += (tone * 0.12 + noise * 0.055) * decay


# Нормализует отсчёты и записывает одноканальный звуковой файл в формате WAV.
def write_wave(path: Path, samples: list[float], target_peak: float = 0.88) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(max(abs(value) for value in samples), 0.001)
    scale = target_peak / peak
    frames = bytearray()
    for value in samples:
        integer = int(max(-1.0, min(1.0, value * scale)) * 32767)
        frames.extend(integer.to_bytes(2, "little", signed=True))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(frames)


# Собирает музыкальную тему из баса, аккордов, мелодии и ударных по заданному темпу.
def music(name: str, root: int, progression: list[int], melody: list[int | None], bpm: int, shape: str, seed: int) -> None:
    beat = 60.0 / bpm
    beats = 32
    samples = [0.0] * int(beats * beat * RATE)
    for index in range(beats):
        chord_root = root + progression[(index // 4) % len(progression)]
        add_note(samples, index * beat, beat * 0.92, chord_root - 12, 0.10, "triangle")
        if index % 2 == 0:
            add_note(samples, index * beat, beat * 1.82, chord_root, 0.045, "sine")
            add_note(samples, index * beat, beat * 1.82, chord_root + 7, 0.035, "sine")
        note = melody[index % len(melody)]
        if note is not None:
            add_note(samples, index * beat, beat * 0.78, root + note, 0.105, shape)
        add_percussion(samples, index * beat, index % 4 == 0, seed + index)
    write_wave(ROOT / "music" / f"{name}.wav", samples)


# Собирает длинную ненавязчивую тему без ударных: редкая мелодия лежит на мягких аккордах и спокойно замыкается в петлю.
def gentle_music(name: str, root: int, progression: list[int], melody: list[int | None], bpm: int) -> None:
    beat = 60.0 / bpm
    beats = len(progression) * 8
    samples = [0.0] * int(beats * beat * RATE)
    for phrase, interval in enumerate(progression):
        start = phrase * 8 * beat
        chord_root = root + interval
        for chord_note, volume in [(0, 0.038), (4, 0.026), (7, 0.031)]:
            add_note(samples, start, beat * 7.82, chord_root + chord_note, volume, "sine")
        for pulse in range(4):
            add_note(samples, start + pulse * beat * 2.0, beat * 1.72, chord_root - 12, 0.048, "triangle")
    for index in range(beats):
        note = melody[index % len(melody)]
        if note is None:
            continue
        duration = beat * (1.52 if index % 4 == 0 else 0.82)
        add_note(samples, index * beat, duration, root + note, 0.060, "triangle")
        add_note(samples, index * beat + 0.025, duration * 0.78, root + note + 12, 0.014, "sine")
    write_wave(ROOT / "music" / f"{name}.wav", samples, 0.52)


# Синтезирует короткий игровой эффект из меняющихся тонов и управляемого шума.
def sfx(name: str, duration: float, tones: list[tuple[float, float, float, str]], noise: float = 0.0, seed: int = 1) -> None:
    samples = [0.0] * int(duration * RATE)
    rng = random.Random(seed)
    for index in range(len(samples)):
        time = index / RATE
        fade = max(0.0, 1.0 - time / duration) ** 1.7
        value = rng.uniform(-1.0, 1.0) * noise * fade
        for start_hz, end_hz, volume, shape in tones:
            frequency = start_hz + (end_hz - start_hz) * time / duration
            value += oscillator(math.tau * frequency * time, shape) * volume * fade
        samples[index] = value
    write_wave(ROOT / "sfx" / f"{name}.wav", samples)


# Создаёт мягкий переходный колокольчик из отдельных нот без резкого шума и частотного скольжения.
def melodic_transition(name: str) -> None:
    duration = 0.82
    samples = [0.0] * int(duration * RATE)
    for index, note in enumerate([64, 67, 71, 76]):
        start = index * 0.13
        add_note(samples, start, 0.34, note, 0.11, "sine")
        add_note(samples, start + 0.018, 0.27, note + 12, 0.025, "triangle")
    add_note(samples, 0.39, 0.42, 52, 0.035, "sine")
    write_wave(ROOT / "sfx" / f"{name}.wav", samples, 0.48)


# Создаёт полный набор музыкальных тем локаций и звуков всех поддерживаемых действий.
def main() -> None:
    gentle_music("menu", 57, [0, 5, 9, 7, 0, 4], [12, None, None, 16, None, 19, None, None, 17, None, 14, None], 70)
    gentle_music("village", 55, [0, 5, 9, 7, 0, 4, 5, 7], [12, None, 16, None, None, 19, None, 16, 14, None, None, 12, None, 9, None, 11], 76)
    music("forest", 57, [0, 3, 7, 5], [12, None, 15, 19, 17, 15, 10, None], 96, "sine", 20)
    music("rocky", 50, [0, 5, 2, 7], [12, 12, 15, 14, 10, 12, 7, 10], 104, "triangle", 30)
    music("cave", 45, [0, 1, 5, 3], [12, None, 13, None, 19, 18, 13, None], 80, "sine", 40)
    music("danger", 46, [0, 1, 6, 3], [12, 13, 18, 13, 12, 10, 6, 7], 124, "square", 50)
    music("workshop", 55, [0, 7, 5, 9], [12, 19, 16, 14, 12, 14, 16, 21], 118, "triangle", 60)
    music("pirate", 50, [0, 5, 3, 7], [12, 12, 15, 17, 19, 17, 15, 10], 132, "square", 70)

    sfx("step", 0.09, [(105, 72, 0.14, "sine")], 0.10, 1)
    sfx("hoe", 0.18, [(125, 74, 0.22, "triangle")], 0.16, 2)
    sfx("plant", 0.20, [(440, 660, 0.12, "sine"), (660, 880, 0.06, "sine")], 0.02, 3)
    sfx("water", 0.38, [(520, 360, 0.05, "sine")], 0.14, 4)
    sfx("harvest", 0.30, [(660, 880, 0.13, "triangle"), (880, 1100, 0.06, "sine")], 0.02, 5)
    sfx("mine", 0.22, [(250, 140, 0.20, "triangle"), (980, 620, 0.08, "sine")], 0.10, 6)
    sfx("chop", 0.24, [(190, 105, 0.22, "triangle"), (410, 180, 0.08, "square")], 0.13, 21)
    sfx("attack", 0.18, [(540, 150, 0.18, "triangle")], 0.10, 7)
    sfx("hit", 0.16, [(180, 90, 0.24, "square")], 0.10, 8)
    sfx("defeat", 0.52, [(330, 82, 0.18, "triangle"), (220, 55, 0.12, "sine")], 0.04, 9)
    sfx("fish_cast", 0.32, [(720, 280, 0.08, "sine")], 0.12, 10)
    sfx("fish_bite", 0.25, [(880, 1320, 0.15, "square")], 0.03, 11)
    sfx("fish_catch", 0.46, [(520, 1040, 0.12, "triangle"), (780, 1560, 0.06, "sine")], 0.07, 12)
    sfx("pickup", 0.20, [(520, 920, 0.13, "triangle")], 0.02, 13)
    sfx("craft", 0.42, [(220, 330, 0.12, "triangle"), (660, 990, 0.10, "sine")], 0.06, 14)
    sfx("coin", 0.22, [(1040, 1480, 0.12, "sine")], 0.02, 15)
    sfx("quest_accept", 0.48, [(440, 660, 0.10, "triangle"), (550, 825, 0.07, "sine")], 0.0, 16)
    sfx("quest_complete", 0.85, [(523, 784, 0.11, "triangle"), (659, 988, 0.08, "sine")], 0.0, 17)
    sfx("level_up", 0.80, [(392, 1175, 0.11, "triangle"), (523, 1568, 0.07, "sine")], 0.0, 18)
    sfx("ui_open", 0.16, [(420, 620, 0.10, "square")], 0.0, 19)
    sfx("ui_focus", 0.085, [(610, 720, 0.055, "sine")], 0.0, 22)
    sfx("ui_press", 0.14, [(520, 390, 0.065, "triangle"), (780, 660, 0.025, "sine")], 0.0, 23)
    sfx("ui_back", 0.18, [(560, 360, 0.055, "sine")], 0.0, 24)
    melodic_transition("travel")


if __name__ == "__main__":
    main()
