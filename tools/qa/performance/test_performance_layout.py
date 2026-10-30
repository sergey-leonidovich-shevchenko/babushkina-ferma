"""Physical-layout contracts exercise actual Git/archive/child I/O, without native FPS admission."""
from contextlib import contextmanager
import importlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.common.git import git_environment
from tools.qa.performance import perf_contract as contract
from tools.qa.performance import perf_contract_collect as collector
from tools.qa.performance import performance_gate as canonical_gate


class PerformanceLayoutTests(unittest.TestCase):
    """Preserves historical names while current collectors use the approved physical source layout."""

    def fixture(self, parent, name):
        root = parent / name
        root.mkdir()
        for logical in collector.FROZEN:
            physical = collector.CURRENT_SOURCES.get(logical, logical)
            target = root / physical
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(collector.ROOT / physical, target)
            if logical != physical:
                stale = root / logical
                stale.parent.mkdir(parents=True, exist_ok=True)
                stale.write_text('WRONG obsolete source, never archive this file')
        subprocess.run(['git', 'init', '-q', str(root)], env=git_environment(), check=True)
        subprocess.run(['git', '-C', str(root), 'add', '.'], env=git_environment(), check=True)
        subprocess.run(['git', '-C', str(root), '-c', 'user.name=Performance layout QA',
            '-c', 'user.email=qa@example.invalid', 'commit', '-qm', name],
            env=git_environment(), check=True)
        return root

    @contextmanager
    def foreign(self, root):
        previous = Path.cwd()
        stable = {n: (root / '.git' / n).read_bytes() for n in ['index', 'config']}
        try:
            os.chdir(root)
            with patch.dict(os.environ, GIT_DIR=str(root / '.git'), GIT_WORK_TREE=str(root),
                GIT_INDEX_FILE=str(root / '.git/index'), GIT_CONFIG_COUNT='1',
                GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true'):
                environment = dict(os.environ)
                yield
                self.assertEqual(environment, dict(os.environ))
        finally:
            os.chdir(previous)
            for n, raw in stable.items():
                self.assertEqual((root / '.git' / n).read_bytes(), raw)

    def collect_empty(self, parent):
        project = self.fixture(parent, 'own source')
        foreign = self.fixture(parent, 'foreign source')
        output = parent / 'fresh archive'
        # Only process-inventory is isolated. Git, path resolution, copying, hashing and writes are real.
        with self.foreign(foreign), patch.object(collector, 'ROOT', project), patch.object(collector, 'jobs', return_value=[]):
            collector.collect(output, [])
        return project, output

    def test_current_producer_archives_canonical_bytes_under_old_logical_keys(self):
        """Two real repositories and stale old paths must not redirect the fresh source archive."""
        with tempfile.TemporaryDirectory(prefix='performance layout archive ') as directory:
            project, output = self.collect_empty(Path(directory).resolve())
            metadata = json.loads((output / 'source.json').read_text())
            self.assertEqual(metadata['source_layout'], 'qa-performance-v1')
            self.assertEqual(set(metadata['sources']), set(collector.FROZEN))
            self.assertTrue(metadata['complete'])
            for logical, digest in metadata['sources'].items():
                physical = collector.CURRENT_SOURCES.get(logical, logical)
                self.assertEqual((output / 'instrumentation' / logical).read_bytes(), (project / physical).read_bytes())
                self.assertEqual(digest, collector.sha(project / physical))
                if physical != logical:
                    self.assertNotEqual((project / logical).read_bytes(), (project / physical).read_bytes())
                    self.assertFalse((output / 'instrumentation' / physical).exists())
            with patch.object(contract, 'ROOT', project):
                self.assertEqual(contract.provenance(output, []), metadata)

    def test_real_child_witness_receives_canonical_capture_and_previous_arguments(self):
        """The collector launches a real isolated fake-open child; this proves argv/file I/O, never GPU/FPS."""
        with tempfile.TemporaryDirectory(prefix='performance layout launch ') as directory:
            parent = Path(directory).resolve()
            project = self.fixture(parent, 'own source')
            foreign = self.fixture(parent, 'foreign source')
            binary = parent / 'bin'
            binary.mkdir()
            fake = binary / 'open'
            fake.write_text('#!/usr/bin/env python3\nimport json,sys\nfrom pathlib import Path\n'
                'out=Path(next(v.split("=",1)[1] for v in sys.argv if v.startswith("--output=")))\n'
                'out.mkdir()\n(out/"argv-witness.json").write_text(json.dumps(sys.argv[1:]))\n')
            fake.chmod(0o755)
            output = parent / 'fresh output'
            schedule = [['fixture', 0, 'fixture-only']]
            with self.foreign(foreign), patch.object(collector, 'ROOT', project), patch.object(collector, 'jobs', return_value=[]), \
                patch.object(collector, 'context', return_value={'fixture_only': True}), \
                patch.dict(os.environ, PATH=str(binary) + os.pathsep + os.environ['PATH']):
                collector.collect(output, schedule)
            env = json.loads((output / 'fixture/environment.json').read_text())
            args = json.loads((output / 'fixture/argv-witness.json').read_text())
            self.assertEqual(args, env['command'][1:])
            self.assertEqual(args[args.index('--script') + 1], 'res://tools/qa/performance/perf_contract_capture.gd')
            self.assertIn('--seconds=0', args)
            self.assertIn('--fault=fixture-only', args)
            self.assertEqual(args[args.index('--path') + 1], str(project))
            self.assertEqual(env['exit_code'], 0)
            self.assertEqual(env['jobs_after'], [])
            with patch.object(contract, 'ROOT', project):
                self.assertEqual(contract.provenance(output, schedule)['source_layout'], 'qa-performance-v1')

    def test_layout_metadata_is_closed_and_legacy_is_explicit(self):
        self.assertEqual(contract.capture_script({}), 'res://tools/perf_contract_capture.gd')
        self.assertEqual(contract.capture_script({'source_layout': 'qa-performance-v1'}),
            'res://tools/qa/performance/perf_contract_capture.gd')
        for invalid in ['', None, 'other-version', '../../outside.gd', {'path': 'anything'}]:
            with self.assertRaisesRegex(ValueError, 'unknown source layout'):
                contract.capture_script({'source_layout': invalid})

    def test_unknown_layout_cannot_relabel_a_real_historical_packet(self):
        with tempfile.TemporaryDirectory(prefix='performance layout invalid ') as directory:
            output = Path(directory) / 'native'
            shutil.copytree(contract.REPORT / 'native', output)
            source = json.loads((output / 'source.json').read_text())
            source['source_layout'] = '../../outside'
            (output / 'source.json').write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError, 'unknown source layout'):
                contract.provenance(output, contract.SCHEDULE)

    def test_layout_and_launch_must_match_on_actual_old_trace(self):
        original = contract.REPORT / 'native/repeat-1'
        policy = contract.read(contract.REPORT / 'native/instrumentation/docs/reports/visual-overhaul/vbase-002/profile.json')
        device = next(d for d in policy['devices'] if d['id'] == policy['selected_device'])
        legacy = contract.capture_script({})
        current = contract.capture_script({'source_layout': 'qa-performance-v1'})
        expected = contract.inspect_run(original, 30, device)
        with tempfile.TemporaryDirectory(prefix='performance layout trace ') as directory:
            target = Path(directory) / 'trace'
            shutil.copytree(original, target)
            # Old traces retain the original URI; current layout cannot silently admit it.
            with self.assertRaisesRegex(ValueError, 'wrong launch'):
                contract.inspect_run(target, 30, device, current)
            env = contract.read(target / 'environment.json')
            env['command'][env['command'].index('--script') + 1] = current
            (target / 'environment.json').write_text(json.dumps(env))
            self.assertEqual(contract.inspect_run(target, 30, device, current), expected)
            with self.assertRaisesRegex(ValueError, 'wrong launch'):
                contract.inspect_run(target, 30, device, legacy)
            env['command'].append('--headless')
            (target / 'environment.json').write_text(json.dumps(env))
            with self.assertRaisesRegex(ValueError, 'wrong launch'):
                contract.inspect_run(target, 30, device, current)

    def test_fresh_archive_bytes_and_existing_target_stay_protected(self):
        with tempfile.TemporaryDirectory(prefix='performance layout tamper ') as directory:
            project, output = self.collect_empty(Path(directory).resolve())
            signature = (output / 'source.json').read_bytes()
            with self.assertRaisesRegex(ValueError, 'fresh collection output required'):
                collector.collect(output, [])
            self.assertEqual((output / 'source.json').read_bytes(), signature)
            (output / 'instrumentation/tools/perf_contract_collect.py').write_text('changed')
            with patch.object(contract, 'ROOT', project), self.assertRaisesRegex(ValueError, 'collector archive changed'):
                contract.provenance(output, [])

    def test_public_import_is_same_module_and_mutable_sampler_is_shared(self):
        """The archived redraw consumer imports the old public name and assigns gate.SAMPLER."""
        public = importlib.import_module('performance_gate')
        self.assertIs(public, canonical_gate)
        protocol = importlib.import_module('performance_protocol')
        self.assertIs(protocol, importlib.import_module('tools.qa.performance.performance_protocol'))
        with tempfile.TemporaryDirectory(prefix='performance sampler identity ') as directory:
            sampler = Path(directory) / 'sampler.gd'
            sampler.write_text('isolated mutable sampler witness')
            with patch.object(public, 'SAMPLER', sampler):
                self.assertIs(canonical_gate.SAMPLER, sampler)
                self.assertEqual(canonical_gate.SAMPLER.read_bytes(), sampler.read_bytes())


    def test_frozen_executable_import_graph_still_works_without_rewriting_archive(self):
        """Actual archived consumers import the public protocol first as well as after the gate."""
        relative = [
            'docs/reports/visual-overhaul/vfoliage-006/redraw-scheduling/verify.py',
            'docs/reports/visual-overhaul/vfoliage-006/causal-investigation/analysis/verify.py',
            'docs/reports/visual-overhaul/vfoliage-006/causal-investigation/instrumentation/causal_capture.py',
            'docs/reports/visual-overhaul/vfoliage-006/ci-performance/fixed-gate/instrumentation/performance_gate.py',
        ]
        with tempfile.TemporaryDirectory(prefix='performance frozen imports ') as directory:
            foreign = Path(directory).resolve()
            for name in relative:
                source = collector.ROOT / name
                before = source.read_bytes()
                own_snapshot = source.parent / 'performance_protocol.py'
                if own_snapshot.is_file():
                    # This frozen copy intentionally owns its protocol; it never used the project root.
                    assertion = ('import performance_protocol;from pathlib import Path;'
                        + 'assert Path(performance_protocol.__file__).resolve() == Path(' + repr(str(own_snapshot)) + ');')
                else:
                    assertion = ('import performance_protocol;from tools.qa.performance import performance_protocol as canonical;'
                        + 'assert performance_protocol is canonical;')
                child = ('import sys,runpy;sys.path.insert(0,' + repr(str(source.parent)) + ');'
                    + 'runpy.run_path(' + repr(str(source)) + ',run_name="qa_frozen_import");'
                    + assertion + 'print("FROZEN_IMPORT_OK")')
                process = subprocess.run([sys.executable, '-c', child], cwd=foreign,
                    env=dict(git_environment(), PYTHONPATH=str(foreign), PYTHONDONTWRITEBYTECODE="1"), capture_output=True, text=True, timeout=30)
                self.assertEqual(process.returncode, 0, name + ': ' + process.stderr)
                self.assertIn('FROZEN_IMPORT_OK', process.stdout)
                self.assertEqual(source.read_bytes(), before)
            self.assertEqual(list(foreign.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
