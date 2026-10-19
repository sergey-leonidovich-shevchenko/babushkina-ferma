#!/usr/bin/env python3
"""Offline unit envelopes of the camera validator; synthetic metadata never proves native acceptance."""
import copy
import unittest

from camera_quantization import REPORT, read, validate_run, verify


def envelope():
    """Wraps actual headless physics in explicit in-memory mock window data for unit tests only."""
    data = copy.deepcopy(read(REPORT/'headless-probe.json'))
    data.update(kind='quantization-native', display_server='macOS', renderer='opengl3',
                profile='Codex-VCAMERA-002-Unit-Envelope', requested=[1152,648],
                initial={'window':[1152,648], 'root':[1152,648], 'focused':True, 'mode':0})
    for row in data['frames']:
        row.update(window=[1152,648], readback=[1152,648], visible=[1152,648],
                   focused=True, window_mode=0, foot_pixel=True, fiducial=True,
                   stretch_scale=[1,1], pointer_window=row['pointer_canvas'])
    return data


class CameraQuantization(unittest.TestCase):
    """Rejects data tampering without relabeling these tests as native captures."""

    def reject(self, edit):
        """Mutates only an in-memory envelope and requires a concrete failure."""
        data = envelope(); edit(data)
        with self.assertRaises(ValueError): validate_run(data, [1152,648], False)

    def test_unit_envelope_center(self):
        """The pure numerical contract is positive; its window metadata are deliberately mocked."""
        result = validate_run(envelope(), [1152,648], False)
        self.assertEqual(result['center_peak_to_peak_logical'], [0,0])
        self.assertEqual(result['stalled_camera_y_steps'], 0)

    def test_headless_is_rejected(self):
        self.reject(lambda d: d.update(kind='quantization-probe', display_server='headless'))

    def test_fps_claim_is_rejected(self):
        self.reject(lambda d: d.update(performance_eligible=True))

    def test_initial_unfocused_is_rejected(self):
        self.reject(lambda d: d['initial'].update(focused=False))
        actual = read(REPORT/'controls/unfocused-start/capture.json')
        self.assertFalse(actual['initial']['focused'])
        with self.assertRaises(ValueError): validate_run(actual,[1152,648],True)

    def test_frame_window_and_focus(self):
        self.reject(lambda d: d['frames'][50].update(window=[1920,1080]))
        self.reject(lambda d: d['frames'][50].update(readback=[1280,720]))
        self.reject(lambda d: d['frames'][50].update(focused=False))

    def test_marker_and_background(self):
        self.reject(lambda d: d['frames'][50].update(foot_pixel=False))
        self.reject(lambda d: d['frames'][50].update(fiducial=False))
        self.reject(lambda d: d['frames'][50].update(background=[0,0]))

    def test_missing_frames_and_wrong_cut(self):
        self.reject(lambda d: d['frames'].pop(100))
        self.reject(lambda d: d['frames'][180].update(stage=0))

    def test_input_coverage(self):
        self.reject(lambda d: d['inputs'].pop())
        self.reject(lambda d: d['frames'][50].update(movement=[1,0]))

    def test_stopped_clock_and_extra_step(self):
        self.reject(lambda d: d['frames'][50].update(minutes=720))
        self.reject(lambda d: d['frames'][50].update(delta=1/30))
        self.reject(lambda d: d['frames'][50].update(automatic_physics=True))

    def test_camera_quantization_and_feet(self):
        self.reject(lambda d: d['frames'][50].update(camera=[0,359]))
        self.reject(lambda d: d['frames'][50].update(foot_world=[0,0]))

    def test_pointer_scale_and_cell(self):
        self.reject(lambda d: d['frames'][50].update(pointer_window=[100,100]))
        self.reject(lambda d: d['frames'][50].update(pointer_cell=[0,0]))

    def test_teleport_and_nonfinite(self):
        self.reject(lambda d: d['frames'][50].update(player=[900,900]))
        self.reject(lambda d: d['frames'][50].update(player=[float('nan'),700]))

    def test_retina_requires_observation(self):
        with self.assertRaises(ValueError): validate_run(envelope(),[1152,648],False,True)

    def test_absent_native_packet_cannot_pass(self):
        """A missing packet must fail; these unit envelopes are not a substitute."""
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError,'packet missing'): verify(Path(directory))


if __name__ == '__main__': unittest.main()
