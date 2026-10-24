#!/usr/bin/env python3
"""Reject corrupted copies of retained native pause data; never admit unfocused runs."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

import foliage_pause_verify as proof


class FoliagePauseProofTests(unittest.TestCase):
    """Positive parser fixtures explicitly differ from the rejected native originals."""

    @classmethod
    def setUpClass(cls):
        cls.folder = proof.REPORT / 'native/1152/native'
        cls.raw = proof.load(cls.folder / 'capture.json')

    def parser_fixture(self):
        # Synthetic focus flags exercise other independent parser guards only.
        # This copy is never written back or passed to provenance/verify as native admission.
        data = copy.deepcopy(self.raw)
        for row in data['records']:
            row['focused'] = True
        return data

    def test_actual_first_series_is_rejected_without_focus(self):
        for width in [1152, 1280]:
            data = proof.load(proof.REPORT / f'native/{width}/native/capture.json')
            with self.assertRaisesRegex(ValueError, 'focused'):
                proof.metadata(data, width)

    def test_actual_second_attempt_is_incomplete_and_rejected(self):
        data = proof.load(proof.REPORT / 'native-focused/1152/native/capture.json')
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            proof.metadata(data, 1152)
        self.assertIn('actual native focus unavailable', data['errors'][0])

    def test_synthetic_metadata_covers_all_original_pause_states(self):
        self.assertEqual(len(proof.metadata(self.parser_fixture(), 1152)), 65)

    def test_missing_or_reordered_stage_is_rejected(self):
        for duplicate in [False, True]:
            data = self.parser_fixture()
            if duplicate:
                data['records'][-1] = data['records'][0]
            else:
                data['records'].pop()
            with self.assertRaisesRegex(ValueError, 'coverage'):
                proof.metadata(data, 1152)

    def test_corrupted_snapshot_bytes_are_rejected(self):
        data = self.parser_fixture()
        digest = data['records'][0]['state_sha']
        data['snapshots'][digest] += ' '
        with self.assertRaisesRegex(ValueError, 'snapshot SHA'):
            proof.metadata(data, 1152)

    def test_resigned_clock_debt_is_still_rejected(self):
        data = self.parser_fixture()
        row = data['records'][3]
        state = proof.snapshot(data, row['state_sha'])
        state['seconds'] += 0.6
        raw = json.dumps(state)
        digest = proof.sha(raw.encode())
        data['snapshots'][digest] = raw
        row['state_sha'] = row['state_after_sha'] = digest
        for draw in row['game_draws']:
            draw['seconds'] = state['seconds']
        with self.assertRaisesRegex(ValueError, 'resume clock debt'):
            proof.metadata(data, 1152)

    def test_missing_paused_sample_is_rejected(self):
        data = self.parser_fixture()
        data['records'][2]['paused_samples'].pop()
        with self.assertRaisesRegex(ValueError, 'sample coverage'):
            proof.metadata(data, 1152)

    def test_render_mutation_is_rejected(self):
        data = self.parser_fixture()
        data['records'][0]['save_after_sha'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'render mutated'):
            proof.metadata(data, 1152)

    def test_present_and_draw_are_both_required(self):
        for key, value in [('present_complete', False), ('frames_after', 0), ('game_draws', [])]:
            data = self.parser_fixture()
            data['records'][0][key] = value
            with self.assertRaises(ValueError):
                proof.metadata(data, 1152)

    def test_fullscreen_size_is_rejected(self):
        data = self.parser_fixture()
        data['records'][0]['window_size'] = [3584, 2240]
        with self.assertRaisesRegex(ValueError, 'dimensions'):
            proof.metadata(data, 1152)

    def test_false_hardware_or_fps_admission_is_rejected(self):
        for key in ['hardware_input_accepted', 'performance_eligible']:
            data = self.parser_fixture()
            data[key] = True
            with self.assertRaisesRegex(ValueError, 'false admission'):
                proof.metadata(data, 1152)

    def test_changed_target_pixel_is_rejected_independently_of_file_sha(self):
        with tempfile.TemporaryDirectory(prefix='pause-proof-') as name:
            folder = Path(name)
            target = folder / 'target.png'
            with Image.open(self.folder / 'inventory/held/target.png') as file:
                image = file.convert('RGBA')
            r, g, b, a = image.getpixel((0, 0))
            image.putpixel((0, 0), ((r + 1) % 256, g, b, a))
            image.save(target)
            original = Image.open

            def redirected(path, *args, **kwargs):
                actual = target if str(path).endswith('inventory/held/target.png') else path
                return original(actual, *args, **kwargs)

            with patch.object(proof.Image, 'open', side_effect=redirected):
                with self.assertRaisesRegex(ValueError, 'target RGBA'):
                    proof.pixels(self.folder, self.parser_fixture(), 1152)

    def test_original_capsules_remain_exact(self):
        proof.inputs(proof.REPORT, proof.load(proof.REPORT / 'plan-focused.json'))
        for plan_name, zip_name in [('plan.json', 'inputs.zip'), ('plan-focused.json', 'inputs-focused.zip')]:
            # Read actual capsules; do not regenerate expected source SHA.
            plan = proof.load(proof.REPORT / plan_name)
            with proof.zipfile.ZipFile(proof.REPORT / zip_name) as archive:
                self.assertEqual(set(archive.namelist()), set(plan['sources']))
                for path, digest in plan['sources'].items():
                    self.assertEqual(proof.sha(archive.read(path)), digest)

    def test_actual_unlocked_campaign_passes(self):
        result = proof.verify()
        self.assertEqual((result['native_states'], result['png'], result['paused_samples']), (130, 260, 936))
        self.assertFalse(result['hardware_input_accepted'])
        self.assertFalse(result['performance_eligible'])

    def test_old_incomplete_campaign_still_fails_public_verifier(self):
        with self.assertRaisesRegex(ValueError, 'incomplete source'):
            proof.verify(proof.REPORT / 'native-focused', proof.REPORT / 'plan-focused.json')

    def test_new_artifact_sha_corruption_is_rejected(self):
        output = proof.REPORT / 'native-windowed'
        plan_file = proof.REPORT / 'plan-windowed.json'
        original = proof.load
        source = copy.deepcopy(original(output / 'source.json'))
        source['artifacts'][next(k for k in source['artifacts'] if k.endswith('.png'))] = '0' * 64
        with patch.object(proof, 'load', side_effect=lambda path: source if path == output / 'source.json' else original(path)):
            with self.assertRaisesRegex(ValueError, 'artifact SHA'):
                proof.provenance(output, original(plan_file), plan_file)

    def test_new_impossible_timestamps_are_rejected(self):
        output = proof.REPORT / 'native-windowed'
        plan_file = proof.REPORT / 'plan-windowed.json'
        original = proof.load
        source = copy.deepcopy(original(output / 'source.json'))
        source['runs'][0]['before']['utc'] = source['runs'][0]['after']['utc'] + 1
        with patch.object(proof, 'load', side_effect=lambda path: source if path == output / 'source.json' else original(path)):
            with self.assertRaisesRegex(ValueError, 'timestamps'):
                proof.provenance(output, original(plan_file), plan_file)

    def test_startup_geometry_cannot_be_missing_or_fullscreen(self):
        original = proof.load(proof.REPORT / 'native-windowed/1152/native/capture.json')
        for empty in [True, False]:
            data = copy.deepcopy(original)
            if empty:
                data['startup_geometry'] = []
            else:
                data['startup_geometry'][-1]['window'] = [3584, 2240]
            with self.assertRaisesRegex(ValueError, 'startup'):
                proof.geometry(data, 1152)


if __name__ == '__main__':
    unittest.main()
