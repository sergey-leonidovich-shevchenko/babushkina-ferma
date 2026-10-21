#!/usr/bin/env python3
"""Reject false local-revision evidence; modifications stay in temporary copies."""
import copy
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from terrain_revision_verify import REPORT, load, metadata, metrics, local_pixels, equal


class TerrainRevisionEvidenceTests(unittest.TestCase):
    """Counters alone cannot prove that a GPU target was updated locally."""
    @classmethod
    def setUpClass(cls):
        cls.folder=REPORT/'native/1152';cls.capture=load(cls.folder/'capture.json')

    def test_complete_cases_and_real_operation_deltas(self):
        self.assertEqual(len(metadata(self.capture,1152)),26);self.assertEqual(len(metrics(self.capture)),15)

    def test_missing_case_wrong_window_and_false_fps_rejected(self):
        for key,value in [('performance_eligible',True),('gpu_time_ms',1),('window',[1280,720])]:
            data=copy.deepcopy(self.capture);data[key]=value
            with self.assertRaises(ValueError):metadata(data,1152)
        data=copy.deepcopy(self.capture);data['rows'].pop()
        with self.assertRaises(ValueError):metadata(data,1152)

    def test_changed_save_or_camera_rejected(self):
        for key,value in [('snapshot',{}),('camera',[0,0]),('zoom',1.0),('focused',False)]:
            data=copy.deepcopy(self.capture);data['rows'][0][key]=value
            with self.assertRaises(ValueError):metadata(data,1152)

    def test_extra_saved_change_in_watering_rejected(self):
        data=copy.deepcopy(self.capture);row=next(r for r in data['rows'] if r['id']=='plot-after');row['snapshot']['coins']+=1
        with self.assertRaisesRegex(ValueError,'another saved field'):metadata(data,1152)

    def test_full_clear_or_wrong_clip_disguised_as_local_rejected(self):
        for key,value in [('clear_mode',0),('clip',[0,0,2400,1368])]:
            data=copy.deepcopy(self.capture);next(o for o in data['operations'] if o['id']=='local')['scheduled'][key]=value
            with self.assertRaises(ValueError):metrics(data)

    def test_recreated_target_or_unfinished_queue_rejected(self):
        for key,value in [('texture_id',999),('targets',2),('ready',False)]:
            data=copy.deepcopy(self.capture);next(o for o in data['operations'] if o['id']=='local')['after'][key]=value
            with self.assertRaises(ValueError):metrics(data)

    def test_lost_request_rebuilt_neighbor_and_idle_work_rejected(self):
        for case in ['rapid','plot','idle']:
            data=copy.deepcopy(self.capture);op=next(o for o in data['operations'] if o['id']==case)
            if case=='rapid':op['after']['revision']['local_paints']-=1
            elif case=='plot':op['meshes_after']['(0, 0)']=123
            else:op['after']['paints']+=1
            with self.assertRaises(ValueError):metrics(data)

    def test_rgb_and_hidden_alpha_outside_region_rejected(self):
        with tempfile.TemporaryDirectory(prefix='terrain-region-test-') as tmp:
            target=Path(tmp)/'changed.png';original=self.folder/'local-after-cache.png'
            for channel in [0,3]:
                image=Image.open(original).convert('RGBA');pixel=list(image.getpixel((12,12)));pixel[channel]=(pixel[channel]+1)%256;image.putpixel((12,12),tuple(pixel));image.save(target)
                with self.assertRaisesRegex(ValueError,'outside'):local_pixels(self.folder/'local-before-cache.png',target)

    def test_empty_update_and_changed_control_pixel_rejected(self):
        with self.assertRaises(ValueError):local_pixels(self.folder/'local-before-cache.png',self.folder/'local-before-cache.png')
        with tempfile.TemporaryDirectory(prefix='terrain-control-test-') as tmp:
            path=Path(tmp)/'control.png';image=Image.open(self.folder/'local-first.png').convert('RGBA');image.putpixel((12,12),(0,0,0,0));image.save(path)
            with self.assertRaises(ValueError):equal(self.folder/'full-first.png',path)


if __name__=='__main__':unittest.main()
