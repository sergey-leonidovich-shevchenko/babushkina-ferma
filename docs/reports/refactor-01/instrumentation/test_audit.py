"""Отрицательные проверки ведомости, настоящего Git, ссылок и графа suites."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import audit
from archive_index import tool_member
from git_snapshot import Snapshot, clean_git_environment, project_root, sha256_file
from mapping import directory_counts, other_catalogs, validate_plan
from references import References, pattern_matches, python_imports, scope, source_description
from suite_registry import registry


def sample_plan() -> dict:
    """Маленький контракт сохраняет реальные типы действий без привязки к числу production-файлов."""
    return {
        "baseline_commit": "a" * 40, "source_extensions": [".py", ".gd", ".sh"],
        "families": {"qa": {"title": "Контроли", "stage": "REFACTOR-03"}},
        "public_facades": {"tools/entry.py": "Documented CLI"}, "protected_anchor": "tools/anchor.gd",
        "new_entries_proposed_not_implemented": [{"path": "tools/run.py", "reason": "one dispatcher"}],
        "root_source_budget": 30, "future_root_source_count": 3,
        "other_catalogs": [],
        "assignments": {
            "tools/entry.py": {"target": "tools/qa/entry.py", "family": "qa", "action": "move_implementation_keep_public_facade",
                               "public_entry": "tools/entry.py", "exception_reason": "Documented CLI"},
            "tools/helper.py": {"target": "tools/qa/helper.py", "family": "qa", "action": "move"},
            "tools/anchor.gd": {"target": "tools/anchor.gd", "family": "qa", "action": "retain_protected_anchor",
                                "exception_reason": "Frozen active reader"},
            "tools/anchor.gd.uid": {"target": "tools/anchor.gd.uid", "family": "qa", "action": "retain_uid_with_anchor"},
        },
    }


class PlanControls(unittest.TestCase):
    """Повреждённая карта должна отказать до чтения большого архива."""

    def setUp(self):
        self.plan = sample_plan()
        self.paths = set(self.plan["assignments"])

    def test_complete_map(self):
        self.assertEqual(validate_plan(self.plan, self.paths), 3)

    def test_missing_source(self):
        del self.plan["assignments"]["tools/helper.py"]
        with self.assertRaisesRegex(ValueError, "coverage"):
            validate_plan(self.plan, self.paths)

    def test_target_collision(self):
        self.plan["assignments"]["tools/helper.py"]["target"] = "tools/qa/entry.py"
        with self.assertRaisesRegex(ValueError, "collision"):
            validate_plan(self.plan, self.paths)

    def test_split_uid(self):
        self.plan["assignments"]["tools/anchor.gd.uid"]["target"] = "tools/qa/lost.uid"
        with self.assertRaisesRegex(ValueError, "UID pair"):
            validate_plan(self.plan, self.paths)

    def test_path_escape(self):
        self.plan["assignments"]["tools/helper.py"]["target"] = "tools/../../outside.py"
        with self.assertRaisesRegex(ValueError, "unsafe"):
            validate_plan(self.plan, self.paths)

    def test_unknown_family(self):
        self.plan["assignments"]["tools/helper.py"]["family"] = "unknown"
        with self.assertRaisesRegex(ValueError, "family"):
            validate_plan(self.plan, self.paths)

    def test_unexplained_root_source(self):
        self.plan["assignments"]["tools/helper.py"]["target"] = "tools/helper.py"
        with self.assertRaisesRegex(ValueError, "undocumented root"):
            validate_plan(self.plan, self.paths)

    def test_public_registry_disagreement(self):
        self.plan["public_facades"]["tools/hidden.py"] = "not actually mapped"
        with self.assertRaisesRegex(ValueError, "registry differs"):
            validate_plan(self.plan, self.paths)

    def test_new_entry_collision(self):
        self.plan["new_entries_proposed_not_implemented"][0]["path"] = "tools/entry.py"
        with self.assertRaisesRegex(ValueError, "entry collision"):
            validate_plan(self.plan, self.paths)

    def test_new_entry_outside_tools_or_nested_is_rejected(self):
        for name in ["../outside.py", "/tmp/outside.py", "tools/common/nested_dispatcher.py"]:
            with self.subTest(path=name):
                plan = sample_plan()
                plan["new_entries_proposed_not_implemented"][0]["path"] = name
                with self.assertRaisesRegex(ValueError, "new root entry"):
                    validate_plan(plan, self.paths)

    def test_new_entry_requires_canonical_portable_path(self):
        for name in ["", ".", "tools", "tools/", "./tools/run.py", "tools//run.py",
                     "tools/./run.py", "tools/qa/../run.py", "tools/run.py/",
                     "tools\\run.py", "tools/C:run.py", "tools/new\nrun.py", "tools/run\0.py", None]:
            with self.subTest(path=name):
                plan = sample_plan()
                plan["new_entries_proposed_not_implemented"][0]["path"] = name
                with self.assertRaisesRegex(ValueError, "new root entry"):
                    validate_plan(plan, self.paths)

    def test_new_entry_must_be_a_declared_source(self):
        for name in ["tools/config.json", "tools/run.py.uid", "tools/README.md", "tools/dispatcher"]:
            with self.subTest(path=name):
                plan = sample_plan()
                plan["new_entries_proposed_not_implemented"][0]["path"] = name
                with self.assertRaisesRegex(ValueError, "new root entry"):
                    validate_plan(plan, self.paths)

    def test_duplicate_new_entries_are_not_hidden_by_root_set(self):
        self.plan["new_entries_proposed_not_implemented"].append({
            "path": "tools/run.py", "reason": "second duplicate must not disappear",
        })
        with self.assertRaisesRegex(ValueError, "entry collision"):
            validate_plan(self.plan, self.paths)

    def test_new_entry_requires_nonblank_reason(self):
        for reason in ["", " \t\n", None, 123]:
            with self.subTest(reason=reason):
                plan = sample_plan()
                plan["new_entries_proposed_not_implemented"][0]["reason"] = reason
                with self.assertRaisesRegex(ValueError, "missing reason"):
                    validate_plan(plan, self.paths)

    def test_alternative_root_source_is_counted(self):
        self.plan["new_entries_proposed_not_implemented"][0]["path"] = "tools/dispatch.sh"
        self.assertEqual(validate_plan(self.plan, self.paths), 3)

    def test_multiple_distinct_root_sources_are_counted(self):
        self.plan["new_entries_proposed_not_implemented"].append({
            "path": "tools/dispatch.sh", "reason": "documented additional CLI",
        })
        self.plan["future_root_source_count"] = 4
        self.assertEqual(validate_plan(self.plan, self.paths), 4)
        self.plan["root_source_budget"] = 3
        with self.assertRaisesRegex(ValueError, "budget"):
            validate_plan(self.plan, self.paths)

    def test_root_budget(self):
        self.plan["root_source_budget"] = 2
        with self.assertRaisesRegex(ValueError, "budget"):
            validate_plan(self.plan, self.paths)


class ReferenceControls(unittest.TestCase):
    """Различает реальный import, динамический кандидат и историческую копию."""

    def test_local_import_and_external_module(self):
        edges, errors = python_imports("tools/entry.py", "import json\nfrom helper import value\n", {"tools/helper.py"})
        self.assertFalse(errors)
        self.assertEqual([row["target"] for row in edges], ["tools/helper.py"])

    def test_cross_directory_import_is_only_candidate(self):
        edges, errors = python_imports("docs/report/entry.py", "import helper", {"tools/helper.py"})
        self.assertEqual(edges[0]["binding"], "candidate_requires_search_path")
        self.assertEqual(errors[0]["kind"], "module_search_path_requires_review")

    def test_glob_does_not_hide_nested_directory(self):
        paths = {"tools/a.gd", "tools/inner/b.gd"}
        self.assertEqual(pattern_matches("tools/*.gd", paths), ["tools/a.gd"])
        self.assertEqual(pattern_matches("tools/{name}.gd", paths), ["tools/a.gd"])

    def test_prefix_filter_is_not_a_missing_file(self):
        refs = References({"tools/family.py", "tools/family_review.gd"})
        refs.add("tools/reader.py", "flag = name.startswith('tools/family')")
        self.assertEqual(refs.rows[0]["kind"], "prefix_filter")
        self.assertEqual(len(refs.rows[0]["candidates"]), 2)

    def test_uid_resolution_and_frozen_scope(self):
        refs = References({"tools/a.gd", "tools/a.gd.uid", "scripts/a.gd"})
        refs.add("tools/a.gd.uid", "uid://abc123\n")
        refs.add("scripts/a.gd", 'const X = preload("uid://abc123")')
        self.assertEqual(refs.rows[0]["target"], "tools/a.gd")
        self.assertEqual(scope("docs/reports/old/test.py"), "frozen_code")
        self.assertEqual(scope("docs/reports/old/plan.json"), "historical_evidence")

    def test_windows_engine_is_not_tracked_source_debt(self):
        refs = References(set())
        refs.add("wiki/scripts/runtime.mjs", "join(root, 'tools/Godot.exe')")
        self.assertEqual(refs.rows[0]["kind"], "installed_runtime")

    def test_argument_declarations_are_separate_from_help_safety(self):
        result = source_description("tools/a.py", 'import argparse\np = argparse.ArgumentParser()\np.add_argument("--output")\n# FARM_OUTPUT\n')
        self.assertEqual(result["cli_options"][0]["flags"], ["--output"])
        self.assertEqual(result["environment_tokens"], ["FARM_OUTPUT"])
        self.assertIn("unguarded", result["entry_kind"])

    def test_frozen_markdown_link_has_its_physical_target(self):
        refs = References({"tools/a.gd"})
        refs.add("docs/reports/example/README.md", "[source](../../../tools/a.gd)")
        links = [row for row in refs.rows if row["kind"] == "markdown_link"]
        self.assertEqual(links[0]["target"], "tools/a.gd")
        self.assertEqual(links[0]["scope"], "historical_evidence")

    def test_archive_member_is_normalized_without_extraction(self):
        self.assertEqual(tool_member("project/tools/a.gd"), "tools/a.gd")
        self.assertIsNone(tool_member("elsewhere/a.gd"))

    def test_counts_keep_uid_shader_and_nested_sources_distinct(self):
        blobs = {name: SimpleNamespace(size=1) for name in [
            "tools/a.gd", "tools/a.gd.uid", "tools/nested/b.py", "tools/nested/wind.gdshader",
        ]}
        result = directory_counts(blobs, "tools", {".py", ".gd"})
        self.assertEqual(result["immediate"]["tracked_files"], 2)
        self.assertEqual(result["immediate"]["executable_sources"], 1)
        self.assertEqual(result["recursive"]["executable_sources"], 2)
        self.assertEqual(result["recursive"]["shader_sources"], 1)
        self.assertEqual(result["recursive"]["uid_files"], 1)

    def test_suite_graph_tracks_nested_run_not_unused_preload(self):
        texts = {
            "tests/test_game.gd": 'const Parent = preload("res://tests/suites/parent_suite.gd")\nvar suites: Array = [Parent]\nfor suite in suites: suite.new(self).run()',
            "tests/suites/parent_suite.gd": 'const Unused = preload("res://tests/suites/unused_suite.gd")\nfunc run():\n preload("res://tests/suites/child_suite.gd").new(context).run()',
            "tests/suites/child_suite.gd": "func run(): pass",
            "tests/suites/unused_suite.gd": "func run(): pass",
        }
        result = registry(texts)
        self.assertEqual(result["static_run_path_counts"]["tests/suites/child_suite.gd"], 1)
        self.assertEqual(result["unreached_suite_files"], ["tests/suites/unused_suite.gd"])

    def test_suite_graph_exposes_duplicate_activation(self):
        result = registry({
            "tests/test_game.gd": 'const A = preload("res://tests/suites/a_suite.gd")\nvar suites: Array = [A, A]\nfor suite in suites: suite.new(self).run()',
            "tests/suites/a_suite.gd": "func run(): pass",
        })
        self.assertEqual(result["multiple_static_run_paths"], {"tests/suites/a_suite.gd": 2})

    def test_other_catalog_decision_lists_only_selected_family_and_uid(self):
        blobs = {name: SimpleNamespace(size=1, oid="a" * 40) for name in [
            "scripts/systems/storage_input.gd", "scripts/systems/storage_input.gd.uid",
            "scripts/systems/unrelated.gd",
        ]}
        result = other_catalogs({"source_extensions": [".gd"], "other_catalogs": [{
            "directory": "scripts/systems", "selectors": ["storage_*.gd"],
            "target_directory": "scripts/systems/storage", "decision": "future_addressed_move",
        }]}, blobs, [], {})[0]
        self.assertEqual(len(result["selected_sources"]), 1)
        self.assertEqual(result["selected_sources"][0]["uid_target"], "scripts/systems/storage/storage_input.gd.uid")


class GitControls(unittest.TestCase):
    """Настоящие временные репозитории не наследуют Git hooks и окружение проекта."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="farm refactor01 tests ")
        self.addCleanup(self.temp.cleanup)
        self.parent = Path(self.temp.name)
        self.root = self.parent / "repo with spaces"
        self.root.mkdir()
        self.git("init", "--quiet")
        contents = {"VERSION": "0.0.341\n", "project.godot": "config_version=5\n",
                    "tools/entry.py": '"""Entry."""\nfrom helper import value\n',
                    "tools/helper.py": '"""Helper."""\nvalue = 1\n',
                    "tools/anchor.gd": "extends SceneTree\n", "tools/anchor.gd.uid": "uid://anchor\n",
                    "tests/test_game.gd": 'var suites: Array = []\nfor suite in suites: suite.new(self).run()\n'}
        for name, text in contents.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "fixture")
        self.commit = self.git("rev-parse", "HEAD").decode().strip()

    def git(self, *arguments):
        return subprocess.check_output(
            ["git", "-C", str(self.root), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
             "-c", "commit.gpgsign=false", "-c", "core.hooksPath=" + str(self.parent / "no-hooks"), *arguments],
            env=clean_git_environment(), stderr=subprocess.PIPE,
        )

    def test_snapshot_ignores_inherited_git_dir_and_preserves_index(self):
        config, index = self.root / ".git/config", self.root / ".git/index"
        before = [sha256_file(config), sha256_file(index)]
        with patch.dict(os.environ, {"GIT_DIR": str(self.parent / "missing"), "GIT_INDEX_FILE": str(self.parent / "bad-index")}):
            snapshot = Snapshot(self.root, self.commit)
            self.assertEqual(snapshot.contents("VERSION"), b"0.0.341\n")
        self.assertEqual([sha256_file(config), sha256_file(index)], before)

    def test_root_finder_does_not_depend_on_parent_depth(self):
        deep = self.root / "tools/qa/inside"
        deep.mkdir(parents=True)
        self.assertEqual(project_root(deep), self.root)

    def test_actual_worktree_git_file_and_spaces(self):
        worktree = self.parent / "linked worktree with spaces"
        self.git("worktree", "add", "--quiet", "--detach", str(worktree), self.commit)
        self.assertTrue((worktree / ".git").is_file())
        deep = worktree / "tools/qa/inside"
        deep.mkdir(parents=True)
        self.assertEqual(project_root(deep), worktree)
        self.assertEqual(Snapshot(worktree, self.commit).contents("VERSION"), b"0.0.341\n")

    def test_full_reproduction_from_different_cwd_with_spaces(self):
        plan = sample_plan()
        plan["baseline_commit"] = self.commit
        plan["verification_command"] = "python3 audit.py check --plan scoped-plan.json --snapshot scoped-capture"
        plan_path = self.parent / "plan.json"
        plan_path.write_text(json.dumps(plan))
        output = self.parent / "capture"
        summary = audit.collect(self.root, self.commit, plan_path, output)
        self.assertEqual(summary["verification_catalog"]["full-snapshot-reproduction"]["command"], plan["verification_command"])
        result = subprocess.run(
            [sys.executable, str(Path(audit.__file__).resolve()), "check", "--root", str(self.root),
             "--snapshot", str(output), "--plan", str(plan_path)],
            cwd=self.parent, env=clean_git_environment(), capture_output=True, text=True, timeout=90,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(self.commit, result.stdout)

    def test_existing_output_is_never_overwritten(self):
        output = self.parent / "existing"
        output.mkdir()
        sentinel = output / "sentinel"
        sentinel.write_text("retain")
        with self.assertRaisesRegex(ValueError, "fresh output"):
            audit.collect(self.root, self.commit, self.parent / "missing-plan", output)
        self.assertEqual(sentinel.read_text(), "retain")

    def test_corrupted_packet_rejected_before_git_read(self):
        output = self.parent / "packet"
        output.mkdir()
        target = output / "data.json"
        target.write_text("original")
        audit.write_json(output / "packet.json", {"files": {"data.json": sha256_file(target)}})
        target.write_text("modified")
        with self.assertRaisesRegex(ValueError, "packet SHA"):
            audit.check(self.parent / "not-a-repo", output, self.parent / "missing-plan")


if __name__ == "__main__":
    unittest.main()
