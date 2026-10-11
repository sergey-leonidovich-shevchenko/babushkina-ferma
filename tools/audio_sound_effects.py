"""Мягкие предметные эффекты: дерево, земля, воздух и короткие музыкальные подтверждения."""

import math

import numpy as np

from audio_composer import AUDIO, RATE, ROOT, voice, write_wave


# Ограничивает полосу шума; локальный seed делает материал воспроизводимым между сборками.
def soft_noise(length: int, seed: int, cutoff: float = 1800.0) -> np.ndarray:
    noise = np.random.default_rng(seed).normal(0, 1, length)
    spectrum = np.fft.rfft(noise)
    hz = np.fft.rfftfreq(length, 1 / RATE)
    spectrum *= np.exp(-(hz / cutoff) ** 4)
    result = np.fft.irfft(spectrum, n=length)
    return result / max(float(np.std(result)), 1e-9)


# Смягчает начало и конец и задаёт именно целевой запас эффекта, а не максимальную цифровую громкость.
def master_effect(samples: np.ndarray, peak_db: float, attack: float = 0.016) -> np.ndarray:
    samples = samples.copy()
    time = np.arange(len(samples)) / RATE
    samples -= np.mean(samples)
    contour = np.minimum(time / attack, 1) * np.minimum((len(samples) / RATE - time) / 0.065, 1)
    samples *= contour
    samples -= np.mean(samples) * contour / max(float(np.mean(contour)), 1e-9)
    gain = 10 ** (peak_db / 20) / max(float(np.max(np.abs(samples))), 1e-9)
    samples *= gain
    samples[0] = samples[-1] = 0
    return samples


# Пишет эффект и возвращает тот же мастер для честного файла прослушивания.
def save_effect(name: str, samples: np.ndarray, peak_db: float, attack: float = 0.016) -> np.ndarray:
    mastered = master_effect(samples, peak_db, attack)
    write_wave(AUDIO / "sfx" / f"{name}.wav", mastered)
    return mastered


# Синтезирует тихое трение деревянной двери: низкие петли, плавный скрип и приглушённая защёлка.
def wooden_door(closing: bool = False) -> np.ndarray:
    duration = 1.05 if closing else 1.28
    time = np.arange(round(duration * RATE)) / RATE
    base = 235 + (70 if closing else -55) * time / duration + 9 * np.sin(math.tau * 2.4 * time)
    phase = math.tau * np.cumsum(base) / RATE
    friction = 0.64 + 0.20 * np.sin(math.tau * 7.3 * time) + 0.09 * np.sin(math.tau * 12.8 * time)
    contour = np.sin(math.pi * np.clip(time / duration, 0, 1)) ** 1.4
    creak = (np.sin(phase) + 0.26 * np.sin(phase * 2) + 0.065 * np.sin(phase * 3)) * friction
    samples = (creak * 0.26 + soft_noise(len(time), 281 if closing else 280, 1150) * 0.035) * contour
    latch_time = duration - 0.23 if closing else 0.055
    local = np.maximum(time - latch_time, 0)
    latch = (np.sin(math.tau * 125 * local) + 0.27 * np.sin(math.tau * 310 * local)) * np.exp(-local * 30)
    latch *= np.clip(local / 0.018, 0, 1) * (time >= latch_time)
    return samples + latch * 0.11


# Собирает короткое подтверждение из отдельных созвучных нот вместо раздражающего частотного свиста.
def chime(name: str, notes: list[int], step: float, peak_db: float, duration: float = 0.46) -> None:
    samples = np.zeros(round((step * (len(notes) - 1) + duration) * RATE))
    for index, note in enumerate(notes):
        sound = voice(note, duration, "piano")
        begin = round(index * step * RATE)
        samples[begin:begin + len(sound)] += sound[:len(samples) - begin] * (1 - index * 0.035)
    save_effect(name, samples, peak_db)


# Формирует материальный контакт с тёплой резонансной основой и ограниченным высокочастотным шумом.
def material(name: str, hz: float, duration: float, noise_gain: float, peak_db: float, seed: int) -> None:
    time = np.arange(round(duration * RATE)) / RATE
    phase = math.tau * hz * (time - 0.16 * time * time / duration)
    tone = (np.sin(phase) + 0.18 * np.sin(phase * 2.7)) * np.exp(-time * 7 / duration)
    noise = soft_noise(len(time), seed, 1600) * np.exp(-time * 4 / duration)
    save_effect(name, tone * (1 - noise_gain) + noise * noise_gain, peak_db)


# Создаёт весь игровой набор без громких шагов и с более тихими интерфейсом и дверями.
def generate_effects() -> None:
    opening = save_effect("door_open", wooden_door(), -20.0, 0.025)
    closing = save_effect("door_close", wooden_door(True), -21.0, 0.025)
    for index, (name, hz, duration, noise, peak) in enumerate([
        ("hoe", 118, 0.28, 0.62, -14), ("mine", 310, 0.32, 0.23, -15),
        ("chop", 170, 0.30, 0.40, -14), ("attack", 105, 0.27, 0.91, -17),
        ("hit", 98, 0.23, 0.31, -15), ("water", 320, 0.65, 0.96, -20),
        ("fish_cast", 280, 0.46, 0.94, -20), ("plant", 175, 0.23, 0.72, -21),
        ("ui_open", 230, 0.23, 0.42, -22), ("ui_press", 190, 0.16, 0.28, -23),
        ("ui_back", 160, 0.23, 0.34, -23), ("ui_focus", 310, 0.10, 0.18, -27),
    ]):
        material(name, hz, duration, noise, peak, 90 + index)
    for name, notes, step, peak, duration in [
        ("harvest", [64, 67, 71], 0.07, -18, 0.45), ("defeat", [59, 55], 0.13, -18, 0.48),
        ("fish_bite", [74, 78], 0.08, -17, 0.30), ("fish_catch", [67, 71, 74], 0.13, -17, 0.62),
        ("pickup", [71, 74], 0.055, -21, 0.30), ("craft", [62, 66, 69], 0.10, -18, 0.48),
        ("coin", [78, 81], 0.055, -22, 0.29), ("quest_accept", [62, 66, 69], 0.13, -18, 0.55),
        ("quest_complete", [62, 66, 69, 74], 0.17, -16, 0.95),
        ("level_up", [67, 71, 74, 79], 0.17, -16, 0.91),
        ("travel", [62, 69], 0.17, -22, 0.73),
    ]:
        chime(name, notes, step, peak, duration)
    # Тишина между открытиями позволяет оценить именно мягкость атаки, без маскирующей музыки.
    preview = np.concatenate((np.zeros(RATE // 3), opening, np.zeros(RATE), closing, np.zeros(RATE // 3)))
    # База эффектов −5 dB, поправка двери −3 dB, effects 90%, master 100% — без усиления для демонстрации.
    preview *= 10 ** (-8 / 20) * 0.9
    write_wave(ROOT / "docs/reports/door_audio_preview.wav", preview)
