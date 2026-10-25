"""Историческое происхождение VFOLIAGE-010 и отдельная проверка текущего кандидата."""
from __future__ import annotations

from functools import lru_cache
import hashlib
from io import BytesIO
from pathlib import Path
import subprocess
import tarfile
import tempfile

from foliage_visibility_evidence import REPORT, ROOT, ROUTES, digest, read, require

BASE = "2fa58d3719ff89f6f61a755e531d963807762ae9"
EVIDENCE_COMMIT = "263b46f6f85bff382c863aa6d2061a16f1690eea"
REPORT_PATH = "docs/reports/visual-overhaul/vfoliage-010"
PLAN_SHA = "cf81cbce6d9f422a23af1e57ab2514465ca1bfb837725acf34e6f2b541f92528"
CAPSULE_SHA = "56727315cf46c5cf020033a2023f762870af57668c18d1870fbde55760d0f776"


@lru_cache(maxsize=4)
def pinned_file(name: str) -> bytes:
    """Читает неизменный опубликованный Git object, а не файл будущей рабочей копии."""
    return subprocess.check_output(
        ["git", "show", f"{EVIDENCE_COMMIT}:{REPORT_PATH}/{name}"],
        cwd=ROOT,
    )


@lru_cache(maxsize=1)
def base_sources() -> dict[str, str]:
    """Хеширует исходные production blobs из закреплённого base с ограниченной памятью."""
    tree = subprocess.check_output(
        ["git", "ls-tree", "-rz", BASE, "--", "scripts", "assets/game", "main.tscn"],
        cwd=ROOT,
    )
    entries = []
    for record in tree.split(b"\0"):
        if not record:
            continue
        header, name = record.split(b"\t", 1)
        mode, kind, oid = header.split()
        require(kind == b"blob" and mode in (b"100644", b"100755"), "base blob type")
        entries.append((name.decode(), oid.decode()))

    # Запросы идут по одному: запись всех OID разом может заблокироваться на pipe stdout.
    result = {}
    with tempfile.TemporaryFile() as error_log:
        process = subprocess.Popen(
            ["git", "cat-file", "--batch"],
            cwd=ROOT,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=error_log,
        )
        try:
            for name, oid in entries:
                process.stdin.write((oid + "\n").encode())
                process.stdin.flush()
                fields = process.stdout.readline().split()
                require(
                    len(fields) == 3
                    and fields[0].decode() == oid
                    and fields[1] == b"blob",
                    "base Git object unavailable: " + name,
                )
                remaining = int(fields[2])
                checksum = hashlib.sha256()
                while remaining:
                    chunk = process.stdout.read(min(remaining, 1024 * 1024))
                    require(bool(chunk), "truncated base Git object: " + name)
                    checksum.update(chunk)
                    remaining -= len(chunk)
                require(process.stdout.read(1) == b"\n", "invalid Git blob boundary")
                result[name] = checksum.hexdigest()
            process.stdin.close()
            require(process.wait(timeout=10) == 0, "historical Git read failed")
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)
            process.stdout.close()
            if not process.stdin.closed:
                process.stdin.close()
    require(bool(result), "historical Git base is empty")
    return result


def verify_capsule(plan: dict, report_dir: Path) -> None:
    """Сверяет целую капсулу с Git и каждый сохранённый исходник с его прежним SHA."""
    capsule_path = report_dir / "sources.tar.gz"
    require(
        digest(capsule_path) == CAPSULE_SHA
        and hashlib.sha256(pinned_file("sources.tar.gz")).hexdigest() == CAPSULE_SHA,
        "historical source capsule SHA",
    )
    expected = {
        name: checksum
        for name, checksum in plan["sources"].items()
        if not name.startswith("assets/")
    }
    with tarfile.open(fileobj=BytesIO(capsule_path.read_bytes())) as capsule:
        members = capsule.getmembers()
        require(
            len(members) == len(expected)
            and {member.name for member in members} == set(expected)
            and all(member.isfile() for member in members),
            "historical source capsule entries",
        )
        for member in members:
            contents = capsule.extractfile(member).read()
            require(
                hashlib.sha256(contents).hexdigest() == expected[member.name],
                "source capsule: " + member.name,
            )


def verify_history(root: Path, report_dir: Path = REPORT) -> tuple[dict, dict]:
    """Всегда проверяет происхождение архива; текущий VERSION и production здесь не читаются."""
    source = read(root / "source.json")
    plan = read(root / "plan-copy.json")
    require(
        source["task"] == plan["task"] == "VFOLIAGE-010" and source["complete"],
        "incomplete source",
    )
    require(digest(root / "plan-copy.json") == source["plan_sha256"], "plan SHA")
    require(
        digest(root / "plan-copy.json") == PLAN_SHA
        and digest(report_dir / "plan.json") == PLAN_SHA
        and hashlib.sha256(pinned_file("plan.json")).hexdigest() == PLAN_SHA,
        "historical plan SHA",
    )
    require(source["base_commit"] == plan["base_commit"] == BASE, "base identity")
    require(
        plan["widths"] == [1152, 1280]
        and plan["routes"] == list(ROUTES)
        and plan["frames"] == 36
        and plan["delta"] == 1 / 120
        and plan["steps_per_frame"] == 2
        and plan["travel"] == 126,
        "predeclared matrix",
    )
    verify_capsule(plan, report_dir)
    production = {
        name: checksum
        for name, checksum in plan["sources"].items()
        if name.startswith(("scripts/", "assets/game/")) or name == "main.tscn"
    }
    require(production == base_sources(), "historical Git base sources differ")
    return source, plan


def verify_current_candidate(plan: dict, candidate_root: Path = ROOT) -> int:
    """Отдельно запрещает выдавать старую съёмку за проверку изменённого текущего кандидата."""
    expected_production = {
        name
        for name in plan["sources"]
        if name.startswith(("scripts/", "assets/game/")) or name == "main.tscn"
    }
    if (candidate_root / ".git").exists():
        tracked = subprocess.check_output(
            ["git", "ls-files", "-z", "--", "scripts", "assets/game", "main.tscn"],
            cwd=candidate_root,
        )
        actual_production = {name.decode() for name in tracked.split(b"\0") if name}
    else:
        # Изолированная fixture не требует изменения Git worktree основной игры.
        actual_production = {
            str(path.relative_to(candidate_root))
            for folder in ("scripts", "assets/game")
            for path in (candidate_root / folder).rglob("*")
            if path.is_file()
        }
        if (candidate_root / "main.tscn").is_file():
            actual_production.add("main.tscn")
    require(
        actual_production == expected_production,
        "current candidate production inventory",
    )
    for name, expected in plan["sources"].items():
        path = candidate_root / name
        require(
            path.is_file() and digest(path) == expected,
            "current candidate source SHA: " + name,
        )
    return len(plan["sources"])
