"""Отделяет текущие World-входы от логических ключей и неизменной Git-истории."""
from __future__ import annotations

from functools import lru_cache
from pathlib import Path
import re
import subprocess
import sys
from types import MappingProxyType

from tools.assets.contracts.source_paths import MOVED_PATHS, current_source
from tools.common.git import git_environment
from tools.qa.art.current_paths import MOVED_PATHS as ART_PATHS

# Только разрешённые исторические aliases принятой World-карты. Физический переезд этим не объявляется.
WORLD_TARGETS = MappingProxyType(__WORLD_TARGETS__)


def input_path(root: Path, logical: str | Path) -> Path:
    """Читает текущий canonical вход; оставшийся legacy-файл не служит запасным источником."""
    name = logical.as_posix() if isinstance(logical, Path) else logical
    # Art имеет прежнюю отдельную карту; generic-карта расширяется только при настоящих переносах.
    current_source(root, name)
    return current_source(root, ART_PATHS.get(name, name))


def _git(root: Path, *arguments: str) -> subprocess.CompletedProcess:
    """Читает выбранный checkout без replace refs и унаследованных GIT overrides."""
    return subprocess.run(['git', '--no-replace-objects', '-C', str(root), *arguments],
                          env=git_environment(), capture_output=True)


def _owned_root(root: Path) -> Path:
    """Не позволяет вложенному проекту заимствовать родительский Git или чужой worktree."""
    root = Path(root).resolve(strict=True)
    marker = root / '.git'
    if not root.is_dir() or not marker.exists() or marker.is_symlink():
        raise ValueError('source history requires its own Git checkout')
    result = _git(root, 'rev-parse', '--show-toplevel')
    result.check_returncode()
    if Path(result.stdout.decode().strip()).resolve() != root:
        raise ValueError('source history cannot borrow a parent repository')
    if marker.is_file():
        directory = _git(root, 'rev-parse', '--absolute-git-dir')
        directory.check_returncode()
        backlink = Path(directory.stdout.decode().strip()).resolve() / 'gitdir'
        if (not backlink.is_file() or backlink.is_symlink()
                or Path(backlink.read_text().strip()).resolve() != marker):
            raise ValueError('source history requires a registered linked worktree')
    return root


@lru_cache(maxsize=64)
def _tree(root: Path, commit: str):
    """Кеширует только успешное неизменное дерево commit, включая его каталоги и типы."""
    kind = _git(root, 'cat-file', '-t', commit)
    kind.check_returncode()
    if kind.stdout.strip() != b'commit':
        raise ValueError('source history requires a commit object')
    result = _git(root, 'ls-tree', '-r', '-t', '-z', '--full-tree', commit)
    result.check_returncode()
    rows = {}
    for row in result.stdout.split(b'\0'):
        if not row:
            continue
        metadata, name = row.split(b'\t', 1)
        mode, object_kind, object_id = metadata.split()
        rows[name.decode()] = (mode, object_kind, object_id)
    return MappingProxyType(rows)


def _entry(root: Path, base: str, logical: str | Path, allow_tree: bool):
    """Выбирает единственный допустимый alias в том же commit; живые файлы не заменяют историю."""
    name = logical.as_posix() if isinstance(logical, Path) else logical
    input_path(root, name)
    if any(character in name for character in '\\:*?['):
        raise ValueError('unsafe historical source path')
    if not isinstance(base, str) or not re.fullmatch('[0-9a-f]{40}', base):
        raise ValueError('historical source requires a pinned commit')
    tree = _tree(root, base)
    aliases = {name}
    targets = {mapping[name] for mapping in (MOVED_PATHS, ART_PATHS, WORLD_TARGETS) if name in mapping}
    if len(targets) > 1:
        raise ValueError('conflicting source alias contract')
    aliases.update(targets)
    # Не читаем symlink рабочего каталога даже при проверке старого immutable blob.
    for alias in aliases:
        current_source(root, alias)
    present = aliases.intersection(tree)
    if not present:
        raise FileNotFoundError('historical source missing: ' + name)
    if len(present) != 1:
        raise ValueError('ambiguous historical source: ' + name)
    physical = present.pop()
    mode, kind, _ = tree[physical]
    if not (kind == b'blob' and mode in (b'100644', b'100755')
            or allow_tree and kind == b'tree' and mode == b'040000'):
        raise ValueError('historical source must be a regular file: ' + name)
    return base, physical, kind


def _historical_result(root, base, logical, *, text=False, allow_tree=False, kind_only=False):
    """Сохраняет форму Git-result и штатный nonzero для отсутствующего исторического входа."""
    root = _owned_root(root)
    args = ['git', 'show', str(base) + ':' + str(logical)]
    try:
        commit, physical, kind = _entry(root, base, logical, allow_tree)
    except FileNotFoundError:
        # Оба допустимых alias отсутствуют. Тот же pinned commit даёт штатный Git stderr,
        # а успешный неожиданный ответ не принимается как fallback.
        result = _git(root, 'show', str(base) + ':' + str(logical))
        if result.returncode == 0:
            raise ValueError('historical source tree changed unexpectedly')
    except subprocess.CalledProcessError as error:
        result = subprocess.CompletedProcess(error.cmd, error.returncode, error.stdout or b'', error.stderr or b'')
    else:
        if kind_only:
            result = subprocess.CompletedProcess(args, 0, kind + b'\n', b'')
        else:
            # Сохраняет git-show header дерева для немигрировавших evidence-каталогов.
            result = _git(root, 'show', commit + ':' + physical)
    if text:
        result.stdout = result.stdout.decode()
        result.stderr = result.stderr.decode()
    return result


def historical_result(root: Path, base: str, logical: str | Path, *, text=False, allow_tree=False):
    """Читает только Git blob известного alias; missing возвращает прежний nonzero результат."""
    return _historical_result(root, base, logical, text=text, allow_tree=allow_tree)


def historical_bytes(root: Path, base: str, logical: str | Path, *, text=False, allow_tree=False):
    """Сохраняет check_output отказ и тип stdout без fallback к текущему файлу."""
    result = historical_result(root, base, logical, text=text, allow_tree=allow_tree)
    if result.returncode and result.stderr:
        sys.stderr.write(result.stderr if isinstance(result.stderr, str) else result.stderr.decode())
    result.check_returncode()
    return result.stdout


def historical_kind(root: Path, base: str, logical: str | Path) -> str:
    """Возвращает прежний Git-тип blob/tree для явно проверяемой audit evidence."""
    result = _historical_result(root, base, logical, text=True, allow_tree=True, kind_only=True)
    if result.returncode and result.stderr:
        sys.stderr.write(result.stderr)
    result.check_returncode()
    return result.stdout.strip()
