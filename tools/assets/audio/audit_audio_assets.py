"""Проверяет экспортированные WAV: реальные отсчёты, запас пиков, RMS, DC, границы петли и спектр."""

import json
import hashlib
import math
import wave

import numpy as np

from tools.assets.audio.audio_composer import AUDIO, ROOT


# Преобразует линейную амплитуду в dBFS с конечным значением для цифровой тишины.
def db(value: float) -> float:
    return round(20 * math.log10(max(value, 1e-9)), 3)


# Измеряет PCM-файл без изменения его громкости; это sample peak/RMS, не выдуманный LUFS или true peak.
def measure(path) -> dict:
    with wave.open(str(path), "rb") as source:
        assert source.getsampwidth() == 2, f"Expected PCM16: {path}"
        rate, channels = source.getframerate(), source.getnchannels()
        samples = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2").astype(float).reshape(-1, channels) / 32768
    rms = float(np.sqrt(np.mean(samples ** 2)))
    peak = float(np.max(np.abs(samples)))
    # Частотный аудит коротких эффектов обнаруживает возврат широкополосного резкого щелчка.
    section = samples[:min(len(samples), rate * 2)].mean(axis=1)
    spectrum = np.abs(np.fft.rfft(section)) ** 2
    frequencies = np.fft.rfftfreq(len(section), 1 / rate)
    high_ratio = float(spectrum[frequencies > 5000].sum() / max(spectrum.sum(), 1e-12))
    return {"path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "seconds": round(len(samples) / rate, 3),
            "rate": rate, "channels": channels, "peak_dbfs": db(peak), "rms_dbfs": db(rms),
            "clipped_samples": int(np.count_nonzero(np.abs(samples) >= 32766 / 32768)),
            "dc_offset": round(float(np.max(np.abs(samples.mean(axis=0)))), 7),
            "loop_boundary_jump": round(float(np.max(np.abs(samples[0] - samples[-1]))), 7),
            "endpoint_peak": round(float(np.max(np.abs(samples[[0, -1]]))), 7),
            "energy_above_5khz_percent": round(high_ratio * 100, 5)}


# Запускает проверку всех действующих файлов; неиспользуемый старый step не входит в контракт игры.
def audit_library() -> dict:
    paths = sorted((AUDIO / "music").glob("*.wav")) + sorted(path for path in (AUDIO / "sfx").glob("*.wav") if path.stem != "step")
    records = [measure(path) for path in paths]
    failures = []
    for data in records:
        checks = {"no_clipping": data["clipped_samples"] == 0, "peak_headroom": data["peak_dbfs"] <= -8.9,
                  "clean_edges": data["endpoint_peak"] == 0, "dc_clean": data["dc_offset"] < 0.001,
                  "sample_rate": data["rate"] == 24000}
        if "/music/" in data["path"]:
            checks.update(stereo=data["channels"] == 2, long_loop=data["seconds"] >= 40,
                          comfortable_rms=-26 <= data["rms_dbfs"] <= -21.8, seamless=data["loop_boundary_jump"] == 0)
        if "door_" in data["path"]:
            checks.update(soft_door=data["peak_dbfs"] <= -19.9, no_shrill=data["energy_above_5khz_percent"] < 0.01)
        data["checks"] = checks
        failures.extend(f"{data['path']}: {name}" for name, ok in checks.items() if not ok)
    report = {"schema": 1, "method": "PCM16 sample peak/RMS/DC; not a loudness-meter LUFS claim",
              "files": records, "checks": sum(len(data["checks"]) for data in records), "failures": failures}
    report["preview_reference"] = {"master": 1.0, "music": 0.7, "effects": 0.9, "music_base_db": -6.0, "sfx_base_db": -5.0, "door_offset_db": -3.0}
    max_effect = max(10 ** (data["peak_dbfs"] / 20) for data in records if "/sfx/" in data["path"])
    max_music = max(10 ** (data["peak_dbfs"] / 20) for data in records if "/music/" in data["path"])
    report["conservative_full_mix_peak"] = round(6 * max_effect * 10 ** (-5 / 20) + math.sqrt(2) * max_music * 10 ** (-6 / 20), 5)
    assert report["conservative_full_mix_peak"] < 0.99, "Six effects and crossfading music exceed safe headroom"
    report["previews"] = [measure(ROOT / "docs/reports" / name) for name in ["audio_preview.wav", "door_audio_preview.wav"]]
    destination = ROOT / "docs/reports/audio_quality_audit.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"AUDIO AUDIT: {len(records)} files, {report['checks']} checks, {len(failures)} failures", flush=True)
    assert not failures, "\n".join(failures)
    return report


if __name__ == "__main__":
    audit_library()
