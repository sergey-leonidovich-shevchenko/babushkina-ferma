"""Real Ground readers/producers against a canonical fixture tree; no native/Game/FPS acceptance."""
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.qa.ground import axial_road_collect as axial_collect
from tools.qa.ground import axial_road_verify as axial
from tools.qa.ground import decoration_collect as decoration_collect
from tools.qa.ground import decoration_verify as decoration
from tools.qa.ground import garden_collect as garden_collect
from tools.qa.ground import garden_verify as garden
from tools.qa.ground import ground_edge_collect as edge_collect
from tools.qa.ground import ground_edge_verify as edge
from tools.qa.ground import ground_layers as layers
from tools.qa.ground import ground_seasons_collect as seasons_collect
from tools.qa.ground import ground_seasons_verify as seasons
from tools.qa.ground import meadow_collect as meadow_collect
from tools.qa.ground import meadow_verify as meadow
from tools.qa.ground import plaza_collect as plaza_collect
from tools.qa.ground import plaza_verify as plaza
from tools.qa.ground import road_network_collect as roads_collect
from tools.qa.ground import road_network_verify as roads
from tools.qa.ground import terrain_revision_collect as revision_collect
from tools.qa.ground import terrain_revision_verify as revision
from tools.qa.world import test_world_context as fixtures
from tools.qa.performance import perf_contract_collect as common
from tools.assets.contracts.source_paths import MOVED_PATHS, current_source
from tools.qa.art.current_paths import MOVED_PATHS as ART_PATHS

ROOT = layers.ROOT
READERS = {'axial_road': axial, 'decoration': decoration, 'garden': garden, 'ground_edge': edge,
    'ground_layers': layers, 'ground_seasons': seasons, 'meadow': meadow, 'plaza': plaza,
    'road_network': roads, 'terrain_revision': revision}
COLLECTORS = {'axial_road': axial_collect, 'decoration': decoration_collect, 'garden': garden_collect,
    'ground_edge': edge_collect, 'ground_layers': layers, 'ground_seasons': seasons_collect,
    'meadow': meadow_collect, 'plaza': plaza_collect, 'road_network': roads_collect,
    'terrain_revision': revision_collect}


