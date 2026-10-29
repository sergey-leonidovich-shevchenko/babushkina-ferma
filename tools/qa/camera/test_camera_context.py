"""Real camera Git/source envelopes before native launch; fake children never admit native/FPS evidence."""
from contextlib import contextmanager, ExitStack
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.qa.camera import camera_quantization as quantization
from tools.qa.camera import presentation_pose as pose
from tools.qa.camera import reference_zoom as zoom
from tools.qa.camera import reference_zoom_perf as timing
from tools.qa.camera import run_visual_baseline as baseline
from tools.qa.camera import visual_camera as camera
from tools.qa.camera import visual_coordinates as coordinates
from tools.qa.camera import visual_motion as motion
from tools.qa.camera import visual_static as static
from tools.common.git import git_environment
from tools.assets.contracts.source_paths import current_source


class BeforeNativeLaunch(Exception):
    """Stop live timing after its real source envelope, before inspecting competing processes."""


class CameraContextTests(unittest.TestCase):
    """Bind copied/nested tools and fresh source envelopes to their own explicit project."""

    def git(self, root, *args):
        """Use real isolated Git for fixtures and expectations, independent from the tool helper."""
        return subprocess.check_output(['git', '-C', str(root), *args], env=git_environment()).decode().strip()

    def repository(self, root, label):
        """Create a real distinct commit without relying on global Git identity."""
        root.mkdir()
        (root / 'label.txt').write_text(label)
        subprocess.run(['git', 'init', '-q', str(root)], env=git_environment(), check=True)
        subprocess.run(['git', '-C', str(root), 'add', '.'], env=git_environment(), check=True)
        subprocess.run(['git', '-C', str(root), '-c', 'user.name=Camera QA',
                        '-c', 'user.email=qa@example.invalid', 'commit', '-qm', label],
                       env=git_environment(), check=True)
        return root

    @contextmanager
    def foreign_context(self, root):
        """Keep caller cwd/environment and both foreign index/config byte-identical."""
        before = {n: (root / '.git' / n).read_bytes() for n in ['index', 'config']}
        cwd = Path.cwd()
        try:
            os.chdir(root)
            with patch.dict(os.environ, GIT_DIR=str(root / '.git'), GIT_WORK_TREE=str(root),
                            GIT_INDEX_FILE=str(root / '.git/index'), GIT_CONFIG_COUNT='1',
                            GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true'):
                environment = dict(os.environ)
                yield
                self.assertEqual(dict(os.environ), environment)
        finally:
            os.chdir(cwd)
            for name, raw in before.items():
                self.assertEqual((root / '.git' / name).read_bytes(), raw)

    def test_source_root_survives_nested_module_imports(self):
        """Nested copies of the six actual modules find their own markers, not a fixed parent."""
        names = ['visual_camera', 'camera_quantization', 'visual_coordinates', 'visual_motion',
                 'run_visual_baseline', 'check_native_frame_reports']
        with tempfile.TemporaryDirectory(prefix='camera nested project ') as directory:
            root = Path(directory).resolve()
            (root / 'project.godot').write_text('; isolated marker\n')
            (root / 'VERSION').write_text('qa\n')
            nested = root / 'tools/qa/camera'
            nested.mkdir(parents=True)
            child = ('import importlib.util,json,sys; from pathlib import Path; '
                     'sys.path[:0]=[sys.argv[1],sys.argv[2]]; '
                     's=importlib.util.spec_from_file_location("camera_nested_probe",sys.argv[3]); '
                     'm=importlib.util.module_from_spec(s);s.loader.exec_module(m); '
                     'print(json.dumps(str(m.ROOT)))')
            for name in names:
                with self.subTest(module=name):
                    source = current_source(baseline.ROOT, 'tools/' + name + '.py')
                    target = nested / source.name
                    target.write_bytes(source.read_bytes())
                    result = subprocess.run([sys.executable, '-c', child,
                        str(baseline.ROOT), str(baseline.ROOT / 'tools'), str(target)],
                        cwd=root, env=dict(git_environment(), PYTHONDONTWRITEBYTECODE='1'),
                        capture_output=True, text=True, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(Path(json.loads(result.stdout)), root)

    def test_git_helper_uses_its_explicit_project(self):
        """A real foreign bare/index override must not change the collector commit or dirty list."""
        with tempfile.TemporaryDirectory(prefix='camera git helper ') as directory:
            parent = Path(directory).resolve()
            own = self.repository(parent / 'own project', 'own camera')
            foreign = self.repository(parent / 'foreign project', 'foreign camera')
            expected = self.git(own, 'rev-parse', 'HEAD')
            with patch.object(baseline, 'ROOT', own), self.foreign_context(foreign):
                self.assertEqual(baseline.command(['git', 'rev-parse', 'HEAD']), expected)
                self.assertEqual(baseline.command(['git', 'status', '--short']), '')

    def test_non_git_helper_keeps_caller_context(self):
        """Ordinary system queries keep their prior cwd/environment; Git cleaning is not global."""
        with tempfile.TemporaryDirectory(prefix='camera non git ') as directory:
            foreign = self.repository(Path(directory).resolve() / 'foreign', 'caller')
            with self.foreign_context(foreign):
                result = json.loads(baseline.command([sys.executable, '-c',
                    'import json,os;print(json.dumps([os.getcwd(),os.environ["GIT_DIR"]]))']))
                self.assertEqual(result, [str(foreign), str(foreign / '.git')])

    def test_source_signature_keeps_own_commit_and_real_bytes(self):
        """The actual VBASE source producer hashes its files and reads its own Git in a foreign cwd."""
        with tempfile.TemporaryDirectory(prefix='camera source signature ') as directory:
            parent = Path(directory).resolve()
            own = self.repository(parent / 'own project', 'own source')
            foreign = self.repository(parent / 'foreign project', 'foreign source')
            (own / 'project.godot').write_text('own source bytes\n')
            with patch.object(baseline, 'ROOT', own), self.foreign_context(foreign):
                source = baseline.source_signature()
                self.assertEqual(source['commit'], self.git(own, 'rev-parse', 'HEAD'))
                self.assertEqual(source['dirty_paths'], '?? project.godot')
                self.assertEqual(source['sha256'], {'project.godot': hashlib.sha256((own / 'project.godot').read_bytes()).hexdigest()})

    def capture_envelope(self, module, function):
        """Run real source/hash/copy/Git with explicit fake children; retain no fake native admission."""
        original = baseline.ROOT
        with tempfile.TemporaryDirectory(prefix='camera actual producer ') as directory:
            parent = Path(directory).resolve()
            own = self.repository(parent / 'own project', 'own capture')
            foreign = self.repository(parent / 'foreign project', 'foreign capture')
            names = set(getattr(module, 'SOURCES', []))
            if module is camera:
                names = {'project.godot', 'main.tscn', 'tools/visual_camera_points.gd',
                         'tools/visual_camera_capture.gd', 'tools/visual_camera.py'}
            if module is static:
                names = {'project.godot', 'main.tscn', 'tools/visual_static.py',
                         'tools/visual_static_capture.gd', 'tools/visual_camera_points.gd'}
            for name in names:
                target = current_source(own, name)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(current_source(original, name).read_bytes())
            engine = own / 'tools/Godot.app/Contents/MacOS/Godot'
            engine.parent.mkdir(parents=True, exist_ok=True)
            engine.write_text('#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\n'
                'args=sys.argv[1:]\nPath(os.environ["FARM_CAMERA_WITNESS"]).write_text(json.dumps({"cwd":os.getcwd(),"argv":args}))\n'
                'raw=next((a.split("=",1)[1] for a in args if a.startswith("--output=")),None)\n'
                'if raw:\n p=Path(raw);p.mkdir(parents=True,exist_ok=True);(p/"capture.json").write_text("{}")\n'
                'if "--log-file" in args:\n p=Path(args[args.index("--log-file")+1]);p.write_text("explicit fake child; no native frame\\n")\n'
                'raise SystemExit(17)\n')
            engine.chmod(0o755)
            binary = parent / 'fake bin'
            binary.mkdir()
            fake_open = binary / 'open'
            fake_open.write_bytes(engine.read_bytes())
            fake_open.chmod(0o755)
            # Coordinates copies the first PNG before checking the failed child; provide explicit fake bytes.
            fake_source = engine.read_text().replace('(p/"capture.json").write_text("{}")',
                '(p/"capture.json").write_text("{}");(p/"frames").mkdir(exist_ok=True);(p/"frames/0000.png").write_bytes(b"FAKE-NOT-PNG")')
            engine.write_text(fake_source)
            fake_open.write_text(fake_source)
            expected = self.git(own, 'rev-parse', 'HEAD')
            output, witness = parent / 'new output', parent / 'child.json'
            @contextmanager
            def scratch():
                path = parent / 'owned raw'
                path.mkdir()
                yield path
            with ExitStack() as stack:
                for tool in [camera, static, coordinates, quantization, pose, zoom, timing, motion, baseline]:
                    stack.enter_context(patch.object(tool, 'ROOT', own))
                stack.enter_context(patch.object(pose, 'recording_scratch', scratch))
                stack.enter_context(patch.object(zoom, 'recording_scratch', scratch))
                stack.enter_context(patch.dict(os.environ, FARM_GODOT_BIN=str(engine),
                    FARM_CAMERA_WITNESS=str(witness), PATH=str(binary) + os.pathsep + os.environ['PATH']))
                if module is timing:
                    stack.enter_context(patch.object(timing, 'competing_jobs', side_effect=BeforeNativeLaunch))
                stack.enter_context(self.foreign_context(foreign))
                try:
                    function(output)
                except (ValueError, KeyError, OSError, BeforeNativeLaunch):
                    pass
                self.assertTrue((output / 'source.json').is_file())
                source = json.loads((output / 'source.json').read_text())
                self.assertEqual(source.get('base_commit', source.get('commit')), expected)
                signatures = source.get('sources', source.get('files'))
                self.assertEqual(set(signatures), names)
                for name, digest in signatures.items():
                    self.assertEqual(digest, hashlib.sha256(current_source(own, name).read_bytes()).hexdigest())
                    archived = output / 'instrumentation' / name
                    if 'sources' in source and module is not coordinates:
                        self.assertEqual(archived.read_bytes(), current_source(own, name).read_bytes())
                if module is timing:
                    self.assertFalse(witness.exists())
                else:
                    self.assertTrue(witness.is_file())
                    self.assertEqual(Path(json.loads(witness.read_text())['cwd']), own)
                # A partial envelope cannot be mistaken for a verified native/video/FPS packet.
                with self.assertRaises((ValueError, KeyError, OSError)):
                    if module is camera:
                        errors = module.verify(output, module.read(module.REGISTRY))
                        if errors:
                            raise ValueError(errors)
                    else:
                        errors = module.verify(output)
                        if errors and isinstance(errors, list):
                            raise ValueError(errors)
                before = (output / 'source.json').read_bytes()
                with self.assertRaises((ValueError, FileExistsError)):
                    function(output)
                self.assertEqual((output / 'source.json').read_bytes(), before)

    def test_camera_fresh_source_envelope(self):
        """Actual camera collector writes a new envelope with own commit before a failed fake child."""
        self.capture_envelope(camera, lambda output: camera.run_capture(output, ''))

    def test_static_fresh_source_envelope(self):
        """Actual static collector preserves its own Git and source namespace."""
        self.capture_envelope(static, static.capture)

    def test_coordinates_fresh_source_envelope(self):
        """Actual coordinate collector reads both Git revision and patch from the explicit project."""
        self.capture_envelope(coordinates, coordinates.capture)

    def test_quantization_fresh_source_envelope(self):
        """Actual quantization collector copies real source bytes before the explicit fake-open failure."""
        self.capture_envelope(quantization, quantization.capture)

    def test_pose_fresh_source_envelope(self):
        """Actual pose collector copies real sources into unchanged logical archive destinations."""
        self.capture_envelope(pose, pose.capture)

    def test_zoom_fresh_source_envelope(self):
        """Actual zoom collector retains its schema/source set before the failed fake child."""
        self.capture_envelope(zoom, zoom.capture)

    def test_zoom_timing_prelaunch_source_envelope(self):
        """Actual timing source writes before its context check, with no engine launched or metric admitted."""
        self.capture_envelope(timing, timing.capture)

    def test_motion_fresh_source_envelope(self):
        """Actual motion collector uses the shared Git helper without changing system-query context."""
        self.capture_envelope(motion, motion.capture)


if __name__ == '__main__':
    unittest.main()
