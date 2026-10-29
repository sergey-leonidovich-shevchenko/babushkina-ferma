#!/usr/bin/env python3
"""Positive and negative evidence checks; mutate only temporary copies."""
import copy
import shutil
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from tools.qa.ground.decoration_verify import REPORT, load, metadata, policy, images, water_overlap, provenance


class DecorationEvidenceTests(unittest.TestCase):
    """Do not allow green metadata to hide a changed scene or unsafe seed."""
    @classmethod
    def setUpClass(cls):
        cls.folder=REPORT/'native'; cls.capture=load(cls.folder/'1152/capture.json'); cls.geometry=load(cls.folder/'1152/policy.json')

    def test_complete_geometry_and_two_windows(self):
        for width in [1152,1280]: self.assertEqual(len(metadata(load(self.folder/str(width)/'capture.json'),width)),52)
        accepted,rejected=policy(self.geometry)
        self.assertEqual((len(accepted),len(rejected)),(86,200))

    def test_missing_or_duplicate_case_rejected(self):
        for mode in ['missing','duplicate']:
            data=copy.deepcopy(self.capture)
            if mode=='missing': data['rows'].pop()
            else: data['rows'][-1]=copy.deepcopy(data['rows'][0])
            with self.assertRaises(ValueError): metadata(data,1152)

    def test_wrong_window_focus_or_zoom_rejected(self):
        for key,value in [('zoom',1.0),('focused',False),('readback',[1280,720])]:
            data=copy.deepcopy(self.capture); data['rows'][0][key]=value
            with self.assertRaises(ValueError): metadata(data,1152)

    def test_changed_full_save_rejected(self):
        data=copy.deepcopy(self.capture); data['rows'][1]['snapshot']['injected_state']=True
        with self.assertRaisesRegex(ValueError,'snapshot'): metadata(data,1152)

    def test_false_performance_or_ordinary_scene_claim_rejected(self):
        for key,value in [('performance_eligible',True),('gpu_time_ms',1),('ordinary_scene_has_procedural_seed',True),('rain_pixel_equality_not_claimed',False)]:
            data=copy.deepcopy(self.capture); data[key]=value
            with self.assertRaises(ValueError): metadata(data,1152)

    def test_unsafe_seed_and_missing_protected_category_rejected(self):
        data=copy.deepcopy(self.geometry); row=next(r for r in data['candidates'] if r['reason']!='allowed'); row['reason']='allowed'
        with self.assertRaisesRegex(ValueError,'classification'): policy(data)
        data=copy.deepcopy(self.geometry); data['zones']=[z for z in data['zones'] if z['reason']!='farm']
        with self.assertRaisesRegex(ValueError,'category'): policy(data)

    def test_water_crossing_is_not_corner_sampling(self):
        # All corners of this rectangle miss the horizontal river strip in its middle.
        river=[[0,240],[576,240],[576,336],[0,336]]
        self.assertTrue(water_overlap([40,220,120,140],river))
        self.assertFalse(water_overlap([40,400,120,100],river))

    def test_unbounded_policy_or_false_count_rejected(self):
        for key,value in [('limit',100000),('margin',0),('accepted',999)]:
            data=copy.deepcopy(self.geometry); data[key]=value
            with self.assertRaises(ValueError): policy(data)

    def test_changed_ordinary_pixel_rejected(self):
        with tempfile.TemporaryDirectory(prefix='decoration-test-') as tmp:
            target=Path(tmp)
            for path in (self.folder/'1152').glob('*.png'): shutil.copyfile(path,target/path.name)
            path=target/'cottage-control-after.png'; image=Image.open(path).convert('RGB'); image.putpixel((20,20),(0,255,0)); image.save(path)
            with self.assertRaisesRegex(ValueError,'ordinary scene'): images(target,metadata(self.capture,1152),policy(self.geometry)[0],1152)

    def test_changed_archived_source_rejected(self):
        with tempfile.TemporaryDirectory(prefix='decoration-source-') as tmp:
            target=Path(tmp); shutil.copyfile(self.folder/'source.json',target/'source.json')
            source=load(target/'source.json'); name=next(iter(source['sources'])); path=target/'inputs'/name; path.parent.mkdir(parents=True)
            path.write_bytes(b'corrupt source')
            with self.assertRaisesRegex(ValueError,'archived source'): provenance(target)


if __name__=='__main__': unittest.main()
