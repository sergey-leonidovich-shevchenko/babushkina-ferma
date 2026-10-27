"""Читает явно закреплённый Git blob, не подменяя историю рабочим файлом."""
from __future__ import annotations

import hashlib
from pathlib import Path, PurePosixPath
import re
import subprocess

from .git import git_environment


def read_git_blob(root: Path, relative: str, commit: str, expected: str) -> bytes:
    """Требует собственный checkout, полный commit/SHA и обычный файл точного дерева."""
    if (not isinstance(relative, str) or not relative
            or PurePosixPath(relative).is_absolute() or PurePosixPath(relative).as_posix() != relative
            or any(part in {'.', '..', '.git'} for part in relative.split('/'))
            or any(c in relative for c in '\\:*?[') or any(ord(c) < 32 or ord(c) == 127 for c in relative)
            or not isinstance(commit, str) or not re.fullmatch('[0-9a-f]{40}', commit)
            or not isinstance(expected, str) or not re.fullmatch('[0-9a-f]{64}', expected)):
        raise ValueError('invalid historical source pin')
    try:
        root = Path(root).resolve(strict=True)
    except OSError as error:
        raise ValueError('historical source requires its checkout') from error
    if not root.is_dir() or not (root / '.git').exists() or (root / '.git').is_symlink():
        raise ValueError('historical source requires its own Git checkout')
    current = root
    for part in relative.split('/'):
        current /= part
        if current.is_symlink():
            raise ValueError('historical source cannot follow a working-tree symlink')

    def git(*arguments: str) -> bytes:
        """Читает собственную историю без replace refs и унаследованных hook/index/config overrides."""
        try:
            return subprocess.run(['git', '--no-replace-objects', '-C', str(root), *arguments],
                                  env=git_environment(), capture_output=True, check=True).stdout
        except (OSError, subprocess.CalledProcessError) as error:
            raise ValueError('historical source unavailable: ' + relative) from error

    repository = Path(git('rev-parse', '--show-toplevel').decode().strip()).resolve()
    if repository != root:
        raise ValueError('historical source cannot borrow a parent repository')
    if (root / '.git').is_file():
        git_dir = Path(git('rev-parse', '--absolute-git-dir').decode().strip()).resolve()
        backlink = git_dir / 'gitdir'
        if (not backlink.is_file() or backlink.is_symlink()
                or Path(backlink.read_text().strip()).resolve() != root / '.git'):
            raise ValueError('historical source requires a registered linked worktree')
    if git('rev-parse', '--verify', commit + '^{commit}').decode().strip() != commit:
        raise ValueError('historical source requires a commit object')
    entry = git('ls-tree', '-z', commit, '--', relative).split(b'\0')
    if len(entry) != 2 or not entry[0] or entry[1]:
        raise ValueError('historical source missing: ' + relative)
    metadata, name = entry[0].split(b'\t', 1)
    mode, kind, object_id = metadata.split()
    if mode not in {b'100644', b'100755'} or kind != b'blob' or name.decode() != relative:
        raise ValueError('historical source must be a regular file: ' + relative)
    raw = git('cat-file', 'blob', object_id.decode())
    if hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError('historical source SHA256 mismatch: ' + relative)
    return raw


def pinned_sha(root: Path, relative: str, commit: str, expected: str) -> str:
    """Возвращает SHA только после чтения и проверки закреплённых байтов Git."""
    return hashlib.sha256(read_git_blob(root, relative, commit, expected)).hexdigest()
