"""Проверяет настоящую Git-границу старых alpha/slicing collectors и нового export-layout."""
from __future__ import annotations

from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import tools.assets.alpha.alpha_proof as alpha
import tools.assets.slicing.slice_proof as proof
import tools.assets.slicing.slice_audit as slicing
from tools.common.git import git_environment
from tools.common.paths import project_root
from tools.assets.contracts.source_paths import current_source

ROOT = project_root(__file__)
COMMIT = 'd609ab4fa6d82d6d013265183f018b8836abf7cc'
NAMES = ('tools/alpha_capture.gd', 'tools/slice_capture.gd', 'tools/slice_legacy_capture.gd',
         'tools/slice_export.gd', 'tools/slice_catalogs.gd')


def digest(raw):
    """Сравнивает фактические файлы с Git, не выводя ожидаемые SHA из таблицы reader."""
    return hashlib.sha256(raw).hexdigest()


class ProcessingHistoryTests(unittest.TestCase):
    """Данные не выбирают Git кода; изменение текущего exporter не становится старой подписью."""

    def setUp(self):
        """Копирует пять настоящих файлов и минимальные live-данные в новый корень."""
        self.temp = tempfile.TemporaryDirectory(prefix='processing history ')
        self.addCleanup(self.temp.cleanup)
        self.parent = Path(self.temp.name).resolve()
        self.root = self.parent / 'data'
        (self.root / 'tools').mkdir(parents=True)
        for name in NAMES:
            target = current_source(self.root, name)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(current_source(ROOT, name), target)
        (self.root / 'scripts').mkdir()
        (self.root / 'scripts/provider.gd').write_text('live source')
        (self.root / 'assets/game').mkdir(parents=True)
        (self.root / 'assets/game/data.json').write_text('{}')
        self.expected = {name: digest(subprocess.check_output(
            ['git', '-C', str(ROOT), 'show', COMMIT + ':' + name], env=git_environment())) for name in NAMES}

    def collectors(self):
        """Исполняет все три реальных historical reader, включая проверку текущих копий."""
        return {NAMES[0]: alpha.capture_sha(self.root),
                NAMES[1]: proof.capture_sha(self.root, NAMES[1]),
                NAMES[2]: proof.capture_sha(self.root, NAMES[2])}

    def test_real_known_collectors_match_exact_git(self):
        """Три исторических collector читаются из точного исходного commit."""
        self.assertEqual(self.collectors(), {n: self.expected[n] for n in NAMES[:3]})

    def test_changed_current_copy_is_still_rejected(self):
        """Исторический pin не разрешает изменённый текущий source в проверяемой копии."""
        for name in NAMES[:3]:
            with self.subTest(source=name):
                path = current_source(self.root, name)
                original = path.read_bytes()
                path.write_bytes(b'changed copy')
                with self.assertRaisesRegex(ValueError, 'implementation differs'):
                    self.collectors()
                path.write_bytes(original)

    def test_changed_code_checkout_keeps_old_git_signature(self):
        """Настоящий shared clone содержит новые live-байты, но legacy остаётся на прежнем Git blob."""
        code = self.parent / 'code checkout'
        subprocess.run(['git', 'clone', '-q', '--shared', '--no-checkout', str(ROOT), str(code)],
                       env=git_environment(), check=True, capture_output=True)
        for name in NAMES:
            raw = b'current changed source: ' + name.encode()
            (current_source(code, name)).parent.mkdir(parents=True, exist_ok=True)
            (current_source(code, name)).write_bytes(raw)
            (current_source(self.root, name)).write_bytes(raw)
        with ExitStack() as stack:
            for module in (alpha, proof, slicing):
                stack.enter_context(patch.object(module, 'ROOT', code))
            self.assertEqual(self.collectors(), {n: self.expected[n] for n in NAMES[:3]})
            for name in NAMES[3:]:
                self.assertEqual(slicing.legacy_exporter_sha(self.root, name), self.expected[name])
            self.assertNotEqual(slicing.inputs(self.root), slicing.inputs(self.root, historical=True))

    def test_missing_code_history_cannot_borrow_data_history(self):
        """Код без D609 отказывает, даже если data Git действительно содержит D609."""
        data = self.parent / 'data with history'
        subprocess.run(['git', 'clone', '-q', '--shared', '--no-checkout', str(ROOT), str(data)],
                       env=git_environment(), check=True, capture_output=True)
        shutil.copytree(self.root, data, dirs_exist_ok=True)
        self.root = data
        for name in NAMES:
            self.assertEqual(digest(subprocess.check_output(
                ['git', '-C', str(data), 'show', COMMIT + ':' + name], env=git_environment())), self.expected[name])
        code = self.parent / 'no history'
        code.mkdir()
        subprocess.run(['git', 'init', '-q', str(code)], env=git_environment(), check=True)
        for name in NAMES:
            (current_source(code, name)).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(current_source(self.root, name), current_source(code, name))
        with ExitStack() as stack:
            for module in (alpha, proof, slicing):
                stack.enter_context(patch.object(module, 'ROOT', code))
            with self.assertRaisesRegex(ValueError, 'historical source'):
                self.collectors()
            with self.assertRaisesRegex(ValueError, 'historical source'):
                slicing.inputs(self.root, historical=True)

    def packaged(self):
        """Собирает будущий layout по известным двум путям, без выбора адресов из metadata."""
        for old, new in slicing.PACKAGED_EXPORTERS.items():
            path = self.root / new
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(current_source(ROOT, old).read_bytes())
        return {'tool_source_paths': dict(slicing.PACKAGED_EXPORTERS),
            'inputs_sha256': slicing.inputs(self.root, source_paths=slicing.PACKAGED_EXPORTERS),
            'source_sha256': digest((self.root / slicing.PACKAGED_EXPORTERS[NAMES[3]]).read_bytes())}

    def test_packaged_inputs_bind_current_code_and_live_data(self):
        """Текущий режим реагирует на изменение exporter и runtime JSON."""
        data = self.packaged()
        self.assertEqual(slicing.input_errors(self.root, data), [])
        runtime = self.root / 'assets/game/data.json'
        runtime.write_text('{"changed":true}')
        self.assertTrue(slicing.input_errors(self.root, data))
        runtime.write_text('{}')
        (self.root / slicing.PACKAGED_EXPORTERS[NAMES[3]]).write_bytes(b'changed exporter')
        self.assertTrue(slicing.input_errors(self.root, data))

    def test_packaged_metadata_cannot_drop_or_choose_unknown_path(self):
        """Пустая/частичная/произвольная карта и старый self-SHA не подменяют свежий exporter."""
        original = self.packaged()
        for kind in ('missing', 'partial', 'outside', 'null', 'old-sha'):
            data = json.loads(json.dumps(original))
            if kind == 'missing':
                data.pop('tool_source_paths')
            elif kind == 'partial':
                data['tool_source_paths'].pop(NAMES[4])
            elif kind == 'outside':
                data['tool_source_paths'][NAMES[3]] = '../outside.gd'
            elif kind == 'null':
                data['tool_source_paths'] = None
            else:
                data['source_sha256'] = self.expected[NAMES[3]]
            with self.subTest(kind=kind):
                self.assertTrue(slicing.input_errors(self.root, data))

    def test_packaged_source_symlink_is_rejected(self):
        """Даже известная metadata-карта не разрешает читать exporter через symlink."""
        data = self.packaged()
        path = self.root / slicing.PACKAGED_EXPORTERS[NAMES[3]]
        outside = self.parent / 'outside.gd'
        outside.write_bytes(path.read_bytes())
        path.unlink()
        path.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            slicing.input_errors(self.root, data)

    def test_foreign_git_environment_and_index_are_unchanged(self):
        """Посторонние GIT_* не выбирают источник и не изменяют чужой index/config."""
        foreign = self.parent / 'foreign git'
        subprocess.run(['git', 'init', '-q', str(foreign)], env=git_environment(), check=True)
        (foreign / 'sentinel').write_text('foreign')
        subprocess.run(['git', '-C', str(foreign), 'add', 'sentinel'], env=git_environment(), check=True)
        index, config = foreign / '.git/index', foreign / '.git/config'
        before = (index.read_bytes(), config.read_bytes())
        with patch.dict(os.environ, GIT_DIR=str(foreign / '.git'), GIT_WORK_TREE=str(foreign),
            GIT_INDEX_FILE=str(index), GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true'):
            environment = dict(os.environ)
            self.assertEqual(self.collectors(), {n: self.expected[n] for n in NAMES[:3]})
            for name in NAMES[3:]:
                self.assertEqual(slicing.legacy_exporter_sha(self.root, name), self.expected[name])
            self.assertEqual(dict(os.environ), environment)
        self.assertEqual((index.read_bytes(), config.read_bytes()), before)


if __name__ == '__main__':
    unittest.main()
