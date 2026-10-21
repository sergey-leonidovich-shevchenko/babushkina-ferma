#!/usr/bin/env python3
"""Negative controls for VGROUND-007 evidence; synthetic fixtures are not native acceptance."""
import copy
import tempfile
import unittest
from pathlib import Path
from PIL import Image, ImageDraw
from garden_verify import PAIRS, metadata, retained, garden_mask, wetness, process_policy, seams, engine_log


def fixture():
    """Provide complete metadata for validator tests, never as a gameplay or rendering proof."""
    row={'viewports':1,'draws':4,'readback':[1152,648],'logical':[1152,648],'focused':True,'physical':[1152,648],
         'zoom':1.2,'camera':[1.25,2.25],'player':[600.25,700.25],'location':'overworld','season':'spring','weather':'clear','snapshot':{'hp':73}}
    rows=[dict(copy.deepcopy(row),id=pair+suffix,garden=suffix=='-after') for pair in PAIRS for suffix in ['-before','-after']]
    rows += [dict(copy.deepcopy(row),id=name,garden=True) for name in ['direct','cached']]
    return {'task':'VGROUND-007','errors':[],'display':'macOS','simulation_frozen':True,'performance_eligible':False,'gpu_time_ms':None,
            'window':[1152,648],'material':{'size':[512,512],'image_bytes':1398100,'cell_world':384,'scale':1.2,'texture':'garden_loam_v1'},'rows':rows}


class GardenEvidence(unittest.TestCase):
    def test_saved_frames_never_excuse_engine_error(self):
        engine_log('Godot\nGARDEN SHOT after\n')
        for message in ['ERROR: Parameter "mesh" is null.','SCRIPT ERROR: invalid call','Parse Error: missing type']:
            with self.assertRaises(ValueError):engine_log(message)

    def test_bright_internal_grid_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'seams.png';image=Image.new('RGB',(1152,432),(64,64,64));image.save(path)
            self.assertEqual(max(seams(path)),0)
            for n in range(1,6):
                x=round((632+48*n)*1.2);ImageDraw.Draw(image).line((x,74,x,329),fill=(140,140,140))
            image.save(path)
            with self.assertRaises(ValueError):seams(path)

    def test_complete_metadata(self):
        self.assertEqual(len(metadata(fixture(),1152)),30)

    def test_missing_junction_rejected(self):
        data=fixture(); data['rows']=[r for r in data['rows'] if r['id']!='junction-east-after']
        with self.assertRaises(ValueError): metadata(data,1152)

    def test_pair_requires_garden_toggle(self):
        data=fixture();data['rows'][1]['garden']=False
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
        data={'callbacks':120,'paints_before':1,'paints_after':1,'requests_before':2,'requests_after':2,'hash_before':'a'*64,'hash_after':'a'*64,'meshes_before':list(range(32)),'meshes_after':list(range(32))}
        retained(data)
        for key,value in [('callbacks',119),('paints_after',2),('requests_after',3),('hash_after','b'*64),('meshes_after',list(range(31)))]:
            with self.assertRaises(ValueError):retained(dict(data,**{key:value}))

    def test_explicit_static_process_policy(self):
        source={'complete':True,'task':'VGROUND-007','performance_eligible':False,'static_coexistence':True,'initial_jobs':['371 Godot']}
        process_policy(source)
        for key,value in [('performance_eligible',True),('static_coexistence',False),('static_coexistence','yes'),('initial_jobs',None),('complete',False)]:
            with self.subTest(key=key):
                with self.assertRaises(ValueError):process_policy(dict(source,**{key:value}))

    def test_transparent_mask_and_negative_pixel_control(self):
        with tempfile.TemporaryDirectory() as folder:
            a,b=Path(folder)/'mask.png',Path(folder)/'recolor.png'
            image=Image.new('RGBA',(1152,432),(255,255,255,255))
            for y in range(52,84):
                alpha=max(0,min(255,(y-57)*20))
                ImageDraw.Draw(image).line((0,y,1151,y),fill=(255,255,255,alpha))
            image.save(a);color=image.copy();color.paste((100,120,100,255),(0,200,1152,400));color.save(b)
            self.assertTrue(garden_mask(a,b)['alpha_exact_after_recolor'])
            color.putpixel((500,300),(100,100,100,10));color.save(b)
            with self.assertRaises(ValueError):garden_mask(a,b)

    def test_wetness_and_flat_or_same_tone_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'states.png';image=Image.new('RGB',(1152,432),(128,128,128))
            for y in range(432):
                ImageDraw.Draw(image).line((420,y,713,y),fill=(128+y%24,)*3)
                ImageDraw.Draw(image).line((785,y,1078,y),fill=(64+y%12,)*3)
            image.save(path);self.assertLess(wetness(path)['ratio'],.8)
            for tone in [128,0]:
                ImageDraw.Draw(image).rectangle((785,94,1078,309),fill=(tone,)*3);image.save(path)
                with self.assertRaises(ValueError):wetness(path)



if __name__=='__main__':unittest.main()
