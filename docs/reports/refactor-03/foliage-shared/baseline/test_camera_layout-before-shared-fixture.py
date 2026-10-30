"""Reject stale current files and bind timing launch URI to closed source metadata; no native sessions."""
import copy
import importlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.common.git import git_environment
from tools.common.paths import project_root
from tools.assets.contracts.source_paths import current_source

# The same source module anchors both the private pre-move run and the installed test.
ROOT = project_root(current_source.__code__.co_filename)


def source_module(logical):
    """Load only the single trusted current-source path, never prefer a stale logical copy."""
    path = current_source(ROOT, logical)
    return importlib.import_module(str(path.relative_to(ROOT)).removesuffix('.py').replace('/', '.'))


class CameraLayoutTests(unittest.TestCase):
    """Exercise actual producers/readers while keeping old evidence unchanged."""

    def setUp(self):
        self.timing = source_module('tools/reference_zoom_perf.py')
        self.camera = source_module('tools/visual_camera.py')
        self.folder = self.timing.REPORT / 'timing'
        plan = json.loads((ROOT / 'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())
        camera = {old: row['target'] for old, row in plan['assignments'].items()
                  if row['family'] == 'camera' and old not in {'tools/visual_camera_points.gd', 'tools/encode_coordinate_video.swift'}}
        self.paths = {name: camera[name] for name in self.timing.LEGACY_SOURCES if name in camera}
        self.assertEqual(len(self.paths), 8)

    def test_launch_uri_is_bound_to_closed_source_paths(self):
        """Legacy and canonical launch each require their matching full known source metadata."""
        case = self.folder / 'base-120-1'
        data = json.loads((case / 'timing.json').read_text())
        env = json.loads((case / 'environment.json').read_text())
        log = (case / 'engine.txt').read_text()
        arguments = ([1152, 648], 1.2, data['profile'], log)
        expected = self.timing.validate_environment(env, *arguments)
        changed = copy.deepcopy(env)
        old = 'res://tools/reference_zoom_live.gd'
        new = 'res://' + self.paths['tools/reference_zoom_live.gd']
        changed['command'] = [new if p == old else p for p in env['command']]
        with self.assertRaises(ValueError):
            self.timing.validate_environment(changed, *arguments)
        self.assertEqual(self.timing.validate_environment(changed, *arguments, source_paths=self.paths), expected)
        with self.assertRaises(ValueError):
            self.timing.validate_environment(env, *arguments, source_paths=self.paths)
        for malformed in [[], True, {next(iter(self.paths)): next(iter(self.paths.values()))},
                          {name: '../outside' for name in self.paths}]:
            with self.subTest(metadata=malformed), self.assertRaises(ValueError):
                self.timing.validate_environment(changed, *arguments, source_paths=malformed)

    def test_resigned_unknown_or_mismatched_layout_does_not_admit_old_frames(self):
        """Actual old packet passes unchanged; adding layout metadata cannot reclassify its old launches."""
        original = self.timing.provenance(self.folder)
        with tempfile.TemporaryDirectory(prefix='camera timing source paths ') as directory:
            folder = Path(directory) / 'copied packet'
            shutil.copytree(self.folder, folder)
            for malformed in [None, [], True, {'tools/reference_zoom_live.gd': 'elsewhere.gd'}]:
                source = copy.deepcopy(original)
                source['source_paths'] = malformed
                (folder / 'source.json').write_text(json.dumps(source))
                with self.subTest(metadata=malformed), self.assertRaises(ValueError):
                    self.timing.provenance(folder)
            source = copy.deepcopy(original)
            source['source_paths'] = self.paths
            (folder / 'source.json').write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError, 'launch script'):
                self.timing.verify(folder)
        self.assertEqual(self.timing.provenance(self.folder), original)

    def test_actual_fresh_camera_never_falls_back_to_stale_root_source(self):
        """Canonical source missing, stale old file present: actual collector must stop before its fake child."""
        with tempfile.TemporaryDirectory(prefix='camera missing canonical ') as directory:
            parent = Path(directory).resolve()
            root = parent / 'own project'
            root.mkdir()
            names = ['project.godot', 'main.tscn', 'tools/visual_camera_points.gd',
                     'tools/visual_camera_capture.gd', 'tools/visual_camera.py']
            plan = json.loads((ROOT / 'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())
            for name in names:
                raw = current_source(ROOT, name).read_bytes()
                physical = plan['assignments'].get(name, {}).get('target', name)
                if name == 'tools/visual_camera_points.gd':
                    physical = name
                for destination in {name, physical}:
                    target = root / destination
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(raw)
            missing = root / plan['assignments']['tools/visual_camera.py']['target']
            missing.unlink()
            (root / 'tools/visual_camera.py').write_bytes(b'stale source must not hide missing canonical input\n')
            subprocess.run(['git', 'init', '-q', str(root)], env=git_environment(), check=True)
            subprocess.run(['git', '-C', str(root), 'add', '.'], env=git_environment(), check=True)
            subprocess.run(['git', '-C', str(root), '-c', 'user.name=Camera QA',
                '-c', 'user.email=qa@example.invalid', 'commit', '-qm', 'isolated camera layout'],
                env=git_environment(), check=True)
            engine, witness = parent / 'explicit fake engine', parent / 'child.txt'
            engine.write_text('#!/usr/bin/env python3\nimport os\nfrom pathlib import Path\n'
                              'Path(os.environ["FARM_CAMERA_LAYOUT_WITNESS"]).write_text("fake child only")\n'
                              'raise SystemExit(17)\n')
            engine.chmod(0o755)
            with patch.object(self.camera, 'ROOT', root), patch.dict(os.environ,
                FARM_GODOT_BIN=str(engine), FARM_CAMERA_LAYOUT_WITNESS=str(witness)):
                with self.assertRaises(FileNotFoundError) as error:
                    self.camera.run_capture(parent / 'new output', '')
                self.assertEqual(Path(error.exception.filename), missing)
                self.assertFalse(witness.exists())
                self.assertTrue((root / 'tools/visual_camera.py').is_file())


if __name__ == '__main__':
    unittest.main()
