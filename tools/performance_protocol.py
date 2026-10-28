#!/usr/bin/env python3
"""Независимо пересчитывает фиксированное окно по реальным callback timestamp; пропуски не превращает в0 FPS."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re

from common.paths import project_root
from common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
PLAN = ROOT / "docs/reports/visual-overhaul/vfoliage-006/ci-performance/plan.json"
PREFIX = "PERF_CAPTURE "
ENGINE = "a13da4feb8d8aefc283c3763d33a2f170a18d541"
ANSI_ESCAPE = re.compile(
    r"(?:\x1b\[|\x9b)[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b\r\n]*(?:\x07|\x1b\\)"
)


class MeasurementError(ValueError):
    """Отличает отсутствующее/повреждённое измерение от настоящего результата ниже бюджета."""


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def policy() -> dict:
    """Не позволяет незаметно сократить окно, убрать повтор или понизить бюджет."""
    data = json.loads(PLAN.read_text())
    wanted = {
        "minimum_fps": 50,
        "headless_cap_after_startup": 60,
        "warmup_usec": 3_000_000,
        "window_usec": 10_000_000,
        "sample_usec": 1_000_000,
        "minimum_valid_samples": 10,
        "repeats_per_mode": 3,
        "seed": 21101986,
        "locale": "ru",
        "engine_hash": ENGINE,
        "modes": ["normal", "f10"],
    }
    if any(data.get(key) != value for key, value in wanted.items()):
        raise MeasurementError("invalid fixed performance policy")
    return data


def events(raw: bytes, returncode: int) -> list[dict]:
    """Сначала проверяет результат процесса и ошибки, затем читает все записи без отбрасывания повреждённых."""
    if returncode != 0:
        raise MeasurementError("process_error: " + str(returncode))
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise MeasurementError("invalid_utf8") from exc
    # Нормализуем только копию для поиска ошибок; raw/SHA и строки протокола остаются исходными.
    error_text = "\n".join(
        line.lstrip() for line in ANSI_ESCAPE.sub("", text).splitlines()
    )
    if re.search(r"^ERROR:|SCRIPT ERROR:|Parse Error", error_text, re.M):
        raise MeasurementError("engine_error")
    rows = []

    def unique_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result

    try:
        for line in text.splitlines():
            if line.startswith(PREFIX):
                row = json.loads(
                    line.removeprefix(PREFIX), object_pairs_hook=unique_pairs
                )
                if not isinstance(row, dict) or "kind" not in row:
                    raise ValueError("object/kind required")
                rows.append(row)
    except (ValueError, TypeError) as exc:
        raise MeasurementError("invalid_protocol_record") from exc
    if not rows:
        raise MeasurementError("missing_measurements: no sampler records")
    return rows


def integer(value: object) -> int:
    if type(value) is not int or value < 0:
        raise MeasurementError("invalid_integer_timestamp_or_count")
    return value


def _validate(raw: bytes, returncode: int, mode: str, expected: dict) -> dict:
    """Все десять интервалов пересчитываются из timestamp; настоящие нулевые/медленные интервалы учитываются."""
    plan = policy()
    if set(expected) != {"sampler_sha256", "scene_sha256", "plan_sha256"}:
        raise MeasurementError("invalid_expected_identity_keys")
    if any(not re.fullmatch(r"[a-f0-9]{64}", value) for value in expected.values()):
        raise MeasurementError("invalid_expected_fingerprint")
    rows = events(raw, returncode)
    kinds = [r["kind"] for r in rows]
    if (
        kinds.count("ready") != 1
        or kinds.count("begin") != 1
        or kinds.count("end") != 1
    ):
        raise MeasurementError("missing_or_duplicate_window_markers")
    if any(k not in ["ready", "begin", "frame", "sample", "end"] for k in kinds):
        raise MeasurementError("unknown_record_or_sampler_error")
    ready, begin, end = rows[0], rows[1], rows[-1]
    if [ready["kind"], begin["kind"], end["kind"]] != ["ready", "begin", "end"]:
        raise MeasurementError("invalid_record_order")
    config = {
        "purpose": "fixed_window_headless_gate",
        "schema": 1,
        "mode": mode,
        "autoplay": True,
        "debug": mode == "f10",
        "cap_after": 60,
        "display": "headless",
        "engine_hash": ENGINE,
        "warmup_us": 3_000_000,
        "window_us": 10_000_000,
        "sample_us": 1_000_000,
        "minimum_samples": 10,
        "seed": plan["seed"],
        "locale": plan["locale"],
        **expected,
    }
    if mode not in plan["modes"] or any(
        ready.get(k) != v or type(ready.get(k)) is not type(v)
        for k, v in config.items()
    ):
        raise MeasurementError("effective_configuration_differs")
    if not re.fullmatch(r"Codex-Performance-[a-f0-9]{32}", ready.get("profile", "")):
        raise MeasurementError("invalid_isolated_profile")
    integer(ready["cap_before"])
    integer(ready["startup_us"])
    for key in ["player", "camera"]:
        if len(ready[key]) != 2 or any(
            type(value) not in [int, float] or not math.isfinite(value)
            for value in ready[key]
        ):
            raise MeasurementError("invalid_initial_route_coordinates")
    start = integer(begin["time_us"])
    if start - integer(ready["time_us"]) < plan["warmup_usec"]:
        raise MeasurementError("warmup_too_short")
    stop = start + plan["window_usec"]
    if integer(end["time_us"]) < stop or end["window_us"] != plan["window_usec"]:
        raise MeasurementError("window_too_short")
    frames = [r for r in rows if r["kind"] == "frame"]
    samples = [r for r in rows if r["kind"] == "sample"]
    if len(samples) != 10 or not frames:
        raise MeasurementError("missing_complete_samples_or_closing_callback")
    if kinds != ["ready", "begin"] + ["frame"] * len(frames) + ["sample"] * 10 + [
        "end"
    ]:
        raise MeasurementError("invalid_record_order")
    counts = [0] * 10
    last_time, last_frame, last_engine = start, integer(begin["frame"]), -1
    for frame in frames:
        now, number = integer(frame["time_us"]), integer(frame["frame"])
        engine_frame = integer(frame["engine_frame"])
        if now <= last_time or number != last_frame + 1 or engine_frame <= last_engine:
            raise MeasurementError("non_monotonic_or_missing_callbacks")
        if frame["cap"] != 60:
            raise MeasurementError("effective_cap_changed")
        if now < stop:
            counts[(now - start) // plan["sample_usec"]] += 1
        last_time, last_frame, last_engine = now, number, engine_frame
    if last_time != end["time_us"] or last_frame != end["frame"]:
        raise MeasurementError("closing_callback_differs")
    if any(frame["time_us"] >= stop for frame in frames[:-1]):
        raise MeasurementError("continued_after_closed_window")
    for index, sample in enumerate(samples):
        if (
            integer(sample["index"]) != index
            or integer(sample["start_us"]) != start + index * plan["sample_usec"]
            or integer(sample["duration_us"]) != plan["sample_usec"]
            or integer(sample["frames"]) != counts[index]
            or type(sample["fps"]) not in [int, float]
            or not math.isfinite(float(sample["fps"]))
            or sample["fps"] != counts[index]
        ):
            raise MeasurementError("sample_differs_from_real_callbacks")
    count = sum(counts)
    if integer(end["window_frames"]) != count:
        raise MeasurementError("total_differs_from_raw_callbacks")
    passed = count * 1_000_000 >= plan["minimum_fps"] * plan["window_usec"]
    return {
        "mode": mode,
        "valid": True,
        "budget_passed": passed,
        "status": "passed" if passed else "budget_exceeded",
        "average_fps": count * 1_000_000 / plan["window_usec"],
        "minimum_fps": plan["minimum_fps"],
        "samples": counts,
        "window_us": plan["window_usec"],
        "actual_close_us": end["time_us"] - start,
        "window_frames": count,
        "profile": ready["profile"],
        "cap_before": ready["cap_before"],
        "cap_after": ready["cap_after"],
        "startup_us": ready["startup_us"],
    }


def validate(raw: bytes, returncode: int, mode: str, expected: dict) -> dict:
    """Любая утрата полей или неверный тип имеет явный invalid-результат, а не вычисленный FPS."""
    try:
        return _validate(raw, returncode, mode, expected)
    except MeasurementError:
        raise
    except (KeyError, TypeError, ValueError, IndexError) as exc:
        raise MeasurementError("invalid_measurement_fields: " + str(exc)) from exc
