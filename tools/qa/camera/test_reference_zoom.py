#!/usr/bin/env python3
"""VCAMERA-006 rejects real evidence defects using memory or temporary copies only."""
import copy
import json
from pathlib import Path
from tools.assets.contracts.source_paths import current_source
import shutil
import tempfile
import sys
import unittest
from unittest.mock import patch
from tools.qa.camera import reference_zoom as Z
from tools.qa.camera import reference_zoom_perf as P


def current_inputs(folder):
    """Mirror archived runtime bytes at canonical input paths, keeping the proof archive unchanged."""
    root = folder.parent / 'current inputs'
    root.mkdir()
    for name in Z.SOURCES:
        target = current_source(root, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(folder / 'instrumentation' / name, target)
    return root


class ZoomPacketTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder=Z.REPORT/'native'; cls.raw=Z.read(cls.folder/'base-120/capture.json')

    def rejected(self, mutation):
        data=copy.deepcopy(self.raw); mutation(data)
        with self.assertRaises((ValueError,KeyError,TypeError)): Z.validate_run(data,[1152,648],1.2)

    def test_complete_native_packet(self):
        result=Z.verify(self.folder)
        self.assertEqual(len(result),6); self.assertEqual(result['retina-2x-120']['field'],[960,540])
        self.assertEqual(result['base-100']['camera_stalls'],0); self.assertEqual(result['base-120']['camera_stalls'],0)

    def test_real_headless_control_is_rejected(self):
        data=Z.read(Z.REPORT/'controls/headless-probe/capture.json')
        Z.validate_run(data,[1152,648],1.2,False)
        with self.assertRaisesRegex(ValueError,'native'): Z.validate_run(data,[1152,648],1.2)

    def test_native_conditions(self):
        for key,value in [('kind','zoom-probe'),('physics_hz',60),('performance_eligible',True),('content_scale_factor',1.2)]:
            with self.subTest(key=key): self.rejected(lambda d:d.update({key:value}))
        for key,value in [('focused',False),('window_mode',3),('readback',[1920,1080]),('automatic_render',True)]:
            with self.subTest(key=key): self.rejected(lambda d:d['frames'][50].update({key:value}))

    def test_field_background_and_matrix(self):
        for key,value in [('field',[1152,648]),('background_scale',[1,1]),('matrix',[[1,0],[0,1],[0,0]]),('background',[0,0])]:
            with self.subTest(key=key): self.rejected(lambda d:d['frames'][50].update({key:value}))

    def test_foot_animation_and_root_phase(self):
        self.rejected(lambda d:d['frames'][51].update(foot_world=d['frames'][51]['player']))
        self.rejected(lambda d:d['frames'][51].update(walk_clock=0))
        self.rejected(lambda d:d['frames'][51].update(shader_contact=[0,0]))
        self.rejected(lambda d:d['frames'][51].update(root_canvas=[0,0]))

    def test_pointer_cell_and_extra_retina_scale(self):
        for key,value in [('pointer_window',[0,0]),('pointer_cell',[0,0]),('cell_size',[24,24]),('pointer_received',[0,0])]:
            with self.subTest(key=key): self.rejected(lambda d:d['frames'][50].update({key:value}))

    def test_phase_order_and_physical_clock(self):
        self.rejected(lambda d:d['frames'].pop())
        self.rejected(lambda d:d['frames'][50].update(index=49))
        self.rejected(lambda d:d['frames'][51].update(player=[100,100]))
        self.rejected(lambda d:d['frames'][51].update(minutes=0))
        self.rejected(lambda d:d['inputs'].pop())

    def test_hud_geometry(self):
        self.rejected(lambda d:d['frames'][50].update(hud_bounds=[0,0,1382,96]))
        self.rejected(lambda d:d['frames'][50].update(hud_crop=[0,0,160,28]))

    def test_versioned_sources_keep_original_packet_immutable(self):
        original=Z.read(Z.REPORT/'native-before-final-fixes/source.json')
        self.assertEqual(set(Z.expected_sources(original)),set(original['sources']))
        self.assertEqual(set(Z.expected_sources({'schema':2}))-set(Z.expected_sources(original)),
            {'scripts/systems/published_level_system.gd','scripts/presentation/village_region_renderer.gd'})
        with self.assertRaisesRegex(ValueError,'unsupported'): Z.expected_sources({'schema':3})

    def test_changed_source_and_video_hash(self):
        for mode in ['source','video','missing']:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix='zoom-negative-') as raw:
                folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
                if mode=='source':
                    path=folder/'instrumentation/scripts/systems/world_projection_system.gd'; path.write_bytes(path.read_bytes()+b'\n# changed\n')
                elif mode=='video':
                    path=folder/'base-120/walk.mp4'; path.write_bytes(path.read_bytes()+b'changed')
                else: (folder/'base-120/engine.txt').unlink()
                with self.assertRaises((ValueError,OSError)): Z.verify(folder)

    def test_signed_launch_metadata_still_rejected(self):
        with tempfile.TemporaryDirectory(prefix='zoom-negative-') as raw:
            folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
            path=folder/'base-120/environment.json'; data=Z.read(path); data['command'].append('--headless')
            path.write_text(json.dumps(data)); Z.manifest(folder,Z.read(folder/'source.json'))
            with self.assertRaisesRegex(ValueError,'launch'): Z.verify(folder)

    def test_signed_hud_trace_must_match_actual_pixels(self):
        with tempfile.TemporaryDirectory(prefix='zoom-negative-') as raw:
            folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
            for mode in ['100','120']:
                path=folder/('base-'+mode)/'capture.json'; data=Z.read(path)
                for row in data['frames']: row['hud_sha256']='0'*64
                path.write_text(json.dumps(data))
            Z.manifest(folder,Z.read(folder/'source.json'))
            with self.assertRaisesRegex(ValueError,'actual HUD'): Z.verify(folder)

    def test_completed_packet_cannot_resume(self):
        with tempfile.TemporaryDirectory(prefix='zoom-negative-') as raw:
            folder=Path(raw); (folder/'source.json').write_text(json.dumps(Z.read(self.folder/'source.json')))
            with patch.object(Z.subprocess,'run',side_effect=AssertionError('no GUI in negative test')):
                with self.assertRaisesRegex(ValueError,'incomplete'): Z.capture(folder,True)

    def test_resume_cannot_resign_damaged_video(self):
        with tempfile.TemporaryDirectory(prefix='zoom-negative-') as raw:
            folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
            source=Z.read(folder/'source.json'); source['complete']=False; (folder/'source.json').write_text(json.dumps(source))
            path=folder/'base-100/walk.mp4'; path.write_bytes(path.read_bytes()+b'changed')
            with patch.object(Z,'ROOT',current_inputs(folder)), patch.object(Z.subprocess,'run',side_effect=AssertionError('no GUI in negative test')):
                with self.assertRaisesRegex(ValueError,'completed artifact'): Z.capture(folder,True)


class LiveTimingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder=Z.REPORT/'timing'; cls.raw=Z.read(cls.folder/'base-120-1/timing.json')

    def rejected(self, mutation):
        data=copy.deepcopy(self.raw); mutation(data)
        with self.assertRaises((ValueError,KeyError,TypeError)): P.validate_run(data,[1152,648],1.2)

    def test_complete_live_packet(self):
        result=P.verify(self.folder)
        self.assertEqual(len(result['runs']),18); self.assertIs(result['release_performance_accepted'],False)

    def test_no_headless_manual_readback_or_pause(self):
        for key,value in [('display_server','headless'),('manual_simulation',True),('gpu_readback_during_samples',True),('physics_hz',30)]:
            with self.subTest(key=key): self.rejected(lambda d:d.update({key:value}))
        for key,value in [('focused',False),('paused',True),('automatic_physics',False),('draw_calls',0),('camera',[0,0])]:
            with self.subTest(key=key): self.rejected(lambda d:d['samples'][100].update({key:value}))

    def test_incomplete_or_retimed_samples(self):
        self.rejected(lambda d:d['samples'].pop())
        self.rejected(lambda d:d['samples'][100].update(usec=0))
        self.rejected(lambda d:d['samples'][100].update(process_frame=0))

    def test_hitch_is_retained_and_fails_absolute_budget(self):
        data=copy.deepcopy(self.raw)
        for row in data['samples'][100:]: row['usec']+=1_000_000
        data['samples'][100]['interval_ms']+=1000
        result=P.validate_run(data,[1152,648],1.2)
        self.assertGreater(result['max_ms'],1000); self.assertEqual(result['budget_60fps_candidate'],'FAIL')

    def test_parallel_test_job_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'another test'): P.require_no_tests(['1 Godot --headless --script tests/test_game.gd'])
        with self.assertRaisesRegex(ValueError,'Godot job'): P.require_no_tests(['1 Godot --editor'])

    def test_actual_power_switch_cannot_be_resigned_as_valid(self):
        actual=Z.read(Z.REPORT/'timing-interrupted-power/base-100-3/environment.json')
        self.assertNotEqual(actual['power_before'].splitlines()[0],actual['power_after'].splitlines()[0])
        folder=Z.REPORT/'timing-interrupted-power/base-100-3'
        data=Z.read(folder/'timing.json')
        with self.assertRaisesRegex(ValueError,'power source changed'):
            P.validate_environment(actual,[1152,648],1.0,data['profile'],(folder/'engine.txt').read_text())

    def test_individually_stable_power_modes_cannot_be_compared(self):
        changed=Z.read(Z.REPORT/'timing-interrupted-power/base-100-3/environment.json')
        battery=changed['power_after'].splitlines()[0]
        ac=changed['power_before'].splitlines()[0]
        P.validate_comparison_power([battery,battery])
        with self.assertRaisesRegex(ValueError,'between compared runs'): P.validate_comparison_power([ac,battery])
        with self.assertRaisesRegex(ValueError,'between compared runs'): P.validate_comparison_power([])

    def test_partial_audit_rejects_actual_focus_loss(self):
        result=P.audit(Z.REPORT/'timing-before-final-fixes')
        self.assertFalse(result['acceptance_granted'])
        self.assertEqual(sum(result['counts'].values()),18)
        self.assertFalse(result['source_complete'])
        self.assertEqual(result['runs']['full-hd-100-3']['status'],'rejected')
        self.assertEqual(result['counts'],{'valid':10,'rejected':1,'missing':7})

    def test_interrupted_power_packet_cannot_pass_acceptance(self):
        folder=Z.REPORT/'timing-interrupted-power'; result=P.audit(folder)
        self.assertEqual(result['counts'],{'valid':4,'rejected':1,'missing':13})
        self.assertEqual(result['runs']['base-100-3']['reason'],'power source changed')
        with self.assertRaisesRegex(ValueError,'incomplete live provenance'): P.verify(folder)

    def test_partial_audit_checks_hashes(self):
        with tempfile.TemporaryDirectory(prefix='zoom-live-negative-') as raw:
            folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
            path=folder/'base-120-1/timing.json'; path.write_bytes(path.read_bytes()+b' ')
            with self.assertRaisesRegex(ValueError,'live artifact hash'): P.audit(folder)

    def test_legacy_packet_cannot_claim_new_source_coverage(self):
        with tempfile.TemporaryDirectory(prefix='zoom-live-negative-') as raw:
            folder=Path(raw)/'packet'; shutil.copytree(Z.REPORT/'timing-interrupted-power',folder)
            path=folder/'source.json'; data=Z.read(path); data['schema']=2
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError,'live source coverage'): P.audit(folder)

    def test_launch_must_match_observed_format_profile_and_script(self):
        folder=self.folder/'base-120-1'; original=Z.read(folder/'environment.json'); log=(folder/'engine.txt').read_text()
        for argument in ['--zoom=1.2','--size=1152x648','--profile='+self.raw['profile'],'res://tools/reference_zoom_live.gd']:
            value=copy.deepcopy(original); value['command'].remove(argument)
            with self.subTest(argument=argument), self.assertRaisesRegex(ValueError,'live launch'):
                P.validate_environment(value,[1152,648],1.2,self.raw['profile'],log)


if __name__=='__main__':
    if '--offline' in sys.argv:
        # This is an explicit partial-development check, never the final acceptance gate.
        suite=unittest.TestSuite()
        for cls in [ZoomPacketTests,LiveTimingTests]:
            for name in unittest.defaultTestLoader.getTestCaseNames(cls):
                if name!='test_complete_live_packet': suite.addTest(cls(name))
        result=unittest.TextTestRunner(verbosity=2).run(suite)
        print('NOT RUN: test_complete_live_packet (requires the complete 18-run native packet)')
        raise SystemExit(0 if result.wasSuccessful() else 1)
    unittest.main()
