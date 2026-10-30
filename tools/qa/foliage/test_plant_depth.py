#!/usr/bin/env python3
"""Reject damaged copies of actual plant-depth evidence without changing native archives."""
import copy,json,tempfile,unittest
from pathlib import Path
from PIL import Image
from tools.qa.foliage import plant_depth_verify as audit

class PlantDepthTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before=audit.capture(audit.REPORT/'native/before/1152')
        cls.after=audit.capture(audit.REPORT/'native/after/1152')

    def changed(self,edit):
        data=copy.deepcopy(self.after);edit(data)
        with self.assertRaises(ValueError):audit.validate_rows(data,'after',1152)

    def test_actual_native_proof(self):
        data=audit.verify();self.assertFalse(data['performance_eligible']);self.assertFalse(data['full_map_accepted'])
        self.assertEqual(sum(w['draw_callbacks'] for w in data['windows'].values()),576)
        self.assertTrue(all(w['exact_legacy_pairs']==48 and w['changed_enabled_frames']==[6,10,14,15] for w in data['windows'].values()))

    def test_missing_frame(self):self.changed(lambda d:d['rows'].pop())
    def test_duplicate_frame(self):self.changed(lambda d:d['rows'][1].update(index=0,mode='legacy'))
    def test_wrong_window(self):self.changed(lambda d:d['rows'][0].update(window=[1280,720]))
    def test_missing_focus(self):self.changed(lambda d:d['rows'][0].update(focused=False))
    def test_hidden_window(self):self.changed(lambda d:d['rows'][0].update(visible=False))
    def test_snapshot_mutation(self):self.changed(lambda d:d['rows'][0]['after'].update(coins=999))
    def test_duplicate_production_callback(self):self.changed(lambda d:d['rows'][0]['draws'].append(copy.deepcopy(d['rows'][0]['draws'][0])))
    def test_retained_callback(self):self.changed(lambda d:d['rows'][0]['depths'][0].update(queue_after=1))
    def test_opaque_duplicate_key(self):
        self.changed(lambda d:d['rows'][1]['depths'][0]['trace'].append(copy.deepcopy(d['rows'][1]['depths'][0]['trace'][0])))
    def test_wrong_ground_boundary(self):
        def edit(d):
            item=d['rows'][1]['depths'][0]['trace'][0];item['phase']='back' if item['phase']=='front' else 'front'
        self.changed(edit)
    def test_different_presentation_ground(self):self.changed(lambda d:d['rows'][1]['depths'][0].update(hero_ground=[0,0]))
    def test_unstable_equal_root_order(self):
        def edit(d):
            row=next(r for r in d['rows'] if r['id']=='same-depth:a' and r['mode']=='enabled');trace=row['depths'][0]['trace']
            indices=[i for i,t in enumerate(trace) if t['kind']=='body' and t['phase']=='front' and t['key'].startswith('forage_berries:')]
            self.assertEqual(len(indices),2);a,b=indices;trace[a],trace[b]=trace[b],trace[a]
        self.changed(edit)
    def test_new_body_in_other_map(self):
        def edit(d):
            row=next(r for r in d['rows'] if r['id']=='other-map' and r['mode']=='enabled');row['depths'][0]['trace'][0]['kind']='body'
        self.changed(edit)
    def test_fake_sweep(self):
        def edit(d):
            for r in d['rows']:
                if r['id'].startswith('sweep:'):r['player']=[792,750]
        self.changed(edit)
    def test_unbounded_trace(self):
        self.changed(lambda d:d['rows'][1]['depths'][0].update(trace=[copy.deepcopy(d['rows'][1]['depths'][0]['trace'][0])]*512))
    def test_incomplete_source(self):
        p=audit.REPORT/'native/after';s=json.loads((p/'source.json').read_text());s['complete']=False
        with self.assertRaises(ValueError):audit.validate_source(p,'after',json.loads((audit.REPORT/'changes.json').read_text()),s)
    def test_missing_source_coverage(self):
        p=audit.REPORT/'native/after';s=json.loads((p/'source.json').read_text());s['sources'].pop(audit.NEW)
        with self.assertRaises(ValueError):audit.validate_source(p,'after',json.loads((audit.REPORT/'changes.json').read_text()),s)
    def test_changed_artifact(self):
        p=audit.REPORT/'native/after';s=json.loads((p/'source.json').read_text());s['artifacts']['1152/frames/enabled/0000.png']='0'*64
        with self.assertRaises(ValueError):audit.validate_source(p,'after',json.loads((audit.REPORT/'changes.json').read_text()),s)
    def test_unrelated_pixel(self):
        off=next(r for r in self.after['rows'] if r['mode']=='legacy' and r['index']==6);on=next(r for r in self.after['rows'] if r['mode']=='enabled' and r['index']==6)
        p=audit.REPORT/'native/after/1152';image=Image.open(p/on['image_file']).convert('RGBA');image.putpixel((0,0),(0,255,255,255))
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'bad.png';image.save(path)
            with self.assertRaises(ValueError):audit.compare_pixels(p/off['image_file'],path,off,on,1152)

if __name__=='__main__':unittest.main()
