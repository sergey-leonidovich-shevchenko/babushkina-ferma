#!/usr/bin/env python3
"""Сверяет рассмотренный конечный реестр экспортов с реальными капсулами и игровыми файлами."""

from pathlib import Path
import json

from preview_portability import (
    ROOT,
    ENGINE_HASH,
    path_under,
    read,
    sha,
    pixels,
    validate_report,
)

MANIFEST = Path("tests/fixtures/item_export_contract/manifest.json")
EVIDENCE = Path("docs/reports/visual-overhaul/vfoliage-006/ci-repro")
FITTER_HASH = "47743787c4b31016690a8ccd9b9c886fe72b8b5312620f38510006c594aa6c7e"
PLATFORMS = ("macos-x64", "linux-x64")


def expected_entries(reports: list[dict]) -> dict:
    """Требует одинаковые исходники/эталоны и разрешает только реально записанные полные RGBA-результаты."""
    first, second = reports
    if first["physical_source_files"] != second["physical_source_files"]:
        raise ValueError("physical sources differ between platforms")
    if set(first["entries"]) != set(second["entries"]):
        raise ValueError("evidence coverage differs")
    result = {}
    for kind, entry in first["entries"].items():
        other = second["entries"][kind]
        excluded = {"derived_rgba_sha256", "same_rgba", "source_png_serialized_sha256"}
        identity = {key: value for key, value in entry.items() if key not in excluded}
        if identity != {
            key: value for key, value in other.items() if key not in excluded
        }:
            raise ValueError("source/reference identity differs: " + kind)
        identity["derived_rgba_sha256"] = sorted(
            {entry["derived_rgba_sha256"], other["derived_rgba_sha256"]}
        )
        result[kind] = identity
    return result


def resource_errors(root: Path, kind: str, entry: dict) -> list[str]:
    """Неизменный игровой PNG проверяется по файлу и RGBA независимо от известных экспортов движка."""
    errors = []
    path = path_under(root, "assets/game/items/ui/preview/" + kind + ".png")
    data, size, _ = pixels(path)
    if (
        size != [160, 160]
        or sha(path.read_bytes()) != entry["preview_file_sha256"]
        or sha(data) != entry["preview_rgba_sha256"]
    ):
        errors.append("actual preview file/RGBA differs: " + kind)
    return errors


def validate(root: Path = ROOT, manifest_path: Path | None = None) -> list[str]:
    """Сверяет предложение с двумя реальными CI-капсулами и всеми текущими игровыми файлами."""
    errors = []
    try:
        data = read(manifest_path or root / MANIFEST)
        if (
            data["schema"] != 1
            or data["purpose"] != "proposed_closed_exact_export_contract_pending_review"
            or data["engine_hash"] != ENGINE_HASH
            or data["fitter_sha256"] != FITTER_HASH
            or sha((root / "tools/item_ui_fitter.gd").read_bytes()) != FITTER_HASH
            or [data["size"], data["padding"]] != [160, 8]
        ):
            errors.append("proposal engine/fitter/geometry differs")
        wanted = {str(EVIDENCE / name / "catalogue/report.json") for name in PLATFORMS}
        if set(data["evidence"]) != wanted:
            errors.append("fixed evidence paths differ")
        reports = []
        probes = []
        for name in PLATFORMS:
            path = EVIDENCE / name / "catalogue/report.json"
            if sha((root / path).read_bytes()) != data["evidence"][str(path)]:
                errors.append("evidence file differs: " + name)
            report = read(root / path)
            if report["engine"]["hash"] != ENGINE_HASH:
                errors.append("evidence engine differs")
            reports.append(report)
            errors += validate_report(root / EVIDENCE / name / "preview", root)
            probes.append(read(root / EVIDENCE / name / "preview/report.json"))
        expected = expected_entries(reports)
        if data["entries"] != expected:
            errors.append("entries are not the finite evidenced outputs")
        catalogue = read(root / "assets/game/items/ui/catalog.json")
        if set(data["entries"]) != set(catalogue["entries"]):
            errors.append("complete canonical coverage differs")
        if data["physical_source_files"] != reports[0]["physical_source_files"]:
            errors.append("physical source coverage differs")
        for resource, digest in data["physical_source_files"].items():
            if not resource.startswith("res://"):
                raise ValueError("invalid resource path")
            if (
                sha(path_under(root, resource.removeprefix("res://")).read_bytes())
                != digest
            ):
                errors.append("source file differs: " + resource)
        for kind, entry in data["entries"].items():
            if entry["preview_rgba_sha256"] not in entry["derived_rgba_sha256"]:
                errors.append("reference was never directly reproduced: " + kind)
            errors += resource_errors(root, kind, entry)
            if len(entry["derived_rgba_sha256"]) > 1:
                for report, probe in zip(reports, probes):
                    rows = [row for row in probe["cases"] if row["id"] == kind]
                    if len(rows) != 1 or any(
                        rows[0][field] != report["entries"][kind][field]
                        for field in [
                            "source_rgba_sha256",
                            "derived_rgba_sha256",
                            "bounds",
                        ]
                    ):
                        errors.append(
                            "alternate lacks identical-input reproduction: " + kind
                        )
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append("invalid closed export proposal: " + str(exc))
    return errors


if __name__ == "__main__":
    problems = validate()
    if problems:
        raise SystemExit("\n".join(problems))
    print(
        "EXPORT CONTRACT: exact source/reference files and reviewed finite outputs valid"
    )
