#!/usr/bin/env python3
"""Regression tests for rejection of invalid meadow evidence, using synthetic documents only."""
import copy
import unittest
from tools.qa.ground.ground_edge_verify import PAIRS, metadata, retained, profile


def fixture():
    """Construct a validator fixture; this is never native or visual evidence."""
    row={'viewports':1,'draws':4,'readback':[1152,648],'logical':[1152,648],'focused':True,'physical':[1152,648],
        'zoom':1.2,'camera':[1.25,2.25],'player':[600.25,700.25],'location':'overworld','season':'spring','weather':'clear','snapshot':{'hp':73}}
    rows=[]
    for pair in PAIRS:
        for suffix in ['-before','-after']: rows.append(dict(copy.deepcopy(row),id=pair+suffix,soft_edges=suffix=='-after'))
    rows += [dict(copy.deepcopy(row),id=name,soft_edges=True) for name in ['direct','cached']]
    return {'task':'VGROUND-003','errors':[],'display':'macOS','simulation_frozen':True,'performance_eligible':False,'gpu_time_ms':None,
        'window':[1152,648],'material':{'size':[512,512],'image_bytes':1398100,'cell_world':192,'scale':1.2},'rows':rows}


class GroundEdgeEvidence(unittest.TestCase):
    def test_smooth_realistic_profile(self):
        self.assertEqual(profile([0,0,0,0,0,11,21,42,84,125,164,206,230,243,255,255,255,255,255,255,255,255,255,255,255,255])['levels'],11)

    def test_binary_or_truncated_profile(self):
        for values in [[0]*13+[255]*13,[0]*26,[0]*25]:
            with self.assertRaises(ValueError): profile(values)

    def test_valid_document(self):
        self.assertEqual(len(metadata(fixture(),1152)),20)

    def test_incomplete_cases(self):
        data=fixture(); data['rows'].pop()
        with self.assertRaises(ValueError): metadata(data,1152)

    def test_real_window_required(self):
        for key,value in [('focused',False),('physical',[960,540]),('zoom',1.0),('logical',[1280,720]),('readback',[1280,720]),('viewports',2),('draws',3)]:
            with self.subTest(key=key):
                data=fixture(); data['rows'][0][key]=value
                with self.assertRaises(ValueError): metadata(data,1152)

    def test_saved_health_and_camera_cannot_be_omitted(self):
        for key,value in [('snapshot',{'hp':72}),('camera',[1,2]),('player',[600,700]),('location','forest'),('weather','rain'),('soft_edges',False)]:
            with self.subTest(key=key):
                data=fixture(); data['rows'][1][key]=value
                with self.assertRaises(ValueError): metadata(data,1152)

    def test_performance_overclaim_rejected(self):
        for key,value in [('display','headless'),('errors',['focus lost']),('simulation_frozen',False),('performance_eligible',True),('gpu_time_ms',0.0)]:
            with self.subTest(key=key):
                data=fixture(); data[key]=value
                with self.assertRaises(ValueError): metadata(data,1152)

    def test_mipmap_or_scale_substitution(self):
        for key,value in [('size',[1254,1254]),('image_bytes',1048576),('cell_world',384),('scale',.6)]:
            with self.subTest(key=key):
                data=fixture(); data['material'][key]=value
                with self.assertRaises(ValueError): metadata(data,1152)

    def test_retained_bytes_and_counters(self):
        data={'callbacks':120,'paints_before':2,'paints_after':2,'requests_before':3,'requests_after':3,'hash_before':'a'*64,'hash_after':'a'*64}
        retained(data)
        for key,value in [('callbacks',119),('paints_after',3),('requests_after',4),('hash_after','b'*64)]:
            with self.subTest(key=key):
                broken=dict(data); broken[key]=value
                with self.assertRaises(ValueError): retained(broken)


if __name__=='__main__': unittest.main()
