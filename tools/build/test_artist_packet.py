#!/usr/bin/env python3
"""Проверяет целостность передачи художнику на отдельных временных копиях."""
import copy
import json
import hashlib
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.common.git import git_environment

import tools.build.artist_packet as packet


class ArtistPacketTests(unittest.TestCase):
    """Не позволяет подменить принятые источники или выдать комплект за приёмку игры."""

    def setUp(self):
        """Копирует только комплект и его зависимости, сохраняя доступ к настоящей Git-истории."""
        self.temp = tempfile.TemporaryDirectory(prefix='farm-artist-packet-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = packet.read(packet.ROOT, packet.REPORT/'references.json')
        paths = [row['file'] for row in self.data['references']]
        paths += ['wiki/articles/artist-packet.md']
        paths += [str(packet.REPORT/name) for name in ['references.json', 'palette.svg', 'modules.csv', 'handoff-example.json']]
        for path in paths:
            target = self.root/path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(packet.ROOT/path, target)
        (self.root/'.git').symlink_to(packet.ROOT/'.git', target_is_directory=True)

    def errors(self):
        """Проверяет копию с независимым изменяемым манифестом."""
        return packet.verify(self.root, self.data)

    def test_complete_packet(self):
        """Сценарий: полный комплект. Исходное состояние: точная копия. Результат: источники и производные совпадают."""
        self.assertEqual(self.errors(), [])

    def test_changed_picture(self):
        """Сценарий: порча рисунка. Исходное состояние: сохранён старый SHA. Результат: подмена отклоняется."""
        row = next(r for r in self.data['references'] if r['file'].endswith('rejected-diagonal.png'))
        (self.root/row['file']).write_bytes(b'corrupt image')
        self.assertTrue(any('SHA256 mismatch' in e for e in self.errors()))

    def test_resigned_picture_still_requires_git_bytes(self):
        """Сценарий: переподпись. Исходное состояние: байты и SHA заменены вместе. Результат: Git-основание обнаруживает подмену."""
        import hashlib
        row = next(r for r in self.data['references'] if r['file'].endswith('rejected-diagonal.png'))
        (self.root/row['file']).write_bytes(b'resigned')
        row['sha256'] = hashlib.sha256(b'resigned').hexdigest()
        self.assertTrue(any('differs from Git source' in e for e in self.errors()))

    def test_reference_boundary(self):
        """Сценарий: чужой путь. Исходное состояние: абсолютный путь или переход выше проекта. Результат: чтение запрещено."""
        original = copy.deepcopy(self.data)
        for path in ['/private/tmp/private.png', '../private.png']:
            with self.subTest(path=path):
                self.data = copy.deepcopy(original)
                self.data['references'][0]['file'] = path
                self.assertTrue(any('escapes project' in e for e in self.errors()))

    def test_missing_and_duplicate_reference(self):
        """Сценарий: неполный список. Исходное состояние: потеряна или повторена ссылка. Результат: комплект не принимается."""
        self.data['references'].append(copy.deepcopy(self.data['references'][0]))
        self.assertIn('duplicate reference', self.errors())
        self.data['references'] = []
        self.assertIn('missing reference coverage', self.errors())

    def test_missing_git_history(self):
        """Сценарий: нет истории. Исходное состояние: commit отсутствует. Результат: текущие файлы не заменяют источник."""
        self.data['source_commit'] = '0'*40
        self.assertTrue(any('differs from Git source' in e for e in self.errors()))
        self.assertTrue(any('differs from Git source: docs/SPRITE_STANDARD.md' in e for e in self.errors()))

    def test_live_document_can_evolve(self):
        """Живая команда меняется; принятый комплект всё ещё проверяет точную историческую редакцию."""
        (self.root/'docs/SPRITE_STANDARD.md').write_text('Current supported authoring command\n')
        self.assertEqual(self.errors(), [])

    def test_live_format_document_can_evolve(self):
        """Актуальная команда формата меняется, прежний комплект читает его Git-редакцию."""
        (self.root/'docs/VISUAL_RESOURCE_FORMAT.md').write_text('Current canonical format command\n')
        self.assertEqual(self.errors(), [])

    def test_format_document_signature_and_missing_history_are_rejected(self):
        """Переподпись и недоступный commit не разрешают заменить формат живым текстом."""
        path = self.root/'docs/VISUAL_RESOURCE_FORMAT.md'
        path.write_bytes(b'New live format documentation')
        row = next(row for row in self.data['references'] if row['file'] == 'docs/VISUAL_RESOURCE_FORMAT.md')
        original = row['sha256']
        row['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.assertTrue(any('differs from Git source: docs/VISUAL_RESOURCE_FORMAT.md' in e for e in self.errors()))
        row['sha256'] = original
        self.data['source_commit'] = '0'*40
        self.assertTrue(any('differs from Git source: docs/VISUAL_RESOURCE_FORMAT.md' in e for e in self.errors()))

    def test_format_document_symlink_cannot_escape(self):
        """Известный исторический формат не разрешает текущий symlink за корень проекта."""
        with tempfile.TemporaryDirectory(prefix='foreign format document ') as folder:
            outside = Path(folder)/'format.md'
            outside.write_text('foreign')
            path = self.root/'docs/VISUAL_RESOURCE_FORMAT.md'
            path.unlink()
            path.symlink_to(outside)
            self.assertTrue(any('reference escapes project: docs/VISUAL_RESOURCE_FORMAT.md' in e for e in self.errors()))

    def test_unlisted_live_document_is_still_checked(self):
        """Другие документы комплекта сохраняют проверку живых байтов и Git-источника."""
        name = 'docs/epics/visual-overhaul-2026-10/ART_REQUIREMENTS.md'
        (self.root/name).write_bytes(b'Changed requirements are not accepted by this refactor')
        self.assertTrue(any('reference SHA256 mismatch: ' + name in e for e in self.errors()))

    def test_resigned_document_still_requires_history(self):
        """Подпись текущего текста не заменяет закреплённую версию документа в Git."""
        path = self.root/'docs/SPRITE_STANDARD.md'
        path.write_bytes(b'New live documentation')
        row = next(row for row in self.data['references'] if row['file'] == 'docs/SPRITE_STANDARD.md')
        row['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.assertTrue(any('differs from Git source: docs/SPRITE_STANDARD.md' in e for e in self.errors()))

    def test_document_symlink_cannot_escape(self):
        """Исторический якорь не разрешает ссылку текущего checkout за границу проекта."""
        with tempfile.TemporaryDirectory(prefix='foreign artist document ') as folder:
            outside = Path(folder)/'document.md'
            outside.write_text('foreign')
            path = self.root/'docs/SPRITE_STANDARD.md'
            path.unlink()
            path.symlink_to(outside)
            self.assertTrue(any('reference escapes project: docs/SPRITE_STANDARD.md' in e for e in self.errors()))

    def test_foreign_git_context_cannot_choose_history(self):
        """Чужой настоящий репозиторий/index/config не выбирает источник и не меняется читателем."""
        foreign = self.root/'foreign repository'
        foreign.mkdir()
        subprocess.run(['git', 'init', str(foreign)], check=True, capture_output=True, env=git_environment())
        (foreign/'sentinel').write_text('preserve index')
        subprocess.run(['git', '-C', str(foreign), 'add', 'sentinel'], check=True, capture_output=True, env=git_environment())
        index = foreign/'.git/index'
        config = foreign/'.git/config'
        before = (index.read_bytes(), config.read_bytes())
        overrides = {'GIT_DIR': str(foreign/'.git'), 'GIT_WORK_TREE': str(foreign),
                     'GIT_INDEX_FILE': str(index), 'GIT_CONFIG_COUNT': '1',
                     'GIT_CONFIG_KEY_0': 'core.bare', 'GIT_CONFIG_VALUE_0': 'true'}
        with patch.dict(os.environ, overrides):
            environment = dict(os.environ)
            self.assertEqual(self.errors(), [])
            self.assertEqual(dict(os.environ), environment)
        self.assertEqual((index.read_bytes(), config.read_bytes()), before)

    def test_derived_files_cannot_drift(self):
        """Сценарий: ручная смена размеров или цветов. Исходное состояние: источники прежние. Результат: производные устарели."""
        for name in ['palette.svg', 'modules.csv', 'handoff-example.json']:
            with self.subTest(name=name):
                path = self.root/packet.REPORT/name
                old = path.read_bytes()
                path.write_text('{}' if name.endswith('.json') else 'changed')
                self.assertTrue(any('stale' in e for e in self.errors()))
                path.write_bytes(old)

    def test_no_runtime_acceptance(self):
        """Сценарий: завышенная приёмка. Исходное состояние: отчёт заявляет FPS и новый runtime. Результат: отказ."""
        self.data['runtime_changed'] = True
        self.data['performance_accepted'] = True
        self.assertIn('artist packet cannot claim runtime/performance acceptance', self.errors())


if __name__ == '__main__':
    unittest.main()
