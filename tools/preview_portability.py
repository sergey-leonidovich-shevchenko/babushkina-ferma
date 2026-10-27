#!/usr/bin/env python3
"""Проверяет фиксированные RGBA/PNG и собирает одинаковый диагностический стенд двух ОС."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
from common.paths import project_root
from common.git import git_environment
import re
import subprocess
import sys

from PIL import Image
import PIL

ROOT = project_root(__file__)
FIXTURE = Path("tests/fixtures/preview_portability/manifest.json")
IDS = ("wood_dowel", "wax_candle", "compost", "fishing_bait")
LOCALES = ("ru", "en", "es", "de", "fr", "zh")
ENGINE_HASH = "a13da4feb8d8aefc283c3763d33a2f170a18d541"


def sha(data: bytes) -> str:
    """Хеширует переданные байты без повторного кодирования PNG."""
    return hashlib.sha256(data).hexdigest()


def path_under(root: Path, name: str) -> Path:
    """Не позволяет диагностическому manifest обращаться за пределы выбранного корня."""
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("path outside root")
    return path


def read(path: Path) -> dict:
    """Читает JSON с отказом при повторных ключах."""

    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate JSON key: " + key)
            result[key] = value
        return result

    return json.loads(path.read_text(), object_pairs_hook=pairs)


def pixels(path: Path) -> tuple[bytes, list[int], list[int]]:
    """Возвращает декодированные RGBA отдельно от хеша исходного PNG-файла."""
    with Image.open(path) as image:
        if image.format != "PNG" or image.mode != "RGBA":
            raise ValueError("expected RGBA PNG")
        bounds = image.getchannel("A").getbbox()
        if not bounds:
            raise ValueError("empty alpha")
        x, y, right, bottom = bounds
        return image.tobytes(), list(image.size), [x, y, right - x, bottom - y]


def validate_inputs(root: Path = ROOT) -> list[str]:
    """Сверяет настоящие файлы, сырой буфер до сериализации, альфу, bounds и прежний fitter."""
    errors = []
    try:
        manifest = read(root / FIXTURE)
        if (
            manifest["schema"] != 1
            or manifest["purpose"] != "fixed_inputs_for_diagnostics_not_acceptance"
        ):
            errors.append("invalid diagnostic input schema")
        if tuple(row["id"] for row in manifest["cases"]) != IDS:
            errors.append("missing or reordered fixed cases")
        if not re.fullmatch(r"[a-f0-9]{40}", manifest["origin_commit"]):
            errors.append("missing source revision")
        if (
            manifest["engine_release"] != "4.7.1-stable"
            or manifest["engine_hash"] != ENGINE_HASH
        ):
            errors.append("engine differs")
        if (
            sha(path_under(root, manifest["fitter_file"]).read_bytes())
            != manifest["fitter_sha256"]
        ):
            errors.append("fitter differs")
        for row in manifest["cases"]:
            source = path_under(root, row["source_file"])
            raw = path_under(root, row["source_rgba_file"]).read_bytes()
            reference = path_under(root, row["reference_file"])
            data, size, bounds = pixels(source)
            ref, ref_size, _ = pixels(reference)
            if sha(source.read_bytes()) != row["source_file_sha256"]:
                errors.append("source PNG file differs: " + row["id"])
            if data != raw or sha(raw) != row["source_rgba_sha256"]:
                errors.append("original raw RGBA differs: " + row["id"])
            if size != row["source_size"] or bounds != row["bounds"]:
                errors.append("source bounds/size differs: " + row["id"])
            if (
                sha(reference.read_bytes()) != row["reference_file_sha256"]
                or sha(ref) != row["reference_rgba_sha256"]
            ):
                errors.append("reference file/RGBA differs: " + row["id"])
            if ref_size != [160, 160] or row["size"] != 160 or row["padding"] != 8:
                errors.append("output geometry differs: " + row["id"])
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append("invalid fixed input: " + str(exc))
    return errors


def differences(actual: bytes, expected: bytes, width: int) -> dict:
    """Независимо пересчитывает каждый отличающийся канал, его координату и амплитуду."""
    samples = []
    count = maximum = 0
    for offset, (left, right) in enumerate(zip(actual, expected)):
        delta = abs(left - right)
        if not delta:
            continue
        count += 1
        maximum = max(maximum, delta)
        if len(samples) < 16:
            pixel = offset // 4
            samples.append(
                {
                    "offset": offset,
                    "x": pixel % width,
                    "y": pixel // width,
                    "channel": "rgba"[offset % 4],
                    "actual": left,
                    "expected": right,
                }
            )
    return {
        "actual_bytes": len(actual),
        "derived_bytes": len(expected),
        "differing_bytes": count,
        "max_delta": maximum,
        "samples": samples,
    }


def validate_report(folder: Path, root: Path = ROOT) -> list[str]:
    """Проверяет честность диагностики; отсутствие отличий не выдаётся за игровую приёмку."""
    errors = validate_inputs(root)
    try:
        manifest = read(root / FIXTURE)
        report = read(folder / "report.json")
        if (
            report["schema"] != 1
            or report["purpose"] != "diagnostics_only_not_acceptance"
        ):
            errors.append("diagnostics cannot claim acceptance")
        engine = report["engine"]
        if [
            engine["major"],
            engine["minor"],
            engine["patch"],
            engine["status"],
            engine["build"],
        ] != [4, 7, 1, "stable", "official"] or engine["hash"] != manifest[
            "engine_hash"
        ]:
            errors.append("wrong engine build")
        if report["os"] not in ["Linux", "macOS"] or report["architecture"] != "x86_64":
            errors.append("experiment requires matching x86_64 architecture")
        for key, name in [
            ("input_manifest_sha256", str(FIXTURE)),
            ("collector_sha256", "tools/preview_portability_capture.gd"),
            ("fitter_sha256", manifest["fitter_file"]),
        ]:
            if report[key] != sha(path_under(root, name).read_bytes()):
                errors.append("experiment source differs: " + key)
        if tuple(row["id"] for row in report["cases"]) != IDS:
            errors.append("diagnostic coverage differs")
        for row, entry in zip(report["cases"], manifest["cases"]):
            derived = path_under(folder, row["derived_file"])
            expected, size, _ = pixels(derived)
            actual, _, _ = pixels(path_under(root, entry["reference_file"]))
            if (
                size != [160, 160]
                or sha(derived.read_bytes()) != row["derived_file_sha256"]
                or sha(expected) != row["derived_rgba_sha256"]
            ):
                errors.append("derived file/RGBA differs: " + row["id"])
            for key in [
                "source_file_sha256",
                "source_rgba_sha256",
                "reference_file_sha256",
                "reference_rgba_sha256",
                "bounds",
                "size",
                "padding",
            ]:
                if row[key] != entry[key]:
                    errors.append("fixed input metadata differs: " + key)
            for key, value in differences(actual, expected, 160).items():
                if row[key] != value:
                    errors.append("recomputed difference differs: " + key)
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append("invalid diagnostic report: " + str(exc))
    return errors


def font_identity_is_valid(draw: dict) -> bool:
    """Сопоставляет реально выбранные шейпером гарнитуры с font RID, а не только с именем запроса ОС."""
    declared = set(zip(draw["families"], draw["styles"], draw["weights"]))
    used = [
        (face["family"], face["style"], face["weight"]) for face in draw["used_faces"]
    ]
    return bool(declared and used) and all(face in declared for face in used)


def validate_ui(folder: Path) -> list[str]:
    """Сверяет целые кадры, фактические callbacks, все локали, размер и максимальный масштаб реального HUD."""
    errors = []
    try:
        report = read(folder / "report.json")
        if (
            report["schema"] != 1
            or report["purpose"]
            != "real_hud_text_portability_not_hardware_or_fps_acceptance"
            or report["engine"]["hash"] != ENGINE_HASH
        ):
            errors.append("HUD capture cannot claim another purpose/build")
        if (
            report["errors"]
            or report["window"] != [1152, 648]
            or report["text_scale"] != 1.2
            or report["display"] == "headless"
        ):
            errors.append("invalid real HUD capture")
        audit = report["after_audit"]
        if (
            audit["failed"] != 0
            or audit["passed"] != audit["checks"]
            or audit["checks"] < 2200
            or audit["localization"]["locales"] != list(LOCALES)
            or audit["localization"]["text_scale"] != 1.2
        ):
            errors.append("complete UI audit did not pass unchanged contract")
        coverage = {(r["phase"], r["locale"], r["event"]) for r in report["cases"]}
        wanted = {
            ("production", loc, event)
            for loc in LOCALES
            for event in ["player_contact", "fertilizer"]
        }
        wanted |= {
            ("baseline_text", "ru", "player_contact"),
            ("baseline_text", "ru", "fertilizer"),
            ("baseline_text", "de", "player_contact"),
        }
        if coverage != wanted or len(report["cases"]) != 15:
            errors.append("HUD locale/event coverage differs")
        for row in report["cases"]:
            path = path_under(folder, row["frame"])
            data, size, _ = pixels(path)
            if (
                sha(path.read_bytes()) != row["file_sha256"]
                or sha(data) != row["rgba_sha256"]
                or size != [1152, 648]
                or row["image_size"] != size
            ):
                errors.append("frame file/RGBA differs: " + row["frame"])
            if (
                row["before"] != row["after"]
                or len(row["draws"]) != 4
                or len({draw["process_frame"] for draw in row["draws"]}) != 4
            ):
                errors.append("state or real callbacks differ: " + row["frame"])
            for draw in row["draws"]:
                if (
                    draw["text"] != row["text"]
                    or draw["position"] != [36, 152]
                    or draw["requested_size"] != 11
                    or [draw["width"], draw["height"], draw["max_lines"]]
                    != [268, 38, 3]
                    or not font_identity_is_valid(draw)
                    or len(draw["styles"]) != len(draw["families"])
                    or len(draw["weights"]) != len(draw["families"])
                ):
                    errors.append("HUD renderer/audit/font identity differs")
                if row["phase"] == "production" and (
                    draw["effective_size"] < 8
                    or draw["line_count"] > 3
                    or draw["measured"][1] > 38.1
                ):
                    errors.append("unreadable or clipped production text")
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append("invalid HUD capture: " + str(exc))
    return errors


def validate_catalogue(folder: Path, root: Path = ROOT) -> list[str]:
    """Проверяет реальные файлы/превью, оставляя вычисленные source/derived RGBA данными для отдельного ревью."""
    errors = []
    try:
        report = read(folder / "report.json")
        catalog = read(root / "assets/game/items/ui/catalog.json")["entries"]
        if (
            report["schema"] != 1
            or report["purpose"]
            != "catalogue_fingerprints_for_contract_review_not_acceptance"
            or report["engine"]["hash"] != ENGINE_HASH
        ):
            errors.append("invalid fingerprint purpose/build")
        if sorted(report["entries"]) != sorted(catalog):
            errors.append("fingerprint catalogue coverage differs")
        for name, digest in report["physical_source_files"].items():
            if (
                not name.startswith("res://")
                or sha(path_under(root, name.removeprefix("res://")).read_bytes())
                != digest
            ):
                errors.append("physical source file differs: " + name)
        different = []
        for kind, entry in report["entries"].items():
            path = root / "assets/game/items/ui/preview" / (kind + ".png")
            data, size, _ = pixels(path)
            if (
                sha(path.read_bytes()) != entry["preview_file_sha256"]
                or sha(data) != entry["preview_rgba_sha256"]
                or size != [160, 160]
            ):
                errors.append("actual preview file/RGBA differs: " + kind)
            if (
                entry["provider"] != catalog[kind]["provider"]
                or entry["tint"][:6] != catalog[kind]["tint"]
            ):
                errors.append("source identity/tint differs: " + kind)
            for key in [
                "source_rgba_sha256",
                "source_png_serialized_sha256",
                "derived_rgba_sha256",
            ]:
                if not re.fullmatch(r"[a-f0-9]{64}", entry[key]):
                    errors.append("missing exact fingerprint: " + kind + ":" + key)
            same = entry["preview_rgba_sha256"] == entry["derived_rgba_sha256"]
            if entry["same_rgba"] != same:
                errors.append("dishonest derived equality: " + kind)
            if not same:
                different.append(kind)
        if sorted(different) != report["different_ids"]:
            errors.append("derived difference coverage differs")
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append("invalid catalogue fingerprints: " + str(exc))
    return errors


def capture(output: Path, godot: str, ui: bool) -> None:
    """Запускает настоящий движок и сохраняет источники/логи эксперимента без изменения текущего гейта."""
    if output.exists():
        raise ValueError("fresh capture directory required")
    output.mkdir(parents=True)
    context = {
        "version": (ROOT / "VERSION").read_text().strip(),
        "source_revision_at_capture": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, env=git_environment(), text=True
        ).strip(),
        "tracked_worktree_changes": subprocess.check_output(
            ["git", "diff", "HEAD", "--name-only"], cwd=ROOT, env=git_environment(), text=True
        ).splitlines(),
        "workflow_revision": os.environ.get("GITHUB_SHA", ""),
        "engine_executable_file_sha256": sha(Path(godot).read_bytes()),
        "python": sys.version,
        "pillow": PIL.__version__,
        "platform": platform.platform(),
        "libc": list(platform.libc_ver()),
    }
    (output / "context.json").write_text(json.dumps(context, indent=2) + "\n")
    sources = {
        str(p.relative_to(ROOT)): sha(p.read_bytes())
        for p in (ROOT / "scripts").rglob("*.gd")
    }
    for name in [
        "project.godot",
        "tools/item_ui_fitter.gd",
        "tools/preview_portability_capture.gd",
        "tools/item_fingerprint_capture.gd",
        "tools/ui_portability_capture.gd",
        "tools/ui_portability_observer.gd",
        "assets/game/fonts/ui_font.tres",
    ]:
        sources[name] = sha((ROOT / name).read_bytes())
    (output / "sources.json").write_text(json.dumps(sources, indent=2) + "\n")
    stages = [("preview", ["--headless"], "preview_portability_capture.gd")]
    stages.append(("catalogue", ["--headless"], "item_fingerprint_capture.gd"))
    if ui:
        stages.append(
            (
                "ui",
                (
                    [
                        "--rendering-method",
                        "gl_compatibility",
                        "--audio-driver",
                        "Dummy",
                    ]
                    if sys.platform.startswith("linux")
                    else []
                ),
                "ui_portability_capture.gd",
            )
        )
    for name, flags, script in stages:
        command = [
            godot,
            *flags,
            "--path",
            str(ROOT),
            "--script",
            "res://tools/" + script,
            "--",
            "--output=" + str(output / name),
        ]
        with (output / (name + ".log")).open("w") as stream:
            result = subprocess.run(
                command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=180
            )
        log = (output / (name + ".log")).read_text()
        print(log)
        if result.returncode or re.search(r"^ERROR:|SCRIPT ERROR:", log, re.M):
            raise ValueError("capture failed: " + name)
        if name == "preview":
            errors = validate_report(output / name)
        elif name == "ui":
            errors = validate_ui(output / name)
        else:
            errors = validate_catalogue(output / name)
        if errors:
            raise ValueError(str(errors))


def main() -> None:
    """Проверяет входы либо собирает одинаковый эксперимент; диагностический успех не принимает старый byte-exact тест."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", type=Path)
    parser.add_argument(
        "--godot",
        default=os.environ.get(
            "FARM_GODOT_BIN", str(ROOT / "tools/Godot.app/Contents/MacOS/Godot")
        ),
    )
    parser.add_argument("--ui", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    if args.capture:
        capture(args.capture.resolve(), args.godot, args.ui)
        return
    errors = validate_report(args.report) if args.report else validate_inputs()
    if errors:
        raise SystemExit("\n".join(errors))
    print("PREVIEW INPUTS: exact files/RGBA/bounds valid; no export acceptance claimed")


if __name__ == "__main__":
    main()
