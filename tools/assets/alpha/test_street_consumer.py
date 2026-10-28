"""Реальный потребитель alpha не должен выбирать Git из чужого окружения."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import village_street_verify as street
from tools.common.git import git_environment


class StreetGitConsumerTests(unittest.TestCase):
    """Исполняет настоящий provenance с файловыми/Git I/O, сохраняя чужой index/config."""

    def test_real_phase_provenance_ignores_foreign_git_and_cwd(self):
        with tempfile.TemporaryDirectory(prefix='street consumer ') as directory:
            foreign = Path(directory).resolve() / 'foreign git'
            foreign.mkdir()
            subprocess.run(['git', 'init', '-q', str(foreign)], env=git_environment(), check=True)
            (foreign / 'sentinel').write_text('foreign data')
            subprocess.run(['git', '-C', str(foreign), 'add', 'sentinel'], env=git_environment(), check=True)
            index, config = foreign / '.git/index', foreign / '.git/config'
            before = index.read_bytes(), config.read_bytes()
            cwd = Path.cwd()
            try:
                os.chdir(foreign)
                with patch.dict(os.environ, GIT_DIR=str(foreign / '.git'), GIT_WORK_TREE=str(foreign),
                    GIT_INDEX_FILE=str(index), GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true'):
                    environment = dict(os.environ)
                    for phase in ['before', 'after']:
                        folder = street.REPORT / 'native' / phase
                        self.assertEqual(street.provenance(folder, phase), street.load(folder / 'source.json'))
                    self.assertEqual(dict(os.environ), environment)
            finally:
                os.chdir(cwd)
            self.assertEqual((index.read_bytes(), config.read_bytes()), before)

    def test_missing_code_base_is_rejected_before_reading_artifacts(self):
        with tempfile.TemporaryDirectory(prefix='street missing base ') as directory:
            folder = Path(directory)
            data = street.load(street.REPORT / 'native/before/source.json')
            data['base_commit'] = '0' * 40
            (folder / 'source.json').write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'missing base commit'):
                street.provenance(folder, 'before')


if __name__ == '__main__':
    unittest.main()
