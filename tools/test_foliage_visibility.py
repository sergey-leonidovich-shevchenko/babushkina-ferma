#!/usr/bin/env python3
"""Negative controls on temporary copies of real VFOLIAGE-010 data; originals are never written."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest

from PIL import Image
from foliage_visibility_verify import REPORT, verify
from foliage_visibility_collect import digest

NATIVE = REPORT / 'native-01'


class VisibilityControls(unittest.TestCase):
    """Re-sign changed metadata where needed so the semantic checks, not only checksums, must detect damage."""
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix='vfoliage010-control-')
        self.root = Path(self.temp.name) / 'copy'
        shutil.copytree(NATIVE, self.root, copy_function=lambda a, b: os.symlink(str(Path(a).resolve()), b))
        self.source = json.loads((self.root / 'source.json').read_text())
        self.capture = json.loads((self.root / '1152/native/capture.json').read_text())
        self.original_sha = digest(NATIVE / 'source.json')

    def tearDown(self) -> None:
        self.assertEqual(digest(NATIVE / 'source.json'), self.original_sha)
        self.temp.cleanup()

    def replace(self, relative: str, data: bytes) -> None:
        path = self.root / relative
        path.unlink()  # Break the read-only link before writing a new private file.
        path.write_bytes(data)
        if relative in self.source['artifacts']:
            self.source['artifacts'][relative] = digest(path)

    def flush(self) -> None:
        self.replace('1152/native/capture.json', (json.dumps(self.capture) + '\n').encode())
        self.replace('source.json', (json.dumps(self.source) + '\n').encode())

    def rejected(self, text: str) -> None:
        self.flush()
        with self.assertRaisesRegex(ValueError, text):
            verify(self.root, check_sources=False)

    def test_golden_real_archive(self):
        result = verify(self.root)
        self.assertEqual((result['frames'], result['exact_pairs'], result['coverage_targets']), (512, 36, 24))

    def test_incomplete(self):
        self.source['complete'] = False
        self.rejected('incomplete source')

    def test_missing_window(self):
        self.source['runs'].pop()
        self.rejected('both native runs')

    def test_headless(self):
        self.capture['display'] = 'headless'
        self.rejected('native identity')

    def test_engine_error_even_exit_zero(self):
        self.replace('1152/engine.txt', (self.root / '1152/engine.txt').read_bytes() + b'\n  \x1b[31mERROR: deliberately damaged copy\x1b[0m\n')
        self.rejected('engine errors in raw log')

    def test_wrong_native_size(self):
        self.capture['records'][0]['size'] = [3584, 2240]
        self.rejected('fresh/focused/windowed')

    def test_lost_focus(self):
        self.capture['records'][0]['focused'] = False
        self.rejected('fresh/focused/windowed')

    def test_missing_present(self):
        self.capture['records'][0]['presents'] = 0
        self.rejected('fresh/focused/windowed')

    def test_stale_marker_metadata(self):
        self.capture['records'][0]['serial'] = 17
        self.rejected('fresh/focused/windowed')

    def test_lost_frame(self):
        self.capture['records'].pop(10)
        self.rejected('complete native frame matrix')

    def test_mutated_save_in_draw(self):
        self.capture['records'][0]['draws'][0]['save_after'] = '0' * 64
        self.rejected('draw purity')

    def test_changed_culling_pixel_with_valid_sha(self):
        row = self.capture['records'][1]
        relative = '1152/native/' + row['image']
        image = Image.open(self.root / relative).convert('RGBA')
        image.putpixel((100, 100), (13, 21, 34, 255))
        path = self.root / relative
        path.unlink()
        image.save(path)
        self.source['artifacts'][relative] = digest(path)
        row['rgba_sha256'] = hashlib.sha256(image.tobytes()).hexdigest()
        self.rejected('culling changes visible RGBA')

    def test_changed_pair_uniform(self):
        self.capture['records'][2]['state']['uniforms'][0]['seconds'] += 1
        self.rejected('culling pair state')

    def test_fake_camera_endpoint(self):
        row = next(r for r in self.capture['records'] if r['route'] == 'left' and r['mode'] == 'full' and r['index'] == 35)
        row['state']['camera'][0] += 100
        self.rejected('camera pan endpoint')

    def test_fake_hero_endpoint(self):
        row = next(r for r in self.capture['records'] if r['route'] == 'chunk' and r['mode'] == 'full' and r['index'] == 35)
        row['state']['player'][0] -= 100
        self.rejected('actual hero movement endpoint')

    def test_unbounded_draw_calls(self):
        row = next(r for r in self.capture['records'] if r['route'] == 'cost' and r['mode'] == 'normal')
        row['budget']['target_draw_calls_last_frame'] = 3
        self.rejected('production canvas budget')

    def test_inactive_target_still_scheduled(self):
        row = next(r for r in self.capture['records'] if r['route'] == 'cost' and r['mode'] == 'low')
        row['budget']['target_update_mode'] = 1
        self.rejected('inactive work not disabled')

    def test_clipped_multimesh_bounds(self):
        self.capture['coverage'][1]['bounds'][0]['aabb']['size'][0] = 10
        self.rejected('native MultiMesh AABB')

    def test_forged_coverage_sum(self):
        self.capture['coverage'][1]['fragments'] += 1
        self.rejected('independent coverage count')

    def test_missing_native_bounds(self):
        self.capture['coverage'][1]['bounds'] = []
        self.rejected('both native bounds groups')

    def test_real_coverage_overlap(self):
        row = self.capture['coverage'][1]
        relative = '1152/native/' + row['image']
        image = Image.open(self.root / relative).convert('RGBA')
        image.putpixel((30, 30), (2, 0, 0, 255))
        path = self.root / relative
        path.unlink()
        image.save(path)
        self.source['artifacts'][relative] = digest(path)
        self.rejected('independent coverage count')

    def test_lossy_or_corrupt_archive(self):
        if not (self.root / 'storage.json').exists(): self.skipTest('packing not yet run')
        storage = json.loads((self.root / 'storage.json').read_text())
        name = next(iter(storage['archives']))
        self.replace(name, b'not a lossless image')
        self.rejected('archive SHA')

    def test_missing_png_without_archive(self):
        (self.root / '1152/native/left/culled/000.png').unlink()
        self.rejected('missing original artifact')

    def test_corrupt_viewing_movie(self):
        self.replace('1152/native/left/motion.mp4', b'damaged derivative')
        self.rejected('viewing clip SHA')


if __name__ == '__main__':
    unittest.main()
