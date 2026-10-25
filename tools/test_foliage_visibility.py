#!/usr/bin/env python3
"""Контроли на временных копиях VFOLIAGE-010: повреждение данных, происхождение и будущие кандидаты."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image
from foliage_visibility_verify import REPORT, verify
from foliage_visibility_evidence import Frames, digest
from foliage_visibility_provenance import verify_current_candidate
from foliage_visibility_test_fixture import build_candidate

NATIVE = REPORT / 'native-01'


class VisibilityControls(unittest.TestCase):
    """Переподписывает только изменённые копии метаданных, чтобы проверить также смысловые отказы."""
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix='vfoliage010-control-')
        self.root = Path(self.temp.name) / 'copy'
        shutil.copytree(
            NATIVE,
            self.root,
            copy_function=lambda a, b: os.symlink(str(Path(a).resolve()), b),
        )
        self.source = json.loads((self.root / 'source.json').read_text())
        self.capture = json.loads((self.root / '1152/native/capture.json').read_text())
        self.original_sha = digest(NATIVE / 'source.json')

    def tearDown(self) -> None:
        self.assertEqual(digest(NATIVE / 'source.json'), self.original_sha)
        self.temp.cleanup()

    def replace(self, relative: str, data: bytes) -> None:
        """Разрывает ссылку до записи, поэтому оригиналы остаются неизменными."""
        path = self.root / relative
        path.unlink()
        path.write_bytes(data)
        if relative in self.source['artifacts']:
            self.source['artifacts'][relative] = digest(path)

    def flush(self) -> None:
        self.replace('1152/native/capture.json', (json.dumps(self.capture) + '\n').encode())
        self.replace('source.json', (json.dumps(self.source) + '\n').encode())

    def rejected(self, text: str) -> None:
        self.flush()
        with self.assertRaisesRegex(ValueError, text):
            verify(self.root)

    def test_golden_real_archive(self):
        result = verify(self.root)
        self.assertEqual(
            (result['frames'], result['exact_pairs'], result['coverage_targets']),
            (512, 36, 24),
        )
        original = json.loads((REPORT / 'verification.json').read_text())
        self.assertEqual(result['windows'], original['windows'])
        self.assertFalse(result['current_candidate_checked'])

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
        self.replace(
            '1152/engine.txt',
            (self.root / '1152/engine.txt').read_bytes()
            + b'\n  \x1b[31mERROR: deliberately damaged copy\x1b[0m\n',
        )
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
        row = next(
            r for r in self.capture['records']
            if r['route'] == 'left' and r['mode'] == 'full' and r['index'] == 35
        )
        row['state']['camera'][0] += 100
        self.rejected('camera pan endpoint')

    def test_fake_hero_endpoint(self):
        row = next(
            r for r in self.capture['records']
            if r['route'] == 'chunk' and r['mode'] == 'full' and r['index'] == 35
        )
        row['state']['player'][0] -= 100
        self.rejected('actual hero movement endpoint')

    def test_unbounded_draw_calls(self):
        row = next(
            r for r in self.capture['records']
            if r['route'] == 'cost' and r['mode'] == 'normal'
        )
        row['budget']['target_draw_calls_last_frame'] = 3
        self.rejected('production canvas budget')

    def test_inactive_target_still_scheduled(self):
        row = next(
            r for r in self.capture['records']
            if r['route'] == 'cost' and r['mode'] == 'low'
        )
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
        if not (self.root / 'storage.json').exists():
            self.skipTest('packing not yet run')
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

    def test_historical_plan_cannot_be_resigned(self):
        plan = json.loads((self.root / 'plan-copy.json').read_text())
        plan['candidate_version'] = '0.0.336'
        contents = (json.dumps(plan) + '\n').encode()
        self.replace('plan-copy.json', contents)
        self.source['plan_sha256'] = hashlib.sha256(contents).hexdigest()
        self.rejected('historical plan SHA')

    def test_historical_capsule_cannot_be_resigned(self):
        report = Path(self.temp.name) / 'report'
        report.mkdir()
        shutil.copyfile(REPORT / 'plan.json', report / 'plan.json')
        capsule = report / 'sources.tar.gz'
        capsule.write_bytes((REPORT / 'sources.tar.gz').read_bytes() + b'changed')
        with self.assertRaisesRegex(ValueError, 'historical source capsule SHA'):
            verify(self.root, report_dir=report)

    def test_historical_base_cannot_be_changed(self):
        self.source['base_commit'] = '8ef7feaefb5cc669997c871234ba0501c6e7d4cf'
        self.rejected('base identity')

    def test_bad_metadata_fails_before_decode(self):
        self.capture['records'][0]['focused'] = False
        with patch.object(Frames, 'image', side_effect=AssertionError('unexpected decode')):
            self.rejected('fresh/focused/windowed')


class FutureCandidateControls(unittest.TestCase):
    """Смена текущей версии/production не портит историю, но запрещает повторно принять кандидата."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.fixture = tempfile.TemporaryDirectory(prefix='vfoliage010-candidate-base-')
        cls.addClassCleanup(cls.fixture.cleanup)
        cls.template = Path(cls.fixture.name) / 'base'
        build_candidate(cls.template)
        cls.plan = json.loads((REPORT / 'plan.json').read_text())

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix='vfoliage010-future-')
        self.addCleanup(self.temp.cleanup)
        self.candidate = Path(self.temp.name) / 'candidate'
        shutil.copytree(
            self.template,
            self.candidate,
            copy_function=lambda a, b: os.symlink(str(Path(a).resolve()), b),
        )

    def replace_candidate(self, name: str, contents: bytes) -> None:
        path = self.candidate / name
        path.unlink()
        path.write_bytes(contents)

    def assert_history_survives(self) -> None:
        result = verify(NATIVE, candidate_root=self.candidate)
        self.assertEqual(
            (result['frames'], result['exact_pairs'], result['coverage_targets']),
            (512, 36, 24),
        )
        self.assertFalse(result['current_candidate_checked'])

    def test_captured_candidate_passes_strict_guard(self):
        self.assertEqual(verify_current_candidate(self.plan, self.candidate), 3743)

    def test_version_only_evidence_is_still_valid(self):
        self.assertEqual((self.candidate / 'VERSION').read_text().strip(), '0.0.335')
        self.replace_candidate('VERSION', b'0.0.336\n')
        self.assert_history_survives()
        with self.assertRaisesRegex(ValueError, 'current candidate source SHA: VERSION'):
            verify(
                NATIVE,
                candidate_root=self.candidate,
                check_current_candidate=True,
            )

    def test_future_production_evidence_is_still_valid(self):
        name = 'scripts/presentation/foliage_wind.gdshader'
        before = (self.candidate / name).read_bytes()
        after = before.replace(
            b'uniform float amplitude = 1.35;',
            b'uniform float amplitude = 2.0;',
        )
        self.assertNotEqual(before, after)
        self.replace_candidate(name, after)
        self.assert_history_survives()
        with self.assertRaisesRegex(ValueError, 'current candidate source SHA: ' + name):
            verify(
                NATIVE,
                candidate_root=self.candidate,
                check_current_candidate=True,
            )

    def test_new_production_file_is_rejected_by_guard(self):
        extra = self.candidate / 'scripts/future_effect.gd'
        self.assertFalse(extra.exists())
        extra.write_text('extends Node\n')
        with self.assertRaisesRegex(ValueError, 'current candidate production inventory'):
            verify_current_candidate(self.plan, self.candidate)


if __name__ == '__main__':
    unittest.main()
