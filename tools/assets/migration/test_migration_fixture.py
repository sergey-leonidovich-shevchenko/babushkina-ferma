"""Упражняет настоящий producer внешнего проекта, его namespace и пять фаз миграции."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.common.git import git_environment
from tools.common.paths import project_root
from tools.assets.migration import migration_fixture as fixture

ROOT = project_root(__file__)
BASE = 'd609ab4fa6d82d6d013265183f018b8836abf7cc'
PHASES = ('baseline', 'dual', 'unadapted', 'retired', 'rollback')


def digest(path):
    """Сравнивает настоящие байты сохранённого документа и текстур между фазами."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


class MigrationFixtureTests(unittest.TestCase):
    """Не подменяет closure/Git/copy и не собирает проект вручную вместо create."""

    def setUp(self):
        """Резервирует только родителя; каталог нового проекта должен создать producer."""
        self.temporary = tempfile.TemporaryDirectory(prefix='real migration producer ')
        self.addCleanup(self.temporary.cleanup)
        self.parent = Path(self.temporary.name).resolve()
        self.target = self.parent / 'new external project'

    def assert_project(self, case):
        """Проверяет три результата producer и прежний путь collector внутри стенда."""
        legacy = self.target / 'tools/migration_capture.gd'
        self.assertTrue(legacy.is_file())
        self.assertEqual(legacy.read_bytes(), Path(fixture.__file__).with_name('migration_capture.gd').read_bytes())
        self.assertFalse((self.target / 'tools/assets').exists())
        self.assertIn('config/name="VPIPELINE-009 isolated fixture"', (self.target / 'project.godot').read_text())
        self.assertEqual(json.loads((self.target / fixture.CASE).read_text()), case)
        draft = json.loads((self.target / 'saved-draft.json').read_text())
        self.assertEqual(draft['version'], 6)
        self.assertEqual([row['asset_path'] for row in draft['objects']], [case['paths'][s] for s in fixture.SIDES])
        self.assertTrue(all(row['notes'] == 'Preserve this note' for row in draft['objects']))
        self.assertTrue(all((self.target / name).is_file() for name in case['copied_files']))

    def test_real_create_and_all_five_phases_preserve_namespace_and_draft(self):
        """Настоящий live producer проходит staging/контроли/откат с прежним collector URI."""
        case = fixture.create(ROOT, self.target)
        self.assert_project(case)
        self.assertEqual(case['copied_files'], fixture.closure(ROOT))
        draft = digest(self.target / 'saved-draft.json')
        probe = digest(self.target / 'tools/migration_capture.gd')
        images = {s: digest(self.target / case['paths'][s].removeprefix('res://')) for s in fixture.SIDES}
        imports = {s: digest(Path(str(self.target / case['paths'][s].removeprefix('res://')) + '.import')) for s in fixture.SIDES}
        for name in PHASES:
            with self.subTest(phase=name):
                state = fixture.phase(self.target, name)
                self.assertEqual(state['phase'], name)
                self.assertEqual(digest(self.target / 'saved-draft.json'), draft)
                self.assertEqual(digest(self.target / 'tools/migration_capture.gd'), probe)
                catalog = json.loads((self.target / 'assets/game/visual_resources.json').read_text())
                for side in fixture.SIDES:
                    old = self.target / case['paths'][side].removeprefix('res://')
                    new = self.target / 'assets/game/interiors/migration_pilot' / old.name
                    moved = name in ('dual', 'unadapted', 'retired')
                    self.assertEqual(old.exists(), name != 'retired')
                    self.assertEqual(new.exists(), moved)
                    selected = new if moved else old
                    self.assertEqual(digest(selected), images[side])
                    self.assertEqual(catalog['textures']['oak_table_' + side]['file'], 'res://' + selected.relative_to(self.target).as_posix())
                    if old.exists():
                        self.assertEqual(digest(Path(str(old) + '.import')), imports[side])

    def test_real_git_create_ignores_foreign_git_context(self):
        """Исторические входы читаются из ROOT, чужие index/config и окружение не меняются."""
        foreign = self.parent / 'foreign repository'
        foreign.mkdir()
        env = git_environment()
        subprocess.run(['git', 'init', '-q', str(foreign)], env=env, check=True)
        (foreign / 'sentinel').write_text('foreign')
        subprocess.run(['git', '-C', str(foreign), 'add', 'sentinel'], env=env, check=True)
        index, config = foreign / '.git/index', foreign / '.git/config'
        before = (index.read_bytes(), config.read_bytes())
        overrides = {'GIT_DIR': str(foreign / '.git'), 'GIT_WORK_TREE': str(foreign),
            'GIT_INDEX_FILE': str(index), 'GIT_CONFIG_COUNT': '1',
            'GIT_CONFIG_KEY_0': 'core.bare', 'GIT_CONFIG_VALUE_0': 'true'}
        with patch.dict(os.environ, overrides):
            environment = dict(os.environ)
            case = fixture.create(ROOT, self.target, BASE)
            self.assert_project(case)
            self.assertEqual(case['copied_files'], fixture.closure(ROOT, BASE))
            self.assertEqual(dict(os.environ), environment)
        self.assertEqual((index.read_bytes(), config.read_bytes()), before)

    def test_existing_repository_and_unknown_phase_refuse_without_changes(self):
        """Ошибочные цели и фаза не записывают проект, sentinel или существующий стенд."""
        self.target.mkdir()
        marker = self.target / 'sentinel'
        marker.write_bytes(b'keep me')
        with self.assertRaisesRegex(ValueError, 'new directory outside'):
            fixture.create(ROOT, self.target)
        self.assertEqual(list(self.target.iterdir()), [marker])
        self.assertEqual(marker.read_bytes(), b'keep me')
        inside = ROOT / 'tmp/refactor03-fixture-must-not-create'
        self.assertFalse(inside.exists())
        with self.assertRaisesRegex(ValueError, 'new directory outside'):
            fixture.create(ROOT, inside)
        self.assertFalse(inside.exists())
        with self.assertRaisesRegex(ValueError, 'external isolated fixture'):
            fixture.phase(ROOT, 'baseline')
        valid = self.parent / 'valid external fixture'
        fixture.create(ROOT, valid)
        before = {p.relative_to(valid).as_posix(): digest(p) for p in valid.rglob('*') if p.is_file()}
        with self.assertRaisesRegex(ValueError, 'unknown fixture phase'):
            fixture.phase(valid, 'unknown')
        self.assertEqual({p.relative_to(valid).as_posix(): digest(p) for p in valid.rglob('*') if p.is_file()}, before)


if __name__ == '__main__':
    unittest.main()
