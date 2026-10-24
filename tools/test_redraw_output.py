#!/usr/bin/env python3
"""Exercise the real shell wrapper with a fake engine; never launch Godot in these tests."""

from pathlib import Path
import hashlib
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FAKE_ENGINE = r'''
from pathlib import Path
import os, sys
with Path(os.environ['REDRAW_WRAPPER_CALLS']).open('a') as calls:
    calls.write(repr(sys.argv[1:]) + '\n')
if '--version' in sys.argv or '--editor' in sys.argv:
    raise SystemExit(0)
script = sys.argv[sys.argv.index('--script') + 1]
if script.endswith('test_game.gd'):
    print('TESTS: 1 passed, 0 failed')
    raise SystemExit(0)
mode = next(arg.split('=', 1)[1] for arg in sys.argv if arg.startswith('--redraw-mode='))
scenario = os.environ.get('REDRAW_WRAPPER_CASE', 'success')
output = os.environ.get('FARM_REDRAW_TEST_OUTPUT', '')
folder = Path(output) / mode if output else None
if folder and folder.exists():
    print('ERROR: fresh redraw output required')
    raise SystemExit(1)
if scenario == 'failure-before-directory':
    print('ERROR: current experiment failed before creating mode')
    raise SystemExit(1)
if folder:
    if scenario == 'mode-symlink':
        folder.symlink_to(Path(os.environ['REDRAW_WRAPPER_PRIOR']), target_is_directory=True)
    else:
        folder.mkdir()
        (folder / 'frames.jsonl').write_text('CURRENT ' + mode + '\n')
        if scenario == 'engine-already-exists':
            (folder / 'engine.txt').write_text('CURRENT ENGINE SENTINEL\n')
        if scenario == 'engine-symlink':
            (folder / 'engine.txt').symlink_to(os.environ['REDRAW_WRAPPER_LOG_TARGET'])
if scenario == 'failure-after-directory':
    print('ERROR: current experiment failed after creating mode')
    raise SystemExit(1)
if scenario == 'zero-exit-error':
    print('ERROR: current experiment error despite exit zero')
print('REDRAW: 90 passed, 0 failed')
'''


def snapshot(folder: Path) -> dict:
    """Preserve names, symlink targets and every previous file SHA, not just one sentinel."""
    result = {}
    for path in [folder, *sorted(folder.rglob('*'))] if folder.is_dir() else [folder]:
        name = str(path.relative_to(folder.parent))
        if path.is_symlink():
            result[name] = ['symlink', os.readlink(path)]
        elif path.is_file():
            result[name] = ['file', hashlib.sha256(path.read_bytes()).hexdigest()]
        else:
            result[name] = ['directory']
    return result


class RedrawOutputTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='redraw wrapper ')
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.runner = self.folder / 'run_tests.sh'
        shutil.copyfile(ROOT / 'run_tests.sh', self.runner)
        fake_script = self.folder / 'engine.py'
        fake_script.write_text(FAKE_ENGINE)
        self.engine = self.folder / 'fake-godot'
        self.engine.write_text(
            '#!/bin/sh\nexec ' + shlex.quote(sys.executable) + ' '
            + shlex.quote(str(fake_script)) + ' "$@"\n'
        )
        self.engine.chmod(0o755)
        self.output = self.folder / 'fresh output'
        self.calls = self.folder / 'calls.txt'
        self.environment = {
            key: value for key, value in os.environ.items() if not key.startswith('GIT_')
        }
        self.environment.update(
            FARM_GODOT_BIN=str(self.engine),
            FARM_REDRAW_TEST_OUTPUT=str(self.output),
            REDRAW_WRAPPER_CALLS=str(self.calls),
        )

    def run_wrapper(self, scenario='success'):
        environment = {**self.environment, 'REDRAW_WRAPPER_CASE': scenario}
        return subprocess.run(
            ['zsh', str(self.runner)], env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, timeout=20,
        )

    def make_prior(self):
        for mode in ['normal', 'f10']:
            folder = self.output / mode
            folder.mkdir(parents=True)
            for name in ['engine.txt', 'frames.jsonl', 'summary.json']:
                (folder / name).write_text('ORIGINAL IMMUTABLE QA EVIDENCE ' + mode + name + '\n')

    def assert_early_refusal(self):
        before = snapshot(self.output)
        result = self.run_wrapper()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(snapshot(self.output), before)
        self.assertFalse(self.calls.exists(), 'Existing evidence must be rejected before any engine launch')

    def test_existing_complete_output_is_immutable(self):
        self.make_prior()
        self.assert_early_refusal()

    def test_existing_empty_root_is_also_rejected(self):
        self.output.mkdir()
        self.assert_early_refusal()

    def test_existing_file_is_immutable(self):
        self.output.write_text('ORIGINAL FILE\n')
        self.assert_early_refusal()

    def test_missing_parent_refuses_before_engine_launch(self):
        self.output = self.folder / 'missing parent' / 'output'
        self.environment['FARM_REDRAW_TEST_OUTPUT'] = str(self.output)
        result = self.run_wrapper()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.output.parent.exists())
        self.assertFalse(self.calls.exists())

    def test_existing_root_symlink_and_target_are_immutable(self):
        target = self.folder / 'prior'
        target.mkdir()
        (target / 'engine.txt').write_text('ORIGINAL LINK TARGET\n')
        self.output.symlink_to(target, target_is_directory=True)
        before = snapshot(target)
        self.assert_early_refusal()
        self.assertEqual(snapshot(target), before)

    def test_fresh_success_saves_current_log_in_both_modes(self):
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stdout)
        for mode in ['normal', 'f10']:
            self.assertEqual((self.output / mode / 'engine.txt').read_text(), 'REDRAW: 90 passed, 0 failed\n')
            self.assertEqual((self.output / mode / 'frames.jsonl').read_text(), 'CURRENT ' + mode + '\n')

    def test_fresh_failure_before_mode_creation_saves_current_log(self):
        result = self.run_wrapper('failure-before-directory')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('current experiment failed before', (self.output / 'normal/engine.txt').read_text())
        self.assertFalse((self.output / 'f10').exists())

    def test_fresh_failure_after_mode_creation_keeps_frames_and_log(self):
        result = self.run_wrapper('failure-after-directory')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('current experiment failed after', (self.output / 'normal/engine.txt').read_text())
        self.assertEqual((self.output / 'normal/frames.jsonl').read_text(), 'CURRENT normal\n')

    def test_exit_zero_engine_error_is_still_saved_and_rejected(self):
        result = self.run_wrapper('zero-exit-error')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ERROR: current experiment error', (self.output / 'normal/engine.txt').read_text())

    def test_mode_symlink_cannot_redirect_log_into_prior_evidence(self):
        prior = self.folder / 'prior mode'
        prior.mkdir()
        (prior / 'engine.txt').write_text('ORIGINAL IMMUTABLE QA EVIDENCE\n')
        self.environment['REDRAW_WRAPPER_PRIOR'] = str(prior)
        before = snapshot(prior)
        result = self.run_wrapper('mode-symlink')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(snapshot(prior), before)

    def test_even_current_engine_file_is_never_clobbered(self):
        result = self.run_wrapper('engine-already-exists')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(
            (self.output / 'normal/engine.txt').read_text(), 'CURRENT ENGINE SENTINEL\n'
        )

    def test_engine_log_symlink_cannot_modify_prior_target(self):
        target = self.folder / 'prior engine.txt'
        target.write_text('ORIGINAL LINK TARGET\n')
        self.environment['REDRAW_WRAPPER_LOG_TARGET'] = str(target)
        result = self.run_wrapper('engine-symlink')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_text(), 'ORIGINAL LINK TARGET\n')

    def test_dangling_engine_log_symlink_cannot_create_foreign_file(self):
        target = self.folder / 'foreign nonexistent engine.txt'
        self.environment['REDRAW_WRAPPER_LOG_TARGET'] = str(target)
        result = self.run_wrapper('engine-symlink')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(target.exists())

    def test_without_capture_root_regular_execution_still_works(self):
        self.environment.pop('FARM_REDRAW_TEST_OUTPUT')
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(result.stdout.count('REDRAW: 90 passed, 0 failed'), 2)
        self.assertFalse(self.output.exists())

    def test_reviewed_old_wrapper_reproduces_overwrite(self):
        previous = subprocess.check_output(
            ['git', 'show', '79a1a65fc3f699fe590d7eb030071bb8a809e0e2:run_tests.sh'], cwd=ROOT
        )
        self.runner.write_bytes(previous)
        self.make_prior()
        before = snapshot(self.output)
        result = self.run_wrapper()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotEqual(snapshot(self.output), before)
        self.assertEqual((self.output / 'normal/engine.txt').read_text(), 'ERROR: fresh redraw output required\n')


if __name__ == '__main__':
    unittest.main()
