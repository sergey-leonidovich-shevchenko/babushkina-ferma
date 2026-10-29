"""Real surface producers must archive canonical helper bytes under the historical logical name."""
from contextlib import contextmanager, ExitStack
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import grass_compare_collect as grass
import grass_methods as grass_reader
from tools.qa.ground import ground_layers as ground
from tools.common.git import git_environment
from tools.assets.contracts.source_paths import current_source
from tools.common.paths import project_root
from tools.qa.performance import perf_contract_collect as common_collector

ROOT = project_root(__file__)
LEGACY = 'tools/perf_contract_collect.py'
CANONICAL = 'tools/qa/performance/perf_contract_collect.py'
OLD = '9a2ad81fb77282c4f52261e694653b28b21f01b8'
MOVED = 'f134dd9b7f2cf0741a0ace939d26fc247178cbad'


class CaptureBoundary(Exception):
    """Stops the real producer at context(), after source.json and before native Popen."""


class SurfaceProducerTests(unittest.TestCase):
    """Hash/copy/Git/provenance are real; native sessions use an explicitly fake-open child."""

    def git(self, root, *arguments):
        return subprocess.check_output(['git', '-c', 'core.hooksPath=' + str(root / 'absent-hooks'),
            '-C', str(root), *arguments], env=git_environment(), stderr=subprocess.DEVNULL)

    def commit(self, root):
        self.git(root, 'add', '.')
        self.git(root, '-c', 'user.name=Surface QA', '-c', 'user.email=qa@example.invalid', 'commit', '-qm', 'surface fixture')
        return self.git(root, 'rev-parse', 'HEAD').decode().strip()

    def fixture(self, parent):
        root = parent / 'own project with spaces'
        root.mkdir()
        # This independent fixture always lays out the real current implementation physically.
        for logical in sorted(set(grass.FROZEN) | set(ground.SOURCES)):
            physical = str(current_source(ROOT,logical).relative_to(ROOT))
            target = root / physical
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / physical, target)
        self.git(root, 'init', '-q')
        self.commit(root)
        return root

    @contextmanager
    def foreign(self, parent):
        root = parent / 'foreign Git'
        root.mkdir()
        (root / 'foreign.txt').write_text('unrelated repository')
        self.git(root, 'init', '-q')
        self.commit(root)
        stable = {n: (root / '.git' / n).read_bytes() for n in ['index', 'config']}
        previous = Path.cwd()
        try:
            os.chdir(root)
            with patch.dict(os.environ, GIT_DIR=str(root / '.git'), GIT_WORK_TREE=str(root),
                GIT_INDEX_FILE=str(root / '.git/index'), GIT_CONFIG_COUNT='1',
                GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true'):
                environment = dict(os.environ)
                yield
                self.assertEqual(dict(os.environ), environment)
        finally:
            os.chdir(previous)
            for name, raw in stable.items():
                self.assertEqual((root / '.git' / name).read_bytes(), raw)

    @contextmanager
    def bound(self, producer, project, parent, stop=False):
        binary = parent / 'fake bin'
        binary.mkdir(exist_ok=True)
        fake = binary / 'open'
        fake.write_text('#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\n'
            'with Path(os.environ["FARM_SURFACE_OPEN_CALLS"]).open("a") as f:f.write(json.dumps(sys.argv[1:])+"\\n")\n'
            'out=Path(next(v.split("=",1)[1] for v in sys.argv if v.startswith("--output=")))\n'
            'out.mkdir()\n(out/"surface-open-witness.json").write_text(json.dumps(sys.argv[1:]))\n')
        fake.chmod(0o755)
        with ExitStack() as stack:
            for module in [producer, common_collector, grass_reader]:
                stack.enter_context(patch.object(module, 'ROOT', project))
            stack.enter_context(patch.object(producer, 'jobs', return_value=[]))
            stack.enter_context(patch.object(producer, 'native_pid', return_value=None))
            stack.enter_context(patch.object(producer, 'context', side_effect=CaptureBoundary if stop else None,
                return_value={'fixture_only': True}))
            stack.enter_context(patch.dict(os.environ, PATH=str(binary) + os.pathsep + os.environ['PATH'],
                FARM_SURFACE_OPEN_CALLS=str(parent / 'open-calls.jsonl'), PYTHONDONTWRITEBYTECODE='1'))
            yield

    def collect(self, producer, output):
        return producer.collect(output, 'quality') if producer is grass else producer.collect(output)

    def read_provenance(self, producer, output):
        return grass_reader.provenance(output, 'quality') if producer is grass else ground.provenance(output)

    def assert_archive(self, producer, project, output):
        source = json.loads((output / 'source.json').read_text())
        names = grass.FROZEN if producer is grass else ground.SOURCES
        self.assertEqual(set(source['sources']), set(names))
        namespace = 'instrumentation' if producer is grass else 'inputs'
        archived = output / namespace / LEGACY
        self.assertEqual(archived.read_bytes(), (project / CANONICAL).read_bytes())
        self.assertEqual(source['sources'][LEGACY], hashlib.sha256((project / CANONICAL).read_bytes()).hexdigest())
        self.assertFalse((output / namespace / CANONICAL).exists())
        self.assertEqual(source['base_commit'], self.git(project, 'rev-parse', 'HEAD').decode().strip())
        return source

    def test_grass_real_collect_and_reader_keep_logical_archive_namespace(self):
        with tempfile.TemporaryDirectory(prefix='grass producer real ') as directory:
            parent = Path(directory).resolve()
            project = self.fixture(parent)
            output = parent / 'new grass archive'
            with self.foreign(parent), self.bound(grass, project, parent):
                self.collect(grass, output)
                source = self.assert_archive(grass, project, output)
                self.assertTrue(source['complete'])
                self.assertEqual(source['schedule'], grass.schedule('quality'))
                self.assertEqual(self.read_provenance(grass, output), source)
                # Fake argv receipts never satisfy the actual native-frame verifier.
                with self.assertRaises(FileNotFoundError):
                    grass_reader.quality(output)
            self.assertEqual(len((parent / 'open-calls.jsonl').read_text().splitlines()), 2)

    def test_ground_real_collect_and_reader_use_canonical_git_base_helper(self):
        with tempfile.TemporaryDirectory(prefix='ground producer real ') as directory:
            parent = Path(directory).resolve()
            project = self.fixture(parent)
            # A regular stale old file must not become a fallback or a historical Git alias.
            (project / LEGACY).write_text('wrong untracked stale helper')
            output = parent / 'new ground archive'
            with self.foreign(parent), self.bound(ground, project, parent):
                self.collect(ground, output)
                source = self.assert_archive(ground, project, output)
                self.assertEqual(source['base_sources'][LEGACY], source['sources'][LEGACY])
                self.assertEqual(self.read_provenance(ground, output), source)
                with self.assertRaises(FileNotFoundError):
                    ground.verify(output)
            self.assertEqual(len((parent / 'open-calls.jsonl').read_text().splitlines()), 2)

    def test_ground_archives_real_sources_before_first_native_launch(self):
        with tempfile.TemporaryDirectory(prefix='ground prelaunch ') as directory:
            parent = Path(directory).resolve()
            project = self.fixture(parent)
            output = parent / 'ground prelaunch archive'
            with self.bound(ground, project, parent, stop=True), self.assertRaises(CaptureBoundary):
                ground.collect(output)
            source = self.assert_archive(ground, project, output)
            self.assertFalse(source['complete'])
            self.assertEqual(source['base_sources'][LEGACY], source['sources'][LEGACY])
            self.assertFalse((parent / 'open-calls.jsonl').exists())

    def test_grass_empty_schedule_archives_sources_without_native_admission(self):
        with tempfile.TemporaryDirectory(prefix='grass prelaunch ') as directory:
            parent = Path(directory).resolve()
            project = self.fixture(parent)
            output = parent / 'grass prelaunch archive'
            with self.bound(grass, project, parent), patch.object(grass, 'schedule', return_value=[]):
                grass.collect(output, 'quality')
                source = self.assert_archive(grass, project, output)
                self.assertTrue(source['complete'])
                self.assertEqual(source['schedule'], [])
                # The real reader retains the original quality schedule; it is never patched here.
                with self.assertRaisesRegex(ValueError, 'schedule'):
                    grass_reader.provenance(output, 'quality')
            self.assertFalse((parent / 'open-calls.jsonl').exists())

    def test_missing_canonical_helper_never_falls_back_to_stale_old_file(self):
        for producer in [grass, ground]:
            with self.subTest(producer=producer.__name__), tempfile.TemporaryDirectory(prefix='surface missing ') as directory:
                parent = Path(directory).resolve()
                project = self.fixture(parent)
                (project / CANONICAL).unlink()
                (project / LEGACY).write_text('wrong old fallback')
                output = parent / 'missing helper output'
                with self.bound(producer, project, parent), self.assertRaises(FileNotFoundError):
                    self.collect(producer, output)
                self.assertFalse((output / 'source.json').exists())
                self.assertFalse((parent / 'open-calls.jsonl').exists())

    def test_ground_historical_lookup_uses_exact_old_and_new_git_bytes(self):
        old = subprocess.check_output(['git', '-C', str(ROOT), 'show', OLD + ':' + LEGACY], env=git_environment())
        current = subprocess.check_output(['git', '-C', str(ROOT), 'show', MOVED + ':' + CANONICAL], env=git_environment())
        self.assertEqual(hashlib.sha256(old).hexdigest(), '0ad2b4f4d73846c17b09af76c05cfe8cc5eefc65892118ad5c681eebc6a88e8a')
        with tempfile.TemporaryDirectory(prefix='surface history ') as directory, self.foreign(Path(directory).resolve()):
            self.assertEqual(ground.base_bytes(OLD, LEGACY), old)
            self.assertEqual(ground.base_bytes(MOVED, LEGACY), current)

    def test_ambiguous_helper_git_aliases_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix='surface ambiguous ') as directory:
            parent = Path(directory).resolve()
            project = self.fixture(parent)
            (project / LEGACY).write_text('second tracked helper alias')
            commit = self.commit(project)
            with self.bound(ground, project, parent), self.assertRaisesRegex(ValueError, 'ambiguous'):
                ground.base_bytes(commit, LEGACY)

    def test_resigned_helper_archive_cannot_override_git_base(self):
        for producer in [grass, ground]:
            with self.subTest(producer=producer.__name__), tempfile.TemporaryDirectory(prefix='surface corrupt ') as directory:
                parent = Path(directory).resolve()
                project = self.fixture(parent)
                output = parent / 'fresh archive'
                with self.bound(producer, project, parent):
                    self.collect(producer, output)
                    source = self.assert_archive(producer, project, output)
                    namespace = 'instrumentation' if producer is grass else 'inputs'
                    archived = output / namespace / LEGACY
                    archived.write_bytes(archived.read_bytes() + b'\n# changed archive\n')
                    source['sources'][LEGACY] = hashlib.sha256(archived.read_bytes()).hexdigest()
                    (output / 'source.json').write_text(json.dumps(source))
                    with self.assertRaisesRegex(ValueError, 'differs from Git base|unreviewed'):
                        self.read_provenance(producer, output)

    def test_existing_output_and_original_signed_packets_remain_protected(self):
        for producer in [grass, ground]:
            with self.subTest(producer=producer.__name__), tempfile.TemporaryDirectory(prefix='surface existing ') as directory:
                parent = Path(directory).resolve()
                project = self.fixture(parent)
                output = parent / 'existing archive'
                output.mkdir()
                sentinel = output / 'keep.txt'
                sentinel.write_text('never clobber')
                with self.bound(producer, project, parent), self.assertRaisesRegex(ValueError, 'fresh'):
                    self.collect(producer, output)
                self.assertEqual(list(output.iterdir()), [sentinel])
                self.assertEqual(sentinel.read_text(), 'never clobber')
                self.assertFalse((parent / 'open-calls.jsonl').exists())
        # Existing signed packets use their old Git layout and are read without writes.
        packets = [grass_reader.REPORT / 'bench', ground.REPORT / 'native']
        stable = [(p / 'source.json').read_bytes() for p in packets]
        with tempfile.TemporaryDirectory(prefix='surface old packets ') as directory, self.foreign(Path(directory).resolve()):
            self.assertTrue(grass_reader.provenance(packets[0], 'bench')['complete'])
            self.assertTrue(ground.provenance(packets[1])['complete'])
        self.assertEqual([(p / 'source.json').read_bytes() for p in packets], stable)


if __name__ == '__main__':
    unittest.main()
