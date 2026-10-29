"""Контроли реальной карты, исторического proof и текущего архивирования входов."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.common.paths import project_root
from tools.qa.art.current_paths import MOVED_PATHS, captured_paths, recorded_paths, source_path


class CurrentPathTests(unittest.TestCase):
    def test_mapping_matches_accepted_plan(self):
        """Текущая таблица точно соответствует отдельному art-standard семейству старой ведомости."""
        root = project_root(__file__)
        plan = json.loads((root / 'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())
        expected = {name: row['target'] for name, row in plan['assignments'].items() if row['family'] == 'art-standard'}
        self.assertEqual(dict(MOVED_PATHS), expected)
        self.assertEqual(len(expected), 26)

    def test_current_sources_exist(self):
        """Все назначенные исходники/UID лежат в новом месте; обычные пути не меняются."""
        root = project_root(__file__)
        for logical, actual in MOVED_PATHS.items():
            self.assertEqual(source_path(root, logical), root / actual)
            self.assertTrue((root / actual).is_file())
        self.assertEqual(source_path(root, 'project.godot'), root / 'project.godot')

    def test_legacy_and_current_records(self):
        """Старый пустой mapper и ровно полный новый mapper имеют отдельные допустимые состояния."""
        names = ['tools/visual_scale_capture.gd', 'project.godot']
        expected = {'tools/visual_scale_capture.gd': 'tools/qa/art/visual_scale_capture.gd'}
        self.assertEqual(captured_paths(names), expected)
        self.assertEqual(recorded_paths(names, {}), {})
        self.assertEqual(recorded_paths(names, expected), expected)

    def test_unknown_partial_and_unsafe_records_rejected(self):
        """Metadata не выбирает произвольный файл и не скрывает неполную карту moved-членов."""
        names = ['tools/visual_scale_capture.gd', 'tools/visual_modules_capture.gd']
        wrong = [None, [], {'tools/visual_scale_capture.gd': 'tools/qa/art/visual_scale_capture.gd'},
                 {'tools/visual_scale_capture.gd': '../outside'}, {'extra': 'project.godot'}, {'project.godot': 7}]
        for record in wrong:
            with self.subTest(record=record), self.assertRaises(ValueError):
                recorded_paths(names, record)

    def test_unsafe_logical_names_rejected(self):
        """Absolute/traversal/двойные разделители не превращаются в адрес current-source."""
        with tempfile.TemporaryDirectory() as directory:
            for name in ['../outside', '/tmp/outside', 'tools//file', 'tools/./file', '.git/config', 'tools\\file', ':magic', 'a\0b']:
                with self.subTest(name=name), self.assertRaises(ValueError):
                    source_path(Path(directory), name)

    def test_external_symlink_rejected(self):
        """Текущий collector не читает файл за пределами своего проекта через symlink."""
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            root = parent / 'project'
            root.mkdir()
            (root / 'outside').symlink_to(parent / 'external')
            with self.assertRaises(ValueError):
                source_path(root, 'outside')

    def test_returned_record_does_not_mutate_mapping(self):
        """Изменение экземпляра metadata не меняет общую известную карту."""
        logical = 'tools/visual_scale_capture.gd'
        record = recorded_paths([logical], captured_paths([logical]))
        record[logical] = 'changed'
        self.assertEqual(MOVED_PATHS[logical], 'tools/qa/art/visual_scale_capture.gd')
        with self.assertRaises(TypeError):
            MOVED_PATHS[logical] = 'changed'

    def test_actual_pilot_archive_keeps_logical_keys(self):
        """Настоящий producer кладёт новый физический source под прежним логическим именем архива."""
        from tools.qa.world import pilot_static_collect as collector
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            logical = 'tools/visual_modules_capture.gd'
            physical = root / MOVED_PATHS[logical]
            physical.parent.mkdir(parents=True)
            physical.write_bytes(b'actual moved module\n')
            (root / 'project.godot').write_bytes(b'fixture\n')
            folder = root / 'capture'
            with patch.object(collector, 'ROOT', root):
                hashes = collector.archive_inputs(folder, [logical, 'project.godot'])
            self.assertEqual(set(hashes), {logical, 'project.godot'})
            self.assertEqual((folder / 'inputs' / logical).read_bytes(), physical.read_bytes())
            self.assertFalse((root / logical).exists())


if __name__ == '__main__':
    unittest.main()
