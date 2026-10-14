"""Проверяет выбранную партию удаления; отсутствие текстовой ссылки само по себе не разрешает удаление."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "docs/reports/sprite-cleanup-2026-10-14"
TEXT_EXTENSIONS = {".gd", ".py", ".sh", ".mjs", ".js", ".ts", ".vue", ".json", ".md", ".tres", ".tscn", ".cfg", ".godot", ".txt", ".html"}
QUOTED_PATH = re.compile(r'''["'`]((?:res://)?assets/[^"'`\n]+\.(?:png|jpg|jpeg|webp|tres))['"`]''')
FORMAT_SLOT = re.compile(r"\$?\{[^{}\n]*\}|%(?:\([^)]+\))?[-+ #0]*\d*(?:\.\d+)?[sdiufxX]")


def source_texts(root):
    """Читает игровые потребители, Wiki, тесты и локальные сборщики; исторические отчёты не являются загрузчиками."""
    names = subprocess.check_output(["git", "-C", str(root), "ls-files", "-z"], text=True).split("\0")
    names += [str(p.relative_to(root)) for p in (root/"tools").glob("*") if p.is_file()]
    result = {}
    for name in sorted(set(names)):
        path = root/name
        if path.suffix not in TEXT_EXTENSIONS or name.startswith(("docs/reports/", "wiki/public/generated/")) or not path.is_file():
            continue
        if path.stat().st_size > 5_000_000:
            continue
        try:
            result[name] = path.read_text()
        except UnicodeError:
            continue
    return result


def protected_paths(usage):
    """Объединяет реально загруженные ресурсы, динамический редактор и оба размера предметных иконок."""
    result = set(usage.get("loaded", [])) | set(usage.get("editor", [])) | set(usage.get("dynamic", []))
    for pose in usage.get("poses", {}).values():
        for key in ["texture", "atlas"]:
            if pose.get(key): result.add(pose[key].removeprefix("res://"))
    return result


def formatted_references(sources):
    """Сохраняет семейства форматных путей к ресурсам в игре, тестах и Wiki; инструменты записи требуют ручного разбора."""
    result = {}
    for source, text in sources.items():
        if not source.startswith(("scripts/", "tests/", "wiki/")):
            continue
        patterns = []
        for match in QUOTED_PATH.finditer(text):
            path = match.group(1).removeprefix("res://")
            if not FORMAT_SLOT.search(path):
                continue
            chunks = FORMAT_SLOT.split(path)
            patterns.append(re.compile("[^/]*".join(re.escape(chunk) for chunk in chunks)))
        if patterns:
            result[source] = patterns
    return result


def validate(root, manifest, usage, sources, phase="after"):
    """Запрещает живые ссылки, выход за assets, подмену файла и незавершённое удаление со служебным import."""
    errors = []
    protected = protected_paths(usage)
    formatted = formatted_references(sources)
    for entry in manifest.get("reserved_legacy_png", []) + manifest.get("reserved_test_previews", []):
        protected.add(entry["path"])
        if not (root/entry["path"]).is_file():
            errors.append("required_missing:"+entry["path"])
    seen = set()
    for entry in manifest["removed"]:
        name = entry["path"]
        path = root/name
        if name in seen:
            errors.append("duplicate:"+name)
        seen.add(name)
        if not name.startswith("assets/") or not path.resolve().is_relative_to((root/"assets").resolve()) or path.is_symlink():
            errors.append("unsafe_path:"+name); continue
        if name in protected:
            errors.append("live_dynamic:"+name)
        for source, text in sources.items():
            if name in text or Path(name).name in text:
                errors.append("reference:"+source+":"+name)
        for source, patterns in formatted.items():
            if any(pattern.fullmatch(name) for pattern in patterns):
                errors.append("formatted_reference:"+source+":"+name)
        if phase == "before":
            if not path.is_file():
                errors.append("missing_before:"+name); continue
            if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"] or path.stat().st_size != entry["bytes"]:
                errors.append("changed_file:"+name)
        elif path.exists() or Path(str(path)+".import").exists():
            errors.append("retired_file_returned:"+name)
    return errors


def main():
    """Проверяет утверждённую партию и оставляет удаление явной отдельной операцией Git."""
    parser = argparse.ArgumentParser(); parser.add_argument("--phase", choices=["before","after"], default="after")
    args = parser.parse_args()
    manifest = json.loads((REPORT/"removed.json").read_text())
    usage = json.loads((REPORT/"usage-before.json").read_text())
    errors = validate(ROOT, manifest, usage, source_texts(ROOT), args.phase)
    for error in errors: print("SPRITE CLEANUP: "+error)
    if errors: return 1
    print(f"SPRITE CLEANUP: {len(manifest['removed'])} retired resources; dynamic paths and consumers preserved")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
