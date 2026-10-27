"""Проверяет границу старого scanner и нового source-mode на настоящем Git-снимке."""
from __future__ import annotations

import copy
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

from tools.common.git import git_environment
from tools.common.history import read_git_blob
from tools.common.paths import project_root
from tools import migration_inventory as scanner


class ScannerHistoryTests(unittest.TestCase):
    """Внешний проект не может выбирать исходник scanner или подменять его историю."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='farm scanner history ')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        files = {
            'assets/game/stone.png': b'fixture resource, not an image acceptance',
            'scripts/use.gd': b'load("res://assets/game/stone.png")\nload(variable)\n',
            'tools/visual_asset_policy.json': b'{"non_runtime_roots": []}\n',
            'project.godot': b'config_version=5\n',
        }
        for name, raw in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        self.git('init', '--initial-branch=main')
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-m', 'scanner fixture')
        self.commit = self.git('rev-parse', 'HEAD').strip()
        self.current = scanner.build(self.root, self.commit)
        self.code_root = project_root(scanner.__file__)

    def git(self, *arguments):
        """Пишет только собственный disposable Git, не запуская пользовательские hooks."""
        return subprocess.check_output(
            ['git', '-c', 'core.hooksPath=' + str(self.root / 'no-hooks'),
             '-C', str(self.root), *arguments], env=git_environment(), text=True,
            stderr=subprocess.DEVNULL,
        )

    def legacy(self):
        """Исполняет точные прежние байты производителя, а не вручную имитирует его JSON."""
        raw = read_git_blob(self.code_root, *scanner.LEGACY_SCANNER)
        path = self.root / 'legacy-scanner.py'
        path.write_bytes(raw)
        module = types.ModuleType('fixture_legacy_scanner')
        module.__file__ = str(path)
        exec(compile(raw, str(path), 'exec'), module.__dict__)
        return module.build(self.root, self.commit)

    def test_fresh_record_binds_actual_current_code(self):
        self.assertEqual(self.current['scanner_source_mode'], 'current')
        self.assertEqual(self.current['scanner_sha256'], scanner.sha(Path(scanner.__file__).read_bytes()))
        self.assertEqual(scanner.historical_errors(self.root, self.current), [])

    def test_actual_legacy_producer_still_passes(self):
        data = self.legacy()
        self.assertNotIn('scanner_source_mode', data)
        self.assertEqual(data['scanner_sha256'], scanner.LEGACY_SCANNER[2])
        self.assertEqual(scanner.historical_errors(self.root, data), [])

    def test_graph_and_resource_bytes_match_actual_old_producer(self):
        old, new = self.legacy(), copy.deepcopy(self.current)
        old.pop('scanner_sha256')
        new.pop('scanner_sha256')
        new.pop('scanner_source_mode')
        self.assertEqual(old, new)

    def test_legacy_uses_code_checkout_independently_of_target_history(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.git('cat-file', '-e', scanner.LEGACY_SCANNER[1] + '^{commit}')
        self.assertEqual(scanner.historical_errors(self.root, self.legacy()), [])

    def test_current_cannot_claim_legacy_by_omitting_mode(self):
        data = copy.deepcopy(self.current)
        data.pop('scanner_source_mode')
        self.assertTrue(any('scanner changed' in e for e in scanner.historical_errors(self.root, data)))

    def test_legacy_cannot_claim_current_mode(self):
        data = self.legacy()
        data['scanner_source_mode'] = 'current'
        self.assertTrue(any('scanner changed' in e for e in scanner.historical_errors(self.root, data)))

    def test_bad_signature_is_rejected_in_both_modes(self):
        for data in [copy.deepcopy(self.current), self.legacy()]:
            data['scanner_sha256'] = '0' * 64
            self.assertTrue(any('scanner changed' in e for e in scanner.historical_errors(self.root, data)))

    def test_unknown_null_or_path_mode_cannot_select_code(self):
        for mode in [None, '', 'legacy', '../outside.py', {}, [], 1, True]:
            with self.subTest(mode=mode):
                data = copy.deepcopy(self.current)
                data['scanner_source_mode'] = mode
                self.assertTrue(any('unknown migration scanner' in e
                                    for e in scanner.historical_errors(self.root, data)))

    def test_missing_legacy_commit_never_falls_back_to_current(self):
        data = self.legacy()
        name, _, digest = scanner.LEGACY_SCANNER
        with patch.object(scanner, 'LEGACY_SCANNER', (name, '0' * 40, digest)):
            self.assertTrue(any('source unavailable' in e for e in scanner.historical_errors(self.root, data)))

    def test_invalid_pin_cannot_be_replaced_by_live_matching_hash(self):
        data = self.legacy()
        name, commit, _ = scanner.LEGACY_SCANNER
        with patch.object(scanner, 'LEGACY_SCANNER', (name, commit, self.current['scanner_sha256'])):
            self.assertTrue(any('source unavailable' in e for e in scanner.historical_errors(self.root, data)))

    def test_foreign_git_environment_does_not_choose_target_or_code(self):
        data = self.legacy()
        config, index = self.root / '.git/config', self.root / '.git/index'
        before = config.read_bytes(), index.read_bytes()
        with patch.dict('os.environ', {'GIT_DIR': str(self.root / 'missing.git'),
                                      'GIT_INDEX_FILE': str(self.root / 'wrong-index'),
                                      'GIT_CONFIG_COUNT': '1', 'GIT_CONFIG_KEY_0': 'core.bare',
                                      'GIT_CONFIG_VALUE_0': 'true'}):
            self.assertEqual(scanner.historical_errors(self.root, data), [])
        self.assertEqual(before, (config.read_bytes(), index.read_bytes()))
        self.assertFalse((self.root / 'wrong-index').exists())

    def test_changed_current_source_is_detected_without_executing_it(self):
        changed = self.root / 'changed-scanner.py'
        changed.write_bytes(Path(scanner.__file__).read_bytes() + b'\n# later code\n')
        with patch.object(scanner, '__file__', str(changed)):
            self.assertTrue(any('scanner changed' in e
                                for e in scanner.historical_errors(self.root, self.current)))


if __name__ == '__main__':
    unittest.main()
