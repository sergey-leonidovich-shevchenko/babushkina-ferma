"""Source-only probe of nine actual collectors; stop before native launch, never accept partial proof."""
from contextlib import ExitStack
import hashlib
import importlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-context-prepare'
sys.path[:0] = [str(Q), str(Q / 'tools')]
from tools.common.git import git_environment
from tools.qa.performance import perf_contract_collect as common
from tools.qa.world.source_inputs import input_path
from tools.qa.world import test_world_context as fixtures

class NativeBoundary(Exception):
    """The real source manifest exists; no open/Godot invocation takes place."""

class GroundProducerProbe(unittest.TestCase):
    git = fixtures.WorldContextTests.git
    repository = fixtures.WorldContextTests.repository
    foreign_context = fixtures.WorldContextTests.foreign_context

    def check_source(self, family):
        collector = importlib.import_module(family + '_collect')
        verifier = importlib.import_module(family + '_verify')
        with tempfile.TemporaryDirectory(prefix='Ground actual source producer ') as directory:
            own = Path(directory) / 'own project with spaces'
            own.mkdir()
            for logical in sorted(set(collector.SOURCES) | {'VERSION'}):
                target = own / logical
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(input_path(Q, logical), target)
            subprocess.run(['git', 'init', '-q', str(own)], env=git_environment(), check=True)
            self.git(own, 'add', '.')
            self.git(own, '-c', 'user.name=Ground QA', '-c', 'user.email=qa@example.invalid', 'commit', '-qm', 'actual source fixture')
            base = self.git(own, 'rev-parse', 'HEAD')
            stable = {n: (own / '.git' / n).read_bytes() for n in ['index', 'config']}
            output = own / 'source output'
            with self.foreign_context(), ExitStack() as stack:
                stack.enter_context(patch.object(collector, 'ROOT', own))
                stack.enter_context(patch.object(common, 'ROOT', own))
                stack.enter_context(patch.object(collector, 'jobs', return_value=[]))
                context = stack.enter_context(patch.object(collector, 'context', side_effect=NativeBoundary))
                with self.assertRaises(NativeBoundary):
                    collector.collect(output)
                context.assert_called_once_with()
                source = json.loads((output / 'source.json').read_text())
                self.assertEqual(source['base_commit'], base)
                self.assertFalse(source['complete'])
                self.assertEqual(set(source['sources']), set(collector.SOURCES))
                self.assertEqual(source['base_sources'], source['sources'])
                for logical, digest in source['sources'].items():
                    original = (own / logical).read_bytes()
                    self.assertEqual((output / 'inputs' / logical).read_bytes(), original)
                    self.assertEqual(hashlib.sha256(original).hexdigest(), digest)
                with self.assertRaises(ValueError):
                    verifier.provenance(output)
            for name, raw in stable.items():
                self.assertEqual((own / '.git' / name).read_bytes(), raw)
            record = R / 'producer-probes' / (family + '.json')
            record.parent.mkdir(exist_ok=True)
            record.write_text(json.dumps({'collector': family, 'fixture_commit': base,
                'source_fields': len(source['sources']), 'all_current_Git_archived_bytes_equal': True,
                'own_index_config_preserved': True, 'foreign_index_config_preserved': True,
                'complete': False, 'partial_provenance_rejected': True,
                'native_frames': 0, 'Game': False, 'capture_boundary': 'context before open/Godot',
                'temporary_fixture_removed_after_test': True}, indent=2) + '\n')

    def test_axial_road(self): self.check_source('axial_road')
    def test_decoration(self): self.check_source('decoration')
    def test_garden(self): self.check_source('garden')
    def test_ground_edge(self): self.check_source('ground_edge')
    def test_ground_seasons(self): self.check_source('ground_seasons')
    def test_meadow(self): self.check_source('meadow')
    def test_plaza(self): self.check_source('plaza')
    def test_road_network(self): self.check_source('road_network')
    def test_terrain_revision(self): self.check_source('terrain_revision')

if __name__ == '__main__':
    unittest.main(verbosity=2)
