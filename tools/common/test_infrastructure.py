"""Проверяет настоящие границы cwd, worktree, argv и унаследованного Git-окружения."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from tools.common.git import git_environment
from tools.common.paths import project_root

ROOT = project_root()


class InfrastructureTests(unittest.TestCase):
    """Использует только disposable репозитории; исходный index/config не являются целью."""

    def setUp(self):
        """Копирует минимальный настоящий launcher в каталог с пробелами и отдельным Git."""
        self.temporary = tempfile.TemporaryDirectory(prefix="farm tools boundary ")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.root = self.base / "project with spaces"
        (self.root / "tools").mkdir(parents=True)
        for name in ("project.godot", "VERSION"):
            shutil.copy2(ROOT / name, self.root / name)
        for name in ("run.py", "__init__.py"):
            shutil.copy2(ROOT / "tools" / name, self.root / "tools" / name)
        shutil.copytree(ROOT / "tools/common", self.root / "tools/common",
                        ignore=shutil.ignore_patterns("__pycache__"))
        (self.root / "tools/probe.py").write_text(
            "import json,sys\nfrom pathlib import Path\n"
            "from tools.common.paths import project_root\n"
            "print(json.dumps(dict(root=str(project_root(__file__)),"
            "cwd=str(Path.cwd()),argv=sys.argv[1:])))\n"
            "raise SystemExit(7 if '--fail' in sys.argv else 0)\n"
        )

    def run_command(self, *arguments, cwd=None, environment=None):
        """Запускает реальный публичный CLI и сохраняет оба потока и exit без shell."""
        return subprocess.run(
            [sys.executable, str(self.root / "tools/run.py"), *arguments],
            cwd=cwd or self.base, env=environment, text=True, capture_output=True,
        )

    def git(self, *arguments):
        """Все fixture-команды адресованы только своему репозиторию без Git overrides."""
        return subprocess.run(["git", "-C", str(self.root), *arguments],
                              env=git_environment(), text=True, capture_output=True, check=True)

    def init_repository(self):
        """Создаёт локальный commit без пользовательских hooks, подписи и внешней сети."""
        self.git("init", "-q", "--initial-branch=main")
        self.git("config", "user.name", "Tools fixture")
        self.git("config", "user.email", "tools@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", str(self.base / "no hooks"))
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")

    def test_anchor_not_cwd_selects_root_and_preserves_argv(self):
        """Чужая cwd и аргументы с пробелами не меняют проект или границы аргументов."""
        for cwd in (self.root, self.base):
            result = self.run_command("probe", "two words", "--json", cwd=cwd)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), {
                "root": str(self.root), "cwd": str(cwd), "argv": ["two words", "--json"],
            })

    def test_exit_and_unknown_commands_are_not_hidden(self):
        """Ошибка команды остаётся exit 7; traversal, внешние и пропавшие модули отклоняются."""
        self.assertEqual(self.run_command("probe", "--fail").returncode, 7)
        for command in ("../probe", "os", "probe.py", "/tmp/probe", "missing", "probe;exit"):
            result = self.run_command(command)
            self.assertEqual(result.returncode, 2, (command, result.stdout, result.stderr))
        self.assertEqual(self.run_command("--root", "probe").returncode, 2)

    def test_unittest_runs_real_cases_and_propagates_failure(self):
        """unittest должен видеть временный __main__, выполнить оба case и вернуть настоящий red."""
        (self.root / "tools/probe.py").write_text(
            "import unittest\nclass Probe(unittest.TestCase):\n"
            " def test_ok(self): self.assertTrue(True)\n"
            " def test_red(self): self.assertTrue(False)\n"
            "unittest.main()\n"
        )
        result = self.run_command("probe")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Ran 2 tests", result.stderr)
        self.assertIn("FAILED (failures=1)", result.stderr)

    def test_external_tools_package_cannot_shadow_project(self):
        """Внешний PYTHONPATH с пакетом tools не подменяет собственную команду."""
        foreign = self.base / "foreign packages"
        (foreign / "tools").mkdir(parents=True)
        (foreign / "tools/__init__.py").write_text("raise RuntimeError('foreign tools')\n")
        for entries in ([foreign], [foreign, self.root]):
            environment = {**os.environ, "PYTHONPATH": os.pathsep.join(map(str, entries))}
            result = self.run_command("probe", environment=environment)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["root"], str(self.root))

    def test_symlink_escape_is_rejected(self):
        """Даже существующий Python через ссылку вне tools не становится допустимой командой."""
        outside = self.base / "outside.py"
        outside.write_text("raise RuntimeError('must not execute')\n")
        (self.root / "tools/escape.py").symlink_to(outside)
        self.assertEqual(self.run_command("escape").returncode, 2)

    def test_missing_project_markers_fail_explicitly(self):
        """Пропажа VERSION не позволяет launcher молча использовать другую cwd."""
        (self.root / "VERSION").unlink()
        result = self.run_command("--root")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Не найден корень проекта", result.stderr)

    def test_real_worktree_with_spaces(self):
        """В worktree .git является файлом; launcher выбирает его собственные исходники."""
        self.init_repository()
        checkout = self.base / "linked checkout with spaces"
        self.git("worktree", "add", "--detach", str(checkout), "HEAD")
        result = subprocess.run([sys.executable, str(checkout / "tools/run.py"), "probe"],
                                cwd=self.base, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["root"], str(checkout))
        self.assertTrue((checkout / ".git").is_file())

    def test_package_entry_and_public_api_imports(self):
        """Пакетный -m и публичные API работают без вручную добавленного tools в sys.path."""
        result = subprocess.run([sys.executable, "-m", "tools.run", "probe", "--help"],
                                cwd=self.root, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["argv"], ["--help"])
        result = subprocess.run([sys.executable, "-c",
            "import tools.task_batch as public;from tools.planning import task_batch as actual;"
            "assert public is actual;public.BATCH_SIZE=23;assert actual.BATCH_SIZE==23;"
            "import tools.bump_version as public_bump;from tools.planning import bump_version;"
            "assert public_bump is bump_version"], cwd=ROOT, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_environment_copy_clears_all_git_overrides(self):
        """Hook/config/index overrides удаляются из копии; PATH и исходный dict сохраняются."""
        environment = {"PATH": "/usr/bin", "KEEP": "value", "GIT_DIR": "foreign",
                       "GIT_INDEX_FILE": "foreign-index", "GIT_CONFIG_COUNT": "1",
                       "GIT_CONFIG_KEY_0": "core.bare", "GIT_CONFIG_VALUE_0": "true"}
        original = dict(environment)
        self.assertEqual(git_environment(environment), {"PATH": "/usr/bin", "KEEP": "value"})
        self.assertEqual(environment, original)

    def test_hook_staging_keeps_its_intentional_alternate_index(self):
        """Изоляция readers не лишает bump --stage законного index текущего commit hook."""
        shutil.copy2(ROOT / "tools/bump_version.py", self.root / "tools/bump_version.py")
        planning = self.root / "tools/planning"
        planning.mkdir()
        for name in ("bump_version.py", "__init__.py"):
            shutil.copy2(ROOT / "tools/planning" / name, planning / name)
        plist = Path("Бабушкина ферма.app/Contents/Info.plist")
        (self.root / plist).parent.mkdir(parents=True)
        shutil.copy2(ROOT / plist, self.root / plist)
        self.init_repository()
        index = self.root / ".git/index"
        before = index.read_bytes()
        alternate = self.root / ".git/fixture-alternate-index"
        alternate.write_bytes(before)
        parts = (self.root / "VERSION").read_text().strip().split(".")
        expected = ".".join([*parts[:2], str(int(parts[2]) + 1)])
        environment = {**git_environment(), "GIT_DIR": str(self.root / ".git"),
                       "GIT_WORK_TREE": str(self.root), "GIT_INDEX_FILE": str(alternate)}
        result = subprocess.run([sys.executable, str(self.root / "tools/bump_version.py"),
                                 "--set", expected, "--stage"], cwd=self.base,
                                env=environment, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(index.read_bytes(), before)
        staged = subprocess.run(["git", "-C", str(self.root), "show", ":VERSION"],
                                env=environment, text=True, capture_output=True, check=True)
        self.assertEqual(staged.stdout.strip(), expected)

    def test_real_shore_method_cannot_change_parent_config_or_index(self):
        """Повторяет красный аудит на реальном методе; parent sentinel остаётся побайтно прежним."""
        self.init_repository()
        self.git("config", "core.bare", "true")
        paths = [self.root / ".git" / name for name in ("config", "index")]
        before = [path.read_bytes() for path in paths]
        environment = {**git_environment(), "GIT_DIR": str(self.root / ".git"),
                       "GIT_WORK_TREE": str(self.root), "GIT_INDEX_FILE": str(paths[1]),
                       "PYTHONPATH": str(ROOT)}
        result = subprocess.run([sys.executable, "-c",
            "from tools.qa.world.test_shore_kit import ShoreKitTests; "
            "ShoreKitTests('test_required_log_must_be_indexed').test_required_log_must_be_indexed()"],
            cwd=self.base, env=environment, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([path.read_bytes() for path in paths], before)

    def test_facade_import_identity_and_mutable_globals(self):
        """Публичный import и пакет делят один модуль; присваивание globals не теряется в wrapper."""
        (self.root / "tools/alias.py").write_text(
            "from common.launch import facade\nfacade(__name__, 'tools.probe')\n"
        )
        # Для import-контракта нужен модуль без CLI side effects.
        (self.root / "tools/probe.py").write_text("VALUE = 'initial'\n")
        result = subprocess.run([sys.executable, "-c",
            "import sys;sys.path[:0]=sys.argv[1:];"
            "import alias,tools.probe;assert alias is tools.probe;"
            "alias.VALUE='changed';assert tools.probe.VALUE=='changed'",
            str(self.root / "tools"), str(self.root)],
            cwd=self.base, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_nested_suite_still_hits_architecture_limit(self):
        """Вложенный набор из 351 строки обязан остановить gate до остальных команд."""
        source = ROOT / "tools/check_architecture.sh"
        target = self.root / "tools/check_architecture.sh"
        shutil.copy2(source, target)
        quality = self.root / "tools/quality"
        quality.mkdir()
        shutil.copy2(ROOT / "tools/quality/check_architecture.sh", quality / "check_architecture.sh")
        for folder in ("scripts/core", "scripts/presentation", "tests/suites/nested"):
            (self.root / folder).mkdir(parents=True)
        for name in ("game.gd", "game_core.gd", "game_renderer.gd", "game_context.gd"):
            (self.root / "scripts" / name).write_text("pass\n")
        (self.root / "scripts/systems").mkdir()
        for name in ("level_editor_system.gd",):
            (self.root / "scripts/systems" / name).write_text("pass\n")
        (self.root / "scripts/editor").mkdir()
        (self.root / "scripts/editor/level_editor_document_store.gd").write_text("pass\n")
        for folder in ("scripts/core", "scripts/presentation"):
            (self.root / folder / "ok.gd").write_text("pass\n")
        (self.root / "tests/suites/nested/bad_suite.gd").write_text("pass\n" * 351)
        result = subprocess.run(["zsh", str(target)], cwd=self.base, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tests/suites/nested/bad_suite.gd has 351 lines", result.stderr)


if __name__ == "__main__":
    unittest.main()
