"""Real Godot provenance and fresh compiler regression probes; never native/FPS evidence."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
ENGINE = os.environ.get('FARM_GODOT_BIN', str(ROOT / 'tools/Godot.app/Contents/MacOS/Godot'))


class CompiledSourceTests(unittest.TestCase):
    def run_script(self, script, folder, *arguments):
        """Run the actual script in an owned output folder, preserving runtime resources."""
        result = subprocess.run([ENGINE, '--headless', '--path', str(ROOT),
            '--log-file', str(folder / (script + '.engine.log')), '--script',
            'res://tools/qa/ground/' + script + '.gd', '--', *arguments],
            cwd=folder, capture_output=True, text=True, timeout=180)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('SCRIPT ERROR', result.stdout + result.stderr)
        print(result.stdout, end='')

    def test_frozen_sources_and_actual_file_tampering(self):
        """Frozen hashes survive only reviewed preload moves; missing/stale/tampered bytes fail."""
        with tempfile.TemporaryDirectory(prefix='farm-ground-provenance-') as temporary:
            folder = Path(temporary)
            self.run_script('compiled_sources_review', folder, '--mode=provenance',
                '--output=' + str(folder / 'fixture'))

    def test_fresh_compilers_keep_geometry_and_record_current_hashes(self):
        """All four real compilers produce nine masks with exact geometry and fresh source hashes."""
        with tempfile.TemporaryDirectory(prefix='farm-ground-compilers-') as temporary:
            folder = Path(temporary)
            for kind in ['ground_edge', 'axial_road', 'road_network', 'plaza']:
                self.run_script(kind + '_compile', folder, '--output=' + str(folder / kind))
            self.run_script('compiled_sources_review', folder, '--mode=fresh', '--output=' + str(folder))


if __name__ == '__main__':
    unittest.main()
