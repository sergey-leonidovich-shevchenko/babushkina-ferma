"""Проверяет настоящие публичные команды после переноса на вложенные адреса."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tools.common.paths import project_root

ROOT = project_root(__file__)


class CompatibilityCliTests(unittest.TestCase):
    """Запускает launcher из чужой cwd без изменения каталогов игры и чужого Git."""

    def call(self, command, *arguments, cwd):
        """Исполняет реальный процесс с чужими путями и возвращает оба потока/код отказа."""
        environment = dict(os.environ, PYTHONPATH=str(cwd), GIT_DIR=str(cwd / 'absent.git'),
            GIT_WORK_TREE=str(cwd), GIT_INDEX_FILE=str(cwd / 'foreign-index'))
        return subprocess.run([sys.executable, str(ROOT / 'tools/run.py'), command,
            *map(str, arguments)], cwd=cwd, env=environment, capture_output=True, text=True,
            timeout=30)

    def test_cycle_writer_uses_external_paths_and_preserves_costs(self):
        """Платная обратная связь остаётся кандидатом, бесплатный подграф не получает ложный цикл."""
        with tempfile.TemporaryDirectory(prefix='compatibility writer ') as directory:
            folder = Path(directory).resolve()
            source, output = folder / 'catalog.json', folder / 'cycles.json'
            data = {'research': [], 'recipes': [
                {'id': 'forward', 'inputs': {'log': 2}, 'output': 'plank', 'count': 3,
                 'station': 'workbench', 'seconds': 2, 'energy': 3},
                {'id': 'reverse', 'inputs': {'plank': 1}, 'output': 'log', 'count': 1,
                 'station': 'workbench', 'seconds': 0, 'energy': 0}]}
            source.write_text(json.dumps(data)); before = source.read_bytes()
            result = self.call('qa.compatibility.farm_cycles', source, output, cwd=folder)
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(output.read_text())
            self.assertEqual(len(report['components']), 1)
            self.assertEqual(report['components'][0]['materials'], ['log', 'plank'])
            self.assertEqual(report['components'][0]['transforms'][0]['energy'], 3)
            self.assertEqual(report['free_components'], [])
            self.assertEqual(source.read_bytes(), before)
            self.assertFalse((folder / 'foreign-index').exists())

    def test_bad_catalog_fails_before_creating_output(self):
        """Повреждённый внешний каталог даёт ненулевой код и не создаёт ложный отчёт."""
        with tempfile.TemporaryDirectory(prefix='compatibility invalid ') as directory:
            folder = Path(directory).resolve()
            source, output = folder / 'bad.json', folder / 'missing-report.json'
            source.write_text('{')
            result = self.call('qa.compatibility.farm_cycles', source, output, cwd=folder)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())
            self.assertEqual(source.read_text(), '{')
            self.assertFalse((folder / 'foreign-index').exists())

    def test_alchemy_reader_preserves_legacy_catalog_rejection_from_foreign_cwd(self):
        """Вложенная команда достигает прежней проверки148 предметов, а не теряет свой source-root."""
        with tempfile.TemporaryDirectory(prefix='compatibility reader ') as directory:
            folder = Path(directory).resolve()
            result = self.call('qa.compatibility.check_alchemy_reports', cwd=folder)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn('assert len(herbs) == 24 and len(catalog["items"]) == 148', result.stderr)
            self.assertIn('AssertionError', result.stderr)
            self.assertNotIn('FileNotFoundError', result.stderr)
            self.assertEqual(list(folder.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
