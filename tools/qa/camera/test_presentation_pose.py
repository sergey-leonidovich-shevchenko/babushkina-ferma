#!/usr/bin/env python3
"""VCAMERA-003 rejection tests use captured evidence and disposable copies only."""
import copy
import json
import shutil
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
from tools.assets.contracts.source_paths import current_source
from tools.common.history import pinned_sha
from tools.qa.camera import presentation_pose as P


def current_inputs(folder):
    """Mirror archived runtime bytes at canonical input paths, keeping the proof archive unchanged."""
    root = folder.parent / 'current inputs'
    root.mkdir()
    for name in P.SOURCES:
        target = current_source(root, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(folder / 'instrumentation' / name, target)
    return root


class PosePacketTests(unittest.TestCase):
    """Rejects temporal and evidence defects without touching the accepted packet."""
    @classmethod
    def setUpClass(cls):
        cls.folder=P.REPORT/'native'
        cls.raw=P.read(cls.folder/'base-shared/capture.json')

    def rejected(self, mutation):
        """Mutates an in-memory raw trace while keeping every real file unchanged."""
        data=copy.deepcopy(self.raw); mutation(data)
        with self.assertRaises((ValueError,KeyError,TypeError)):
            P.validate_run(data,[1152,648],False)

    def test_complete_native_packet(self):
        result=P.verify(self.folder)
        self.assertEqual(len(result),6)
        self.assertEqual(result['retina-2x-shared']['stalled_steps'],0)

    def test_decoded_video_review_provenance(self):
        from PIL import Image
        folder=P.REPORT/'video-review'; source=P.read(folder/'source.json')
        self.assertEqual(source['kind'],'decoded-video-contact-sheet'); self.assertIs(source['rescaled'],False)
        self.assertEqual(source['sheet_sha256'],P.sha(folder/'frames-90-97.png'))
        with Image.open(folder/'frames-90-97.png') as image: self.assertEqual(image.size,(1224,392))
        self.assertEqual(source['decoder_sha256'],P.sha(current_source(P.ROOT, 'tools/pose_video_frames.swift')))
        self.assertEqual(source['plot_sha256'],pinned_sha(P.ROOT, 'tools/pose_video_strip.py', 'd609ab4fa6d82d6d013265183f018b8836abf7cc', '89d6198c307c16d79e4517973c1c47fc95079cdabb4056925465204ad4a03943'))
        for mode in ['physical','shared']:
            self.assertEqual(source['mp4_sha256'][mode],P.sha(self.folder/('base-'+mode)/'walk.mp4'))
            rows=[r for r in source['frames'] if r['mode']==mode]
            self.assertEqual([r['frame'] for r in rows],list(range(90,98)))
            self.assertTrue(all(abs(r['seconds']-r['frame']/60)<1e-5 and [r['width'],r['height']]==[1152,648] for r in rows))

    def test_real_automatic_callbacks(self):
        source=P.read(P.REPORT/'live-source.json')
        for name,digest in source['artifacts'].items(): self.assertEqual(P.sha(P.REPORT/name),digest)
        data=P.read(P.REPORT/'live-callbacks.json')
        self.assertIs(data['native'],False); self.assertIs(data['performance_eligible'],False)
        self.assertEqual(data['errors'],[]); self.assertEqual(len(data['rows']),240)
        observed=0
        for index,row in enumerate(data['rows']):
            self.assertGreaterEqual(row['alpha'],0); self.assertLessEqual(row['alpha'],1)
            expected=[row['previous'][j]+(row['player'][j]-row['previous'][j])*row['alpha'] for j in range(2)]
            self.assertTrue(P.near(row['ground'],expected))
            self.assertTrue(P.near(row['camera'],[max(0,min(1248,expected[0]-576)),max(0,min(720,expected[1]-324))]))
            if index and row['player']==data['rows'][index-1]['player'] and row['ground']!=data['rows'][index-1]['ground']: observed+=1
        self.assertEqual(observed,data['sub_tick_frames']); self.assertGreaterEqual(observed,10)

    def test_native_conditions(self):
        for key,value in [('kind','pose-probe'),('physics_hz',60),('performance_eligible',True),('content_scale_factor',2)]:
            with self.subTest(key=key): self.rejected(lambda d:d.update({key:value}))
        self.rejected(lambda d:d['frames'][100].update(focused=False))
        self.rejected(lambda d:d['frames'][100].update(readback=[2304,1296]))
        self.rejected(lambda d:d['frames'][100].update(automatic_render=True))

    def test_foot_uses_the_wrong_phase(self):
        self.rejected(lambda d:d['frames'][101].update(ground=d['frames'][101]['player']))
        self.rejected(lambda d:d['frames'][101].update(foot_world=d['frames'][101]['player']))

    def test_root_shader_uses_physics_instead_of_displayed_foot(self):
        def wrong(data):
            row=data['frames'][101]
            row['shader_contact']=[(row['player'][j]-row['root'][j])/72 for j in range(2)]
        self.rejected(wrong)
        self.rejected(lambda d:d['frames'][100].update(root_canvas=[0,0]))

    def test_camera_and_pointer_phase(self):
        self.rejected(lambda d:d['frames'][101].update(camera=d['frames'][100]['camera']))
        self.rejected(lambda d:d['frames'][101].update(background=[0,0]))
        self.rejected(lambda d:d['frames'][101].update(pointer_window=[0,0]))
        self.rejected(lambda d:d['frames'][101].update(pointer_cell=[0,0]))

    def test_render_does_not_change_physics_or_clock(self):
        self.rejected(lambda d:d['frames'][101].update(player=[700,800]))
        self.rejected(lambda d:d['frames'][101].update(minutes=d['frames'][100]['minutes']+1/60))
        self.rejected(lambda d:d['frames'][101].update(walk_clock=0))

    def test_incomplete_or_reordered_frames(self):
        self.rejected(lambda d:d['frames'].pop(100))
        self.rejected(lambda d:d['frames'][100].update(alpha=1))
        self.rejected(lambda d:d.update(inputs=[]))

    def test_stop_resets_animation_clock(self):
        stopped=[row for i,row in enumerate(self.raw['frames']) if i and row['stage']==self.raw['frames'][i-1]['stage'] and row['physical_walk_clock']<self.raw['frames'][i-1]['physical_walk_clock']]
        self.assertTrue(stopped)
        for row in stopped: self.assertEqual(row['walk_clock'],0)

    def test_source_video_and_coverage(self):
        for mode in ['source','video','missing']:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix='pose-negative-') as raw:
                folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
                if mode=='source':
                    path=folder/'instrumentation/scripts/systems/presentation_pose_system.gd'
                    path.write_bytes(path.read_bytes()+b'\n# changed\n')
                elif mode=='video':
                    path=folder/'base-shared/walk.mp4'; data=bytearray(path.read_bytes()); data[-20]^=1; path.write_bytes(data)
                else: (folder/'base-shared/engine.txt').unlink()
                with self.assertRaises((ValueError,OSError)): P.verify(folder)

    def test_signed_metadata_cannot_hide_a_launch_failure(self):
        with tempfile.TemporaryDirectory(prefix='pose-negative-') as raw:
            folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
            path=folder/'base-shared/environment.json'; data=P.read(path); data['exit_code']=1
            path.write_text(json.dumps(data)+'\n'); P.manifest(folder,P.read(folder/'source.json'))
            with self.assertRaisesRegex(ValueError,'launch'): P.verify(folder)

    def test_completed_packet_cannot_be_resumed(self):
        with tempfile.TemporaryDirectory(prefix='pose-negative-') as raw:
            folder=Path(raw); source=P.read(self.folder/'source.json')
            source['complete']=True
            (folder/'source.json').write_text(json.dumps(source))
            before=(folder/'source.json').read_bytes()
            with patch.object(P.subprocess,'run',side_effect=AssertionError('no GUI in rejection test')):
                with self.assertRaisesRegex(ValueError,'incomplete'): P.capture(folder,True)
            self.assertEqual((folder/'source.json').read_bytes(),before)

    def test_resume_rejects_changed_instrumentation(self):
        with tempfile.TemporaryDirectory(prefix='pose-negative-') as raw:
            folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
            source=P.read(folder/'source.json'); source['complete']=False
            (folder/'source.json').write_text(json.dumps(source))
            target=folder/'instrumentation/scripts/systems/presentation_pose_system.gd'
            target.write_bytes(target.read_bytes()+b'\n# changed\n')
            with patch.object(P,'ROOT',current_inputs(folder)), patch.object(P.subprocess,'run',side_effect=AssertionError('no GUI in rejection test')):
                with self.assertRaisesRegex(ValueError,'source changed'): P.capture(folder,True)

    def test_resume_cannot_resign_damaged_completed_video(self):
        with tempfile.TemporaryDirectory(prefix='pose-negative-') as raw:
            folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
            source=P.read(folder/'source.json'); source['complete']=False
            (folder/'source.json').write_text(json.dumps(source))
            target=folder/'base-physical/walk.mp4'
            target.write_bytes(target.read_bytes()+b'changed')
            before=(folder/'source.json').read_bytes()
            with patch.object(P,'ROOT',current_inputs(folder)), patch.object(P.subprocess,'run',side_effect=AssertionError('no GUI in rejection test')):
                with self.assertRaisesRegex(ValueError,'completed artifact changed'): P.capture(folder,True)
            self.assertEqual((folder/'source.json').read_bytes(),before)

    def test_collectors_must_be_archived_and_safe(self):
        with tempfile.TemporaryDirectory(prefix='pose-negative-') as raw:
            folder=Path(raw)/'packet'; shutil.copytree(self.folder,folder)
            source=P.read(folder/'source.json')
            source['resume_tools'][0]['path']='../outside.py'
            with self.assertRaisesRegex(ValueError,'unsafe'): P.collector_sources(folder,source)
            path=folder/'base-shared/environment.json'; data=P.read(path)
            data['collector_sha256']='0'*64; path.write_text(json.dumps(data))
            P.manifest(folder,P.read(folder/'source.json'))
            with self.assertRaisesRegex(ValueError,'unknown collector'): P.verify(folder)


if __name__=='__main__': unittest.main()
