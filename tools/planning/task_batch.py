#!/usr/bin/env python3
"""Считает завершённые задачи в main и публикует пакет из десяти задач."""

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import subprocess
import sys

from tools.common.paths import project_root
from tools.common.git import git_environment

ROOT = project_root(__file__)
BATCH_SIZE = 10
TASK_ID = re.compile(r"[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+")


@dataclass(frozen=True)
class Batch:
    """Снимок локальной main относительно последнего известного origin/main."""

    head: str
    task_ids: tuple[str, ...]
    commits: int
    remote_is_ancestor: bool


def git(root: Path, *args: str) -> str:
    """Выполняет Git без shell и сохраняет причину отказа для пользователя."""
    result = subprocess.run(
        ["git", *args], cwd=root, text=True, capture_output=True, check=False, env=git_environment()
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Ошибка Git")
    return result.stdout.strip()


def read_batch(root: Path) -> Batch:
    """Считает уникальные trailers только в уже влитой неопубликованной истории."""
    head = git(root, "rev-parse", "--verify", "refs/heads/main")
    remote = git(root, "rev-parse", "--verify", "refs/remotes/origin/main")
    pending = f"{remote}..{head}"
    trailers = git(
        root, "log", "--reverse", "--format=%(trailers:key=Task-Complete,valueonly)", pending
    )
    task_ids = []
    for line in trailers.splitlines():
        task_id = line.strip()
        if not task_id:
            continue
        if TASK_ID.fullmatch(task_id) is None:
            raise RuntimeError(f"Некорректный Task-Complete: {task_id!r}")
        if task_id not in task_ids:
            task_ids.append(task_id)
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", remote, head],
        cwd=root, capture_output=True, text=True, check=False, env=git_environment(),
    )
    if ancestor.returncode not in (0, 1):
        raise RuntimeError(ancestor.stderr.strip() or "Не удалось сравнить main и origin/main")
    return Batch(
        head, tuple(task_ids), int(git(root, "rev-list", "--count", pending)),
        ancestor.returncode == 0,
    )


def describe(batch: Batch) -> str:
    """Показывает задачи отдельно от количества локальных коммитов."""
    result = (
        f"MAIN: {len(batch.task_ids)}/{BATCH_SIZE} завершённых задач ждут публикации; "
        f"локальных коммитов: {batch.commits}."
    )
    if batch.task_ids:
        result += "\nЗадачи: " + ", ".join(batch.task_ids)
    if not batch.remote_is_ancestor:
        result += "\nВ origin/main есть новые изменения: сначала объедините историю и проверьте её."
    if len(batch.task_ids) >= BATCH_SIZE:
        result += "\nПакет готов: после проверок запустите python3 tools/task_batch.py publish."
    return result


def publish(root: Path) -> Batch:
    """После проверки агентом отправляет только готовую main обычным push."""
    if git(root, "branch", "--show-current") != "main":
        raise RuntimeError("Публикация разрешена из локальной main после merge готовых задач")
    if git(root, "status", "--porcelain"):
        raise RuntimeError("Перед публикацией нужен чистый checkout")
    batch = read_batch(root)
    if len(batch.task_ids) < BATCH_SIZE:
        return batch
    git(root, "fetch", "origin")
    batch = read_batch(root)
    if not batch.remote_is_ancestor:
        raise RuntimeError("origin/main обновилась: выполните обычный merge и повторите проверки")
    if len(batch.task_ids) >= BATCH_SIZE:
        git(root, "push", "origin", f"{batch.head}:refs/heads/main")
    # Состояние выводится из Git, а не сбрасывается до подтверждённого push.
    return read_batch(root)


def main() -> int:
    """Status не меняет репозиторий и сеть; publish вызывается после TESTING.md."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("status", "publish"))
    args = parser.parse_args()
    try:
        batch = publish(ROOT) if args.command == "publish" else read_batch(ROOT)
        print(describe(batch))
        return 0
    except RuntimeError as error:
        print(f"TASK BATCH: {error}", file=sys.stderr)
        # post-commit уже создал коммит; отсутствие remote не делает его неуспешным.
        return 1 if args.command == "publish" else 0


if __name__ == "__main__":
    raise SystemExit(main())