class GroundLayoutTests(unittest.TestCase):
    """Git, copy, hashes and index are real; only inventory/context/open are explicit QA fixtures."""
    git = fixtures.WorldContextTests.git
    repository = fixtures.WorldContextTests.repository
    foreign_context = fixtures.WorldContextTests.foreign_context

    def future_name(self, name):
        """The accepted original plan independently chooses fixture destinations, before and after move."""
        plan = json.loads((ROOT / 'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())
        row = plan['assignments'].get(name)
        if row and row['family'] == 'ground' and name != row['target']:
            return row['target']
        targets = {mapping[name] for mapping in [MOVED_PATHS, ART_PATHS] if name in mapping}
        self.assertLessEqual(len(targets), 1)
        return next(iter(targets), name)

    def commit(self, own):
        """Commit only an owned temporary source tree, retaining its real immutable object identity."""
        self.git(own, 'add', '.')
        self.git(own, '-c', 'user.name=Ground layout QA', '-c', 'user.email=qa@example.invalid',
            'commit', '-qm', 'canonical source-only Ground fixture')
        return self.git(own, 'rev-parse', 'HEAD')

    def source_fixture(self, module, own):
        """Reuse exact archived input bytes under old keys and commit them at independent new addresses."""
        original = module.REPORT / 'native'
        source = json.loads((original / 'source.json').read_text())
        for name, digest in source['sources'].items():
            raw = (original / 'inputs' / name).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), digest)
            target = own / self.future_name(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        (own / 'VERSION').write_text('source-only-fixture\n')
        base = self.commit(own)
        report = own / 'docs/reports/ground-source-only'
        folder = report / 'native'
        folder.mkdir(parents=True)
        for name in source['sources']:
            target = folder / 'inputs' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((original / 'inputs' / name).read_bytes())
        source['base_commit'] = base
        source['base_sources'] = {name: source['sources'][name] for name in source['base_sources']}
        source['artifacts'] = {}
        source['fixture_scope'] = {'complete_inputs': True, 'native_frames': 0,
            'native_capture': False, 'performance_eligible': False}
        (folder / 'source.json').write_text(json.dumps(source, indent=2) + '\n')
        self.git(own, 'add', '.')
        self.assertFalse(any(p for p in folder.rglob('*.png') if 'inputs' not in p.relative_to(folder).parts))
        return report, folder, source

    def reader(self, name):
        """Accept the complete source envelope; the full verifier must still reject absent native frames."""
        module = READERS[name]
        with tempfile.TemporaryDirectory(prefix='Ground actual history ') as directory:
            own = self.repository(Path(directory).resolve() / 'owned project')
            report, folder, source = self.source_fixture(module, own)
            stable = {n: (own / '.git' / n).read_bytes() for n in ['index', 'config']}
            with patch.object(module, 'ROOT', own), patch.object(module, 'REPORT', report), self.foreign_context():
                self.assertEqual(module.provenance(folder), source)
                with self.assertRaises((FileNotFoundError, ValueError)):
                    module.verify(folder)
            for n, raw in stable.items():
                self.assertEqual((own / '.git' / n).read_bytes(), raw)

    def current_fixture(self, module, own):
        """Actual current bytes are placed according to the original migration plan, not the new reader."""
        for name in sorted(set(module.SOURCES) | {'VERSION'}):
            source = current_source(ROOT, ART_PATHS.get(name, name))
            self.assertTrue(source.is_file(), name)
            target = own / self.future_name(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())
        return self.commit(own)

    def bound(self, module, own, parent):
        """Use a real failed fake-open process; it records argv/cwd and never invokes Godot."""
        binary = parent / 'fake bin'
        binary.mkdir()
        fake = binary / 'open'
        fake.write_text('#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\n'
            'Path(os.environ["FARM_GROUND_OPEN_WITNESS"]).write_text(json.dumps({"argv":sys.argv[1:],"cwd":os.getcwd()}))\n'
            'raise SystemExit(17)\n')
        fake.chmod(0o755)
        stack = ExitStack()
        stack.enter_context(patch.object(module, 'ROOT', own))
        stack.enter_context(patch.object(common, 'ROOT', own))
        stack.enter_context(patch.object(module, 'jobs', return_value=[]))
        stack.enter_context(patch.object(module, 'context', return_value={'source_only_fixture': True}))
        stack.enter_context(patch.dict(os.environ, PATH=str(binary) + os.pathsep + os.environ['PATH'],
            FARM_GROUND_OPEN_WITNESS=str(parent / 'open.json'), PYTHONDONTWRITEBYTECODE='1'))
        return stack

    def producer(self, name):
        """Archive/hash/read current canonical inputs, then fail explicitly at fake-open17 with no admission."""
        module, verifier = COLLECTORS[name], READERS[name]
        with tempfile.TemporaryDirectory(prefix='Ground actual producer ') as directory:
            parent = Path(directory).resolve()
            own = self.repository(parent / 'owned project')
            base = self.current_fixture(module, own)
            stable = {n: (own / '.git' / n).read_bytes() for n in ['index', 'config']}
            output = parent / 'new archive'
            with self.foreign_context(), self.bound(module, own, parent):
                with self.assertRaises(ValueError):
                    module.collect(output)
                source = json.loads((output / 'source.json').read_text())
                self.assertEqual(source['base_commit'], base)
                self.assertFalse(source['complete'])
                self.assertEqual(set(source['sources']), set(module.SOURCES))
                expected = set(module.SOURCES) - (set(module.NEW) if module is layers else set())
                self.assertEqual(set(source['base_sources']), expected)
                for logical, digest in source['sources'].items():
                    raw = (own / self.future_name(logical)).read_bytes()
                    self.assertEqual((output / 'inputs' / logical).read_bytes(), raw)
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), digest)
                    if logical in expected:
                        self.assertEqual(source['base_sources'][logical], digest)
                witness = json.loads((parent / 'open.json').read_text())
                argv = witness['argv']
                self.assertEqual(witness['cwd'], str(own))
                self.assertEqual(argv[argv.index('--path') + 1], str(own))
                logical_capture = 'tools/' + name + '_capture.gd'
                self.assertEqual(argv[argv.index('--script') + 1], 'res://' + self.future_name(logical_capture))
                self.assertEqual(json.loads((output / '1152/environment.json').read_text())['exit_code'], 17)
                self.assertFalse(any(output.rglob('*.png')))
                with self.assertRaises(ValueError):
                    verifier.provenance(output)
            for n, raw in stable.items():
                self.assertEqual((own / '.git' / n).read_bytes(), raw)

    def test_axial_history(self): self.reader('axial_road')
    def test_decoration_history(self): self.reader('decoration')
    def test_garden_history(self): self.reader('garden')
    def test_edge_history(self): self.reader('ground_edge')
    def test_layers_history(self): self.reader('ground_layers')
    def test_seasons_history(self): self.reader('ground_seasons')
    def test_meadow_history(self): self.reader('meadow')
    def test_plaza_history(self): self.reader('plaza')
    def test_roads_history(self): self.reader('road_network')
    def test_revision_history(self): self.reader('terrain_revision')
    def test_axial_producer(self): self.producer('axial_road')
    def test_decoration_producer(self): self.producer('decoration')
    def test_garden_producer(self): self.producer('garden')
    def test_edge_producer(self): self.producer('ground_edge')
    def test_layers_producer(self): self.producer('ground_layers')
    def test_seasons_producer(self): self.producer('ground_seasons')
    def test_meadow_producer(self): self.producer('meadow')
    def test_plaza_producer(self): self.producer('plaza')
    def test_roads_producer(self): self.producer('road_network')
    def test_revision_producer(self): self.producer('terrain_revision')

    def test_missing_canonical_ground_input_never_reads_stale_legacy(self):
        """Both collector families must fail on the exact missing canonical address, without launching."""
        for name in ['ground_edge', 'ground_layers']:
            with self.subTest(module=name), tempfile.TemporaryDirectory(prefix='Ground missing input ') as directory:
                parent = Path(directory).resolve()
                own = self.repository(parent / 'owned project')
                module = COLLECTORS[name]
                self.current_fixture(module, own)
                legacy = 'tools/' + name + '_capture.gd'
                canonical = own / self.future_name(legacy)
                canonical.unlink()
                (own / legacy).write_text('stale physical legacy input\n')
                output = parent / 'must remain partial'
                with self.foreign_context(), self.bound(module, own, parent):
                    with self.assertRaises(FileNotFoundError) as missing:
                        module.collect(output)
                    self.assertEqual(Path(missing.exception.filename), canonical)
                self.assertFalse((parent / 'open.json').exists())
                self.assertFalse((output / 'source.json').exists())

    def test_ambiguous_ground_git_aliases_are_rejected(self):
        """Actual surface readers may never silently choose between two historical Ground aliases."""
        for name in ['ground_edge', 'meadow']:
            with self.subTest(module=name), tempfile.TemporaryDirectory(prefix='Ground ambiguous history ') as directory:
                own = self.repository(Path(directory).resolve() / 'owned project')
                module = READERS[name]
                report, folder, source = self.source_fixture(module, own)
                legacy = 'tools/' + name + '_capture.gd'
                (own / legacy).write_bytes((own / self.future_name(legacy)).read_bytes())
                source['base_commit'] = self.commit(own)
                (folder / 'source.json').write_text(json.dumps(source, indent=2) + '\n')
                self.git(own, 'add', '.')
                with patch.object(module, 'ROOT', own), patch.object(module, 'REPORT', report), self.foreign_context():
                    with self.assertRaisesRegex(ValueError, 'ambiguous'):
                        module.provenance(folder)


if __name__ == '__main__':
    unittest.main()
