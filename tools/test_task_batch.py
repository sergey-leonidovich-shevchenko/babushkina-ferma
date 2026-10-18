#!/usr/bin/env python3
"""Проверяет публикацию задач на изолированных репозиториях без сети."""

from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import task_batch


class TaskBatchTests(unittest.TestCase):
    """Реальные merge и push не затрагивают рабочий проект и GitHub."""

    def setUp(self):
        """Создаёт main и локальный bare origin с одним опубликованным коммитом."""
        # Git hook экспортирует GIT_DIR/GIT_INDEX_FILE: cwd сам по себе не изолирует Git.
        environment = patch.dict(
            os.environ, {key: value for key, value in os.environ.items() if not key.startswith("GIT_")},
            clear=True,
        )
        environment.start()
        self.addCleanup(environment.stop)
        self.temp = tempfile.TemporaryDirectory(prefix="farm-task-batch-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "work"
        self.remote = self.base / "origin.git"
        self.root.mkdir()
        self.run_git(self.base, "init", "--bare", "--initial-branch=main", str(self.remote))
        self.run_git(self.root, "init", "--initial-branch=main")
        self.run_git(self.root, "config", "user.name", "Task batch test")
        self.run_git(self.root, "config", "user.email", "batch@example.invalid")
        self.run_git(self.root, "config", "commit.gpgsign", "false")
        self.run_git(self.root, "config", "core.hooksPath", str(self.base / "no-hooks"))
        self.run_git(self.root, "remote", "add", "origin", str(self.remote))
        self.commit("baseline")
        self.run_git(self.root, "push", "-u", "origin", "main")
        self.published = self.remote_head()

    def run_git(self, root, *args):
        """Выполняет команды fixture с изолированными Git hooks."""
        result = subprocess.run(
            ["git", "-c", f"core.hooksPath={self.base / 'no-hooks'}", *args],
            cwd=root, capture_output=True, text=True, check=True,
        )
        return result.stdout.strip()

    def commit(self, message):
        """Добавляет пустой коммит для проверки истории без фиктивных файлов."""
        self.run_git(self.root, "commit", "--allow-empty", "-m", message)

    def complete(self, count):
        """Имитирует завершение независимых задач с правильным trailer."""
        for number in range(1, count + 1):
            self.commit(f"TEST-{number:02}: ready\n\nTask-Complete: TEST-{number:02}")

    def remote_head(self):
        """Проверяет настоящий ref bare origin, не только tracking ref."""
        return self.run_git(self.remote, "rev-parse", "refs/heads/main")

    def test_empty_batch(self):
        """Опубликованная main начинает счёт с нуля."""
        batch = task_batch.read_batch(self.root)
        self.assertEqual((), batch.task_ids)
        self.assertEqual(0, batch.commits)
        self.assertTrue(batch.remote_is_ancestor)

    def test_inherited_hook_environment_cannot_modify_parent_repository(self):
        """Вложенный прогон с GIT_DIR/GIT_INDEX_FILE не меняет родительский fixture."""
        before = (self.root / ".git" / "config").read_bytes()
        subprocess.run(
            [sys.executable, __file__, "TaskBatchTests.test_empty_batch"],
            cwd=self.root, capture_output=True, text=True, check=True,
            env={**os.environ, "GIT_DIR": str(self.root / ".git"),
                 "GIT_INDEX_FILE": str(self.root / ".git" / "index"), "GIT_WORK_TREE": str(self.root)},
        )
        self.assertEqual(before, (self.root / ".git" / "config").read_bytes())
        self.assertEqual(self.published, self.run_git(self.root, "rev-parse", "HEAD"))

    def test_intermediate_commits_and_duplicate_task_count_once(self):
        """Три коммита одной задачи и повтор trailer дают только одну задачу."""
        self.commit("TEST-01: implementation")
        self.complete(1)
        self.commit("TEST-01: docs\n\nTask-Complete: TEST-01")
        batch = task_batch.read_batch(self.root)
        self.assertEqual(("TEST-01",), batch.task_ids)
        self.assertEqual(3, batch.commits)

    def test_unmerged_branch_does_not_count(self):
        """Готовая ветка учитывается только после merge в main."""
        self.run_git(self.root, "switch", "-c", "codex/test-01-fixture")
        self.complete(1)
        self.assertEqual((), task_batch.read_batch(self.root).task_ids)
        self.run_git(self.root, "switch", "main")
        self.run_git(self.root, "merge", "--ff-only", "codex/test-01-fixture")
        self.assertEqual(("TEST-01",), task_batch.read_batch(self.root).task_ids)

    def test_task_name_in_subject_is_not_completion(self):
        """Название задачи и обычное упоминание в тексте не завершают её."""
        self.commit("TEST-01: progress\n\nTask-Complete: TEST-01\nStill doing the task.")
        self.assertEqual((), task_batch.read_batch(self.root).task_ids)

    def test_merge_commit_does_not_add_a_task(self):
        """Обычный merge сохраняет ID задачи без дополнительной единицы в счётчике."""
        self.run_git(self.root, "switch", "-c", "codex/test-01-fixture")
        self.complete(1)
        self.run_git(self.root, "switch", "main")
        self.commit("maintenance")
        self.run_git(self.root, "merge", "--no-ff", "-m", "merge ready task", "codex/test-01-fixture")
        batch = task_batch.read_batch(self.root)
        self.assertEqual(("TEST-01",), batch.task_ids)
        self.assertEqual(3, batch.commits)

    def test_real_post_commit_hook_never_pushes(self):
        """Установленный hook показывает готовую десятку, но не публикует её."""
        self.complete(10)
        hooks = self.root / ".githooks"
        tools = self.root / "tools"
        hooks.mkdir()
        tools.mkdir()
        shutil.copy2(task_batch.ROOT / ".githooks" / "post-commit", hooks / "post-commit")
        shutil.copy2(task_batch.ROOT / "tools" / "task_batch.py", tools / "task_batch.py")
        self.run_git(self.root, "config", "core.hooksPath", str(hooks))
        self.run_git(self.root, "add", ".githooks", "tools")
        result = subprocess.run(
            ["git", "commit", "-m", "install hook fixture"], cwd=self.root,
            capture_output=True, text=True, check=True,
        )
        self.assertIn("MAIN: 10/10", result.stdout + result.stderr)
        self.assertEqual(self.published, self.remote_head())

    def test_nine_tasks_do_not_push(self):
        """Девять готовых задач остаются локально."""
        self.complete(9)
        batch = task_batch.publish(self.root)
        self.assertEqual(9, len(batch.task_ids))
        self.assertEqual(self.published, self.remote_head())

    def test_ten_tasks_publish_main_and_reset_from_git(self):
        """Десятая задача отправляет main; следующий процесс видит ноль."""
        self.complete(10)
        expected = self.run_git(self.root, "rev-parse", "main")
        self.assertEqual((), task_batch.publish(self.root).task_ids)
        self.assertEqual(expected, self.remote_head())
        self.assertEqual(0, task_batch.read_batch(self.root).commits)

    def test_rejected_push_keeps_all_tasks(self):
        """Отказ сервера не обнуляет счётчик и не меняет опубликованную историю."""
        self.complete(10)
        hook = self.remote / "hooks" / "pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        hook.chmod(0o755)
        with self.assertRaises(RuntimeError):
            task_batch.publish(self.root)
        self.assertEqual(10, len(task_batch.read_batch(self.root).task_ids))
        self.assertEqual(self.published, self.remote_head())

    def test_dirty_checkout_blocks_publication(self):
        """Незакоммиченные файлы блокируют push даже после десятой задачи."""
        self.complete(10)
        (self.root / "unfinished.txt").write_text("pending", encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "чистый"):
            task_batch.publish(self.root)
        self.assertEqual(self.published, self.remote_head())

    def test_publication_from_task_branch_is_rejected(self):
        """Отдельная ветка не публикуется вместо main."""
        self.complete(10)
        self.run_git(self.root, "switch", "-c", "codex/unfinished")
        with self.assertRaisesRegex(RuntimeError, "локальной main"):
            task_batch.publish(self.root)
        self.assertEqual(self.published, self.remote_head())

    def test_remote_divergence_requires_merge(self):
        """Чужой push требует обычного merge и повторных проверок."""
        self.run_git(self.root, "switch", "-c", "parallel", "origin/main")
        self.commit("parallel work")
        self.run_git(self.root, "push", "origin", "HEAD:main")
        remote_head = self.remote_head()
        self.run_git(self.root, "switch", "main")
        self.complete(10)
        with self.assertRaisesRegex(RuntimeError, "merge"):
            task_batch.publish(self.root)
        self.assertEqual(remote_head, self.remote_head())
        self.assertEqual(10, len(task_batch.read_batch(self.root).task_ids))

    def test_remote_has_already_published_the_batch(self):
        """Публикация другим процессом обнаруживается fetch без второго push."""
        self.complete(10)
        self.run_git(self.root, "push", "origin", "main")
        self.run_git(self.root, "update-ref", "refs/remotes/origin/main", self.published)
        self.assertEqual(10, len(task_batch.read_batch(self.root).task_ids))
        self.assertEqual((), task_batch.publish(self.root).task_ids)

    def test_unknown_remote_does_not_fabricate_zero(self):
        """Отсутствующий tracking ref даёт явную ошибку."""
        self.run_git(self.root, "update-ref", "-d", "refs/remotes/origin/main")
        with self.assertRaises(RuntimeError):
            task_batch.read_batch(self.root)

    def test_malformed_marker_is_rejected(self):
        """Повреждённый ID не считается завершённой задачей."""
        self.commit("bad\n\nTask-Complete: need more work")
        with self.assertRaisesRegex(RuntimeError, "Task-Complete"):
            task_batch.read_batch(self.root)


if __name__ == "__main__":
    unittest.main()
