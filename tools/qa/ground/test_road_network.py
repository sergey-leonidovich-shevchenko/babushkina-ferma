#!/usr/bin/env python3
"""Negative controls for VGROUND-005 evidence; synthetic fixtures are not native acceptance."""
import copy
import tempfile
import unittest
from pathlib import Path
from PIL import Image, ImageDraw
from tools.qa.ground.road_network_verify import PAIRS, metadata, retained, network_agreement


def fixture():
    """Provide complete metadata for validator tests, never as a gameplay or rendering proof."""
    row={'viewports':1,'draws':4,'readback':[1152,648],'logical':[1152,648],'focused':True,'physical':[1152,648],
         'zoom':1.2,'camera':[1.25,2.25],'player':[600.25,700.25],'location':'overworld','season':'spring','weather':'clear','snapshot':{'hp':73}}
    rows=[dict(copy.deepcopy(row),id=pair+suffix,joined=suffix=='-after') for pair in PAIRS for suffix in ['-before','-after']]
    rows += [dict(copy.deepcopy(row),id=name,joined=True) for name in ['direct','cached']]
    return {'task':'VGROUND-005','errors':[],'display':'macOS','simulation_frozen':True,'performance_eligible':False,'gpu_time_ms':None,
            'window':[1152,648],'material':{'size':[512,512],'image_bytes':1398100,'cell_world':192,'scale':1.2},'rows':rows}


class RoadNetworkEvidence(unittest.TestCase):
    def test_complete_metadata(self):
        self.assertEqual(len(metadata(fixture(),1152)),26)

    def test_missing_junction_rejected(self):
        data=fixture(); data['rows']=[r for r in data['rows'] if r['id']!='junction-east-after']
        with self.assertRaises(ValueError): metadata(data,1152)

    def test_pair_requires_joined_toggle(self):
        data=fixture();data['rows'][1]['joined']=False
        with self.assertRaises(ValueError): metadata(data,1152)

    def test_pair_preserves_state_and_camera(self):
        for key,value in [('snapshot',{'hp':72}),('camera',[1,2]),('player',[601,700]),('location','forest'),('weather','rain')]:
            with self.subTest(key=key):
                data=fixture(); data['rows'][1][key]=value
                with self.assertRaises(ValueError): metadata(data,1152)

    def test_native_window_and_scale_required(self):
        for key,value in [('focused',False),('physical',[960,540]),('zoom',1),('logical',[1280,720]),('readback',[960,540]),('viewports',2),('draws',0)]:
            with self.subTest(key=key):
                data=fixture(); data['rows'][0][key]=value
                with self.assertRaises(ValueError): metadata(data,1152)

    def test_no_performance_overclaim(self):
        for key,value in [('display','headless'),('errors',['focus']),('performance_eligible',True),('gpu_time_ms',0.0),('simulation_frozen',False)]:
            with self.subTest(key=key):
                data=fixture();data[key]=value
                with self.assertRaises(ValueError):metadata(data,1152)

    def test_cache_witness(self):
        data={'callbacks':120,'paints_before':1,'paints_after':1,'requests_before':2,'requests_after':2,'hash_before':'a'*64,'hash_after':'a'*64}
        retained(data)
        for key,value in [('callbacks',119),('paints_after',2),('requests_after',3),('hash_after','b'*64)]:
            with self.assertRaises(ValueError):retained(dict(data,**{key:value}))

    def test_single_pass_agreement_and_negative_pixel_controls(self):
        with tempfile.TemporaryDirectory() as folder:
            paths=[Path(folder)/name for name in ['actual.png','ref.png','mask.png','ref-mask.png']]
            image=Image.new('RGBA',(1152,1152));draw=ImageDraw.Draw(image)
            for x,y in [(120,144),(800,144),(120,432),(600,480),(800,816)]:
                cx,cy=round(x*1.2),round(y*1.2);draw.rectangle((cx-90,cy-43,cx+90,cy+43),fill=(255,255,255,255))
            for path in paths:image.save(path)
            self.assertEqual(network_agreement(*paths)['alpha_max_error'],0)
            for value in [(100,100,100,255),(255,255,255,100)]:
                broken=image.copy();broken.putpixel((144,173),value);broken.save(paths[2] if value[3]!=255 else paths[0])
                with self.assertRaises(ValueError):network_agreement(*paths)
                image.save(paths[2]);image.save(paths[0])
            blank=Image.new('RGBA',(1152,1152))
            for path in paths:blank.save(path)
            with self.assertRaises(ValueError):network_agreement(*paths)

    def test_inconsistent_arm_width(self):
        with tempfile.TemporaryDirectory() as folder:
            paths=[Path(folder)/str(i) for i in range(4)];image=Image.new('RGBA',(1152,1152),(255,255,255,255))
            for path in paths:image.save(path,format='PNG')
            with self.assertRaises(ValueError):network_agreement(*paths)


if __name__=='__main__':unittest.main()
