"""Индексирует имена старых капсул без извлечения файлов и без перепаковки доказательств."""
from __future__ import annotations

import hashlib
import subprocess
import tarfile
import tempfile
import zipfile

from git_snapshot import Snapshot, clean_git_environment


def tool_member(name: str) -> str | None:
    """Сохраняет старое имя; поиск суффикса не используется для записи на диск."""
    normalized = name.replace("\\", "/").removeprefix("./")
    if normalized.startswith("tools/"):
        return normalized
    marker = normalized.find("/tools/")
    return normalized[marker + 1:] if marker >= 0 else None


def checksum(stream) -> str:
    """Хеширует только читаемый member; никакой код из архива не исполняется."""
    digest = hashlib.sha256()
    while chunk := stream.read(1024 * 1024):
        digest.update(chunk)
    return digest.hexdigest()


def index_archives(snapshot: Snapshot, references, hashes: dict[str, str]) -> list[dict]:
    """ZIP/TAR читаются из временного файла с ограниченной памятью, исходные blobs неизменны."""
    result = []
    for blob in snapshot.blobs.values():
        if not blob.path.startswith("docs/reports/") or not blob.path.endswith((".zip", ".tar.gz", ".tgz")):
            continue
        record = {"path": blob.path, "git_blob": blob.oid, "sha256": hashes[blob.path],
                  "size": blob.size, "members": 0, "tool_members": 0, "errors": []}
        with tempfile.TemporaryFile() as spool:
            process = subprocess.Popen(
                ["git", "-C", str(snapshot.root), "cat-file", "blob", blob.oid],
                env=clean_git_environment(), stdout=spool, stderr=subprocess.PIPE,
            )
            _, error = process.communicate(timeout=180)
            if process.returncode:
                raise ValueError("cannot read archive Git blob: " + error.decode(errors="replace"))
            spool.seek(0)
            try:
                if blob.path.endswith(".zip"):
                    with zipfile.ZipFile(spool) as archive:
                        for member in archive.infolist():
                            record["members"] += 1
                            target = tool_member(member.filename)
                            if member.is_dir() or not target:
                                continue
                            with archive.open(member) as source:
                                digest = checksum(source)
                            _add_member(references, record, member.filename, target, digest, hashes)
                else:
                    with tarfile.open(fileobj=spool, mode="r|*") as archive:
                        for member in archive:
                            record["members"] += 1
                            target = tool_member(member.name)
                            if not member.isfile() or not target:
                                continue
                            with archive.extractfile(member) as source:
                                digest = checksum(source)
                            _add_member(references, record, member.name, target, digest, hashes)
            except (zipfile.BadZipFile, tarfile.TarError) as error:
                record["errors"].append(type(error).__name__ + ": " + str(error))
        result.append(record)
    return result


def _add_member(references, record, member, target, digest, hashes):
    """Несовпадение с нынешним исходником — историческое различие, а не ошибка архива."""
    record["tool_members"] += 1
    references.rows.append({
        "consumer": record["path"], "line": 0, "kind": "archive_member",
        "target": target, "binding": "archived_source_member", "scope": "historical_evidence",
        "member": member, "text": member, "member_sha256": digest,
        "matches_baseline_source": hashes.get(target) == digest,
    })
