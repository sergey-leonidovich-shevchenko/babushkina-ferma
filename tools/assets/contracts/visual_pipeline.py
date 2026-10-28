#!/usr/bin/env python3
"""Проверяет границу авторских файлов и импортируемых ресурсов, не удаляя ассеты."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from tools.common.paths import project_root
from tools.common.git import git_environment
from tools.assets.contracts.source_paths import current_source
from PIL import Image
from PIL import ImageChops

ROOT = project_root(__file__)
POLICY = "tools/visual_asset_policy.json"
REPORT = "docs/reports/visual-overhaul/vpipeline-001"
REFERENCES = re.compile(r'''["'](res://[^"']+)["']''')


def under(path: str, folder: str) -> bool:
    """Сравнивает целые компоненты пути, исключая совпадение похожих префиксов."""
    return path == folder or path.startswith(folder + "/")


def ignored(path: str, policy: dict) -> bool:
    """Определяет принадлежность авторскому или диагностическому дереву."""
    return any(under(path, folder) for folder in policy["non_runtime_roots"])


def validate(root: Path, policy: dict, files: list[str]) -> list[str]:
    """Проверяет барьеры, целостность изображений и статические ссылки живого проекта."""
    errors = []
    for folder in policy["non_runtime_roots"]:
        candidate = (root / folder).resolve()
        if not candidate.is_relative_to(root.resolve()) or folder in [".", ""]:
            errors.append(f"unsafe boundary: {folder}")
        elif not (candidate / ".gdignore").is_file():
            errors.append(f"missing .gdignore: {folder}")
    allowed = {(row["owner"], row["path"]) for row in policy["development_io"]}
    seen = set()
    for name in files:
        path = root / name
        if not path.is_file() or ignored(name, policy):
            continue
        runtime = any(under(name, folder) for folder in policy["runtime_roots"])
        if runtime:
            for parent in path.parents:
                if parent == root: break
                if (parent / ".gdignore").exists(): errors.append(f"runtime hidden by .gdignore: {name}"); break
            if path.suffix.lower() in [".png", ".webp"]:
                try:
                    with Image.open(path) as image: image.verify()
                except Exception as exc:
                    errors.append(f"invalid image: {name}: {exc}")
        if path.suffix not in [".gd", ".tscn", ".tres", ".godot", ".json"]:
            continue
        if not (name.startswith(("scripts/", "level_designs/")) or name in ["main.tscn", "project.godot"]):
            continue
        text = path.read_text(encoding="utf-8")
        for line in text.splitlines():
            if line.lstrip().startswith("#"): continue
            for ref in REFERENCES.findall(line):
                relative = ref.removeprefix("res://")
                if ".." in Path(relative).parts:
                    errors.append(f"unsafe resource path: {name}: {ref}"); continue
                if ignored(relative, policy):
                    key = (name, ref); seen.add(key)
                    resource_load = re.search(r"\b(?:load|preload)\s*\(", line)
                    if key not in allowed or resource_load or path.suffix != ".gd":
                        errors.append(f"non-runtime reference: {name}: {ref}")
                elif any(under(relative, folder) for folder in policy["runtime_roots"]):
                    if "%" not in relative and not (root / relative).exists():
                        errors.append(f"missing runtime resource: {name}: {ref}")
    for owner, ref in sorted(allowed - seen):
        errors.append(f"stale development I/O exception: {owner}: {ref}")
    return errors


def editor_textures(cache: Path) -> list[str]:
    """Читает диагностический индекс Godot 4.7; это не публичный формат и не runtime API."""
    rows, folder = [], ""
    for line in cache.read_text().splitlines()[1:]:
        if line.startswith("::res://"):
            folder = line.split("::")[1].removeprefix("res://")
        elif "::" in line:
            name, kind = line.split("::")[:2]
            if kind == "CompressedTexture2D": rows.append((Path(folder) / name).as_posix())
    if not rows: raise ValueError("empty/unknown editor cache; refresh using Godot 4.7 editor")
    return sorted(rows)


def runtime_hashes(root: Path, policy: dict, files: list[str]) -> dict:
    """Фиксирует байты игровых растров и импортных профилей для проверяемого сравнения."""
    return {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in sorted(files)
            if any(under(p, folder) for folder in policy["runtime_roots"]) and not ignored(p, policy)
            and Path(p).suffix in [".png", ".webp", ".import"] and (root / p).is_file()}


def quarantine(root: Path, policy: dict, files: list[str], tiles_only: bool = False) -> list[dict]:
    """Обратимо переносит только старые локальные превью корня с проверкой ссылок и коллизий."""
    candidates = sorted((root / "assets/game/tiles").glob("*_preview.png")) if tiles_only else sorted(
        p for p in root.glob("*.png") if re.fullmatch(r"(?:level_|showcase_).+\.png", p.name))
    candidates = [p for p in candidates if p.relative_to(root).as_posix() not in files]
    consumers = [root / p for p in files if Path(p).suffix in [".gd", ".tscn", ".tres", ".json", ".godot"]
                 and not ignored(p, policy) and (root / p).is_file()]
    text = "\n".join(p.read_text(encoding="utf-8") for p in consumers)
    moves = []
    for path in candidates:
        if "res://" + path.name in text: raise ValueError(f"preview still referenced: {path.name}")
        for source in [path, Path(str(path) + ".import")]:
            if not source.exists(): continue
            target = root / "assets/generated/legacy_root" / source.name
            if target.exists(): raise ValueError(f"refusing overwrite: {target}")
            moves.append({"from":source.relative_to(root).as_posix(), "to":target.relative_to(root).as_posix(),
                          "sha256":hashlib.sha256(source.read_bytes()).hexdigest()})
    for row in moves:
        target = root / row["to"]; target.parent.mkdir(parents=True, exist_ok=True)
        (root / row["from"]).rename(target)
    return moves


def verify_evidence(folder: Path) -> None:
    """Перепроверяет исторические нативные кадры без запрета будущих изменений игровой графики."""
    proof = json.loads((folder / "native-comparison.json").read_text())
    states, images = [], []
    for phase in ["before", "after"]:
        path = folder / "native" / phase / "village.png"
        if hashlib.sha256(path.read_bytes()).hexdigest() != proof["sha256"][phase]:
            raise ValueError(f"capture hash mismatch: {phase}")
        with Image.open(path) as source: images.append(source.convert("RGBA"))
        state = json.loads((path.parent / "capture.json").read_text())
        if state["errors"] or state["performance_eligible"] or state["framebuffer"] != [1152,648]:
            raise ValueError(f"invalid capture conditions: {phase}")
        states.append({k:v for k,v in state.items() if k != "profile"})
    if states[0] != states[1] or images[0].size != (1152,648) or images[1].size != (1152,648):
        raise ValueError("capture camera/configuration mismatch")
    if any(channel.getbbox() for channel in ImageChops.difference(*images).split()):
        raise ValueError("native pixels changed")
    if not proof["decoded_pixel_equal"] or proof["performance_eligible"]:
        raise ValueError("invalid comparison claim")


def main() -> None:
    """Запускает аудит; отдельные режимы сохраняют только явно запрошенные подтверждения."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--quarantine-root-previews", action="store_true")
    parser.add_argument("--quarantine-tile-previews", action="store_true")
    parser.add_argument("--record-after", action="store_true")
    args = parser.parse_args()
    policy = json.loads(current_source(ROOT, POLICY).read_text())
    files = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT, env=git_environment()).decode().split("\0")
    errors = validate(ROOT, policy, files)
    if errors: raise SystemExit("\n".join(errors))
    verify_evidence(ROOT / REPORT)
    if args.quarantine_root_previews:
        output = ROOT / REPORT / "local-preview-relocation.json"
        if output.exists(): raise SystemExit("relocation receipt already exists")
        output.write_text(json.dumps(quarantine(ROOT, policy, files), ensure_ascii=False, indent=2) + "\n")
    if args.quarantine_tile_previews:
        output = ROOT / REPORT / "local-tile-preview-relocation.json"
        if output.exists(): raise SystemExit("tile relocation receipt already exists")
        output.write_text(json.dumps(quarantine(ROOT, policy, files, True), ensure_ascii=False, indent=2) + "\n")
    if args.record_after:
        baseline = json.loads((ROOT / REPORT / "baseline.json").read_text())
        hashes = runtime_hashes(ROOT, policy, files)
        if hashes != baseline["runtime_sha256"]: raise SystemExit("runtime bytes/profiles changed")
        textures = editor_textures(ROOT / ".godot/editor/filesystem_cache10")
        leaked = [p for p in textures if ignored(p, policy)]
        if leaked: raise SystemExit("editor still imports non-runtime: " + str(leaked))
        data = {"engine":baseline["engine"], "base_commit":baseline["base_commit"], "runtime_files_unchanged":len(hashes),
                "editor_textures_before":baseline["editor_textures"], "editor_textures_after":len(textures),
                "classified_non_runtime_imports_before":len(baseline["non_runtime_imported"]), "non_runtime_imports_after":0,
                "untracked_indexed_textures":[p for p in textures if p not in files],
                "cache_format":"filesystem_cache10 (Godot 4.7 diagnostic only)", "performance_eligible":False}
        (ROOT / REPORT / "import-comparison.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        (ROOT / REPORT / "editor-textures-after.json").write_text(json.dumps(textures, indent=2) + "\n")
    print("VISUAL PIPELINE: boundaries, development I/O, runtime images and references valid")


if __name__ == "__main__": main()
