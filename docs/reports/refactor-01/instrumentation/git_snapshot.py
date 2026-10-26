"""Читает точный Git-снимок; не запускает код проекта и не меняет индекс."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile


def clean_git_environment() -> dict[str, str]:
    """Исключает унаследованные hook-переменные даже для вложенного read-only Git."""
    return {name: value for name, value in os.environ.items() if not name.startswith("GIT_")}


def project_root(start: Path) -> Path:
    """Ищет маркеры, а не предполагает фиксированную глубину файла или текущую cwd."""
    for candidate in (start, *start.parents):
        if (candidate / "project.godot").is_file() and (candidate / ".git").exists():
            return candidate
    raise ValueError("project.godot and .git root not found")


@dataclass(frozen=True)
class Blob:
    path: str
    oid: str
    size: int
    mode: str


class Snapshot:
    """Содержит только принятый commit; рабочая копия не подменяет исходную ведомость."""

    def __init__(self, root: Path, commit: str):
        if not re.fullmatch(r"[0-9a-f]{40}", commit):
            raise ValueError("an exact 40-character Git commit is required")
        self.root = root.resolve()
        self.commit = commit
        resolved = self.git("rev-parse", "--verify", commit + "^{commit}").decode().strip()
        if resolved != commit:
            raise ValueError("snapshot commit mismatch")
        self.blobs = {}
        for entry in self.git("ls-tree", "-rlz", commit).split(b"\0"):
            if not entry:
                continue
            header, name = entry.split(b"\t", 1)
            mode, kind, oid, size = header.decode().split()
            if kind != "blob":
                raise ValueError("unsupported non-blob tree entry: " + name.decode())
            path = name.decode()
            self.blobs[path] = Blob(path, oid, int(size), mode)

    def git(self, *arguments: str) -> bytes:
        """Каждый вызов адресован выбранному repo и не наследует GIT_DIR/GIT_INDEX_FILE."""
        return subprocess.check_output(
            ["git", "-C", str(self.root), *arguments],
            env=clean_git_environment(),
        )

    def contents(self, name: str) -> bytes:
        """Читает один известный blob по OID, без интерпретации имени как Git revision."""
        return self.git("cat-file", "blob", self.blobs[name].oid)

    def stream(self, text_suffixes: set[str], selected: set[str] | None = None):
        """Хеширует все blobs с ограниченной памятью; текст выдаёт только для анализа ссылок."""
        with tempfile.TemporaryFile() as errors:
            process = subprocess.Popen(
                ["git", "-C", str(self.root), "cat-file", "--batch"],
                env=clean_git_environment(),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=errors,
            )
            try:
                for blob in self.blobs.values():
                    if selected is not None and blob.path not in selected:
                        continue
                    # Один запрос за раз не заполняет stdout, пока родитель пишет stdin.
                    process.stdin.write((blob.oid + "\n").encode())
                    process.stdin.flush()
                    header = process.stdout.readline().decode().split()
                    if header != [blob.oid, "blob", str(blob.size)]:
                        raise ValueError("unexpected Git object header: " + blob.path)
                    remaining = blob.size
                    checksum = hashlib.sha256()
                    keep_text = Path(blob.path).suffix.lower() in text_suffixes
                    chunks = []
                    while remaining:
                        chunk = process.stdout.read(min(remaining, 1024 * 1024))
                        if not chunk:
                            raise ValueError("truncated Git blob: " + blob.path)
                        checksum.update(chunk)
                        if keep_text:
                            chunks.append(chunk)
                        remaining -= len(chunk)
                    if process.stdout.read(1) != b"\n":
                        raise ValueError("invalid Git object boundary")
                    raw = b"".join(chunks) if keep_text else None
                    text = raw.decode("utf-8", errors="replace") if raw is not None else None
                    yield blob, checksum.hexdigest(), text
                process.stdin.close()
                if process.wait(timeout=30) != 0:
                    raise ValueError("Git batch read failed")
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=10)
                process.stdout.close()
                if not process.stdin.closed:
                    process.stdin.close()


def sha256_file(path: Path) -> str:
    """Сравнивает защищённый рабочий файл поточно, не меняя его metadata или содержимое."""
    checksum = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            checksum.update(chunk)
    return checksum.hexdigest()
