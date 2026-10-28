"""Проверяет реальное текущее размещение и выбор политики только из своего Git commit."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.common.git import git_environment
from tools.common.paths import project_root
from tools.assets.contracts.asset_report import reader, working_reader
from tools.assets.contracts.source_paths import (
    MOVED_PATHS, captured_paths, current_source, historical_source, recorded_paths,
)
from tools.assets.migration.migration_inventory import build, historical_errors

POLICY = 'tools/visual_asset_policy.json'
PREVIEW = ('tools/item_ui_fitter.gd', 'tools/preview_portability_capture.gd')


class SourcePathsTests(unittest.TestCase):
    """Никакая legacy-копия, metadata или live-файл не заменяет объявленный источник."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='asset source paths ')
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.root = self.folder / 'project with spaces'
        self.root.mkdir()

    def git(self, *arguments):
        """Читает/пишет только собственный временный Git без пользовательских hooks."""
        return subprocess.check_output(
            ['git', '-c', 'core.hooksPath=' + str(self.folder / 'no-hooks'), '-C', str(self.root), *arguments],
            env=git_environment(), text=True, stderr=subprocess.DEVNULL,
        )

    def repository(self, policy=POLICY):
        """Создаёт маленькую настоящую историю с явным old/new путём политики."""
        files = {'assets/game/a.png': b'fixture resource', 'scripts/a.gd': b'load("res://assets/game/a.png")\n'}
        if policy is not None:
            files[policy] = b'{"non_runtime_roots": []}\n'
        for name, raw in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        self.git('init', '--initial-branch=main')
        return self.commit()

    def commit(self):
        """Фиксирует только fixture и возвращает её настоящий commit."""
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-m', 'source layout fixture')
        return self.git('rev-parse', 'HEAD').strip()

    def test_table_matches_accepted71_and_actual_files(self):
        root = project_root(__file__)
        plan = json.loads((root / 'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())
        expected = {old: row['target'] for old, row in plan['assignments'].items()
                    if row['family'] in {'assets-contracts', 'assets-migration', 'build'}}
        self.assertEqual(dict(MOVED_PATHS), expected)
        self.assertEqual(len(expected), 71)
        for old, target in expected.items():
            self.assertEqual(current_source(root, old), root / target)
            self.assertTrue((root / target).is_file(), target)
            self.assertFalse((root / old).exists(), old)

    def test_table_and_returned_metadata_cannot_mutate_each_other(self):
        with self.assertRaises(TypeError):
            MOVED_PATHS[POLICY] = 'elsewhere.json'
        reported = captured_paths(PREVIEW)
        accepted = recorded_paths(PREVIEW, reported)
        accepted.clear()
        self.assertEqual(reported, captured_paths(PREVIEW))

    def test_missing_current_target_has_no_legacy_file_fallback(self):
        old = self.root / POLICY
        old.parent.mkdir()
        old.write_bytes(b'old copy must not hide missed move')
        with self.assertRaises(FileNotFoundError):
            current_source(self.root, POLICY).read_bytes()

    def test_unmoved_media_stays_live_without_git(self):
        path = self.root / 'a.txt'
        path.write_bytes(b'before')
        read = working_reader(self.root)
        self.assertEqual(read('a.txt'), b'before')
        path.write_bytes(b'after')
        self.assertEqual(read('a.txt'), b'after')

    def test_noncanonical_paths_are_rejected(self):
        for name in ['../a', '/a', 'tools//a', 'tools/./a', 'tools/../a', '.git/config', 'a\\b', 'a\x00b']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                current_source(self.root, name)

    def test_logical_symlink_is_rejected_even_with_valid_new_target(self):
        target = current_source(self.root, POLICY)
        target.parent.mkdir(parents=True)
        target.write_bytes(b'new canonical file')
        (self.root / POLICY).symlink_to(target)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            current_source(self.root, POLICY)

    def test_physical_parent_symlink_is_rejected(self):
        (self.root / 'tools').mkdir()
        outside = self.folder / 'outside'
        outside.mkdir()
        (self.root / 'tools/assets').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            current_source(self.root, POLICY)

    def test_only_full_known_or_legacy_metadata_is_accepted(self):
        self.assertEqual(recorded_paths(PREVIEW, {}), {})
        self.assertEqual(recorded_paths(PREVIEW, captured_paths(PREVIEW)), captured_paths(PREVIEW))
        for value in [None, [], True, {PREVIEW[0]: MOVED_PATHS[PREVIEW[0]]},
                      {**captured_paths(PREVIEW), 'extra': 'file'}, {n: '../outside' for n in PREVIEW}]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                recorded_paths(PREVIEW, value)

    def test_same_commit_alias_reads_real_old_and_new_git_blobs(self):
        old_commit = self.repository()
        target = current_source(self.root, POLICY)
        target.parent.mkdir(parents=True)
        self.git('mv', POLICY, MOVED_PATHS[POLICY])
        target.write_bytes(b'{"non_runtime_roots": ["docs"]}\n')
        new_commit = self.commit()
        target.write_bytes(b'changed live bytes are not historical policy')
        self.assertEqual(json.loads(reader(self.root, old_commit)(POLICY)), {'non_runtime_roots': []})
        self.assertEqual(json.loads(reader(self.root, new_commit)(POLICY)), {'non_runtime_roots': ['docs']})

    def test_two_aliases_in_one_real_commit_are_ambiguous(self):
        self.repository()
        target = current_source(self.root, POLICY)
        target.parent.mkdir(parents=True)
        target.write_bytes(b'{"non_runtime_roots": ["different"]}\n')
        commit = self.commit()
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            reader(self.root, commit)(POLICY)
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            historical_source({POLICY, MOVED_PATHS[POLICY]}, POLICY)

    def test_missing_history_policy_is_not_replaced_by_live_new_file(self):
        commit = self.repository(policy=None)
        target = current_source(self.root, POLICY)
        target.parent.mkdir(parents=True)
        target.write_bytes(b'{"non_runtime_roots": []}\n')
        with self.assertRaises(FileNotFoundError):
            reader(self.root, commit)(POLICY)
        with self.assertRaises(FileNotFoundError):
            build(self.root, commit)

    def test_scanner_uses_new_policy_tree_without_rewriting_graph_contract(self):
        commit = self.repository(policy=MOVED_PATHS[POLICY])
        inventory = build(self.root, commit)
        self.assertIn('assets/game/a.png', inventory['files'])
        self.assertIn(MOVED_PATHS[POLICY], inventory['sources'])
        self.assertEqual(historical_errors(self.root, inventory), [])


if __name__ == '__main__':
    unittest.main()
