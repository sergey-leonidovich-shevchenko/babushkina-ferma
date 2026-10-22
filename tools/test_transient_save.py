#!/usr/bin/env python3
"""Corrupt isolated native metadata/source copies; never replace accepted evidence."""
import copy,json,tempfile,unittest
from pathlib import Path
from PIL import Image
import transient_save_verify as audit

class TransientSaveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.data=audit.load(audit.REPORT/'native/after/1152/capture.json')
    def changed(self,edit):
        data=copy.deepcopy(self.data);edit(data)
        with self.assertRaises(ValueError):audit.metadata(data,'after',1152)
    def test_actual_native_proof(self):
        data=audit.verify();self.assertFalse(data['performance_eligible']);self.assertFalse(data['full_map_accepted'])
        self.assertEqual(sum(w['draw_callbacks'] for w in data['windows'].values()),16)
    def test_missing_row(self):self.changed(lambda d:d['rows'].pop())
    def test_duplicate_row(self):self.changed(lambda d:d['rows'][1].update(id='plain'))
    def test_wrong_window(self):self.changed(lambda d:d['rows'][0].update(window=[1280,720]))
    def test_missing_focus(self):self.changed(lambda d:d['rows'][0].update(focused=False))
    def test_snapshot_mutation(self):self.changed(lambda d:d['rows'][1]['after'].update(coins=999))
    def test_metadata_leak(self):self.changed(lambda d:d['rows'][1]['before'].update(shader_time=93.25))
    def test_fake_production_callback(self):self.changed(lambda d:d['rows'][0]['draws'].__setitem__(1,copy.deepcopy(d['rows'][0]['draws'][0])))
    def test_writer_accepted_resource(self):self.changed(lambda d:d['writer'].update(unsafe_accepted=True))
    def test_primary_modified(self):self.changed(lambda d:d['writer'].update(primary_unchanged=False))
    def test_backup_modified(self):self.changed(lambda d:d['writer'].update(backup_unchanged=False))
    def test_no_positive_io_control(self):self.changed(lambda d:d['writer'].update(healthy_writes=False))
    def test_no_native_gpu_reference(self):self.changed(lambda d:d['writer'].update(material_rid_valid=False))
    def test_partial_source(self):
        p=audit.REPORT/'native/after';s=audit.load(p/'source.json');s['complete']=False
        with self.assertRaises(ValueError):audit.provenance(p,'after',audit.load(audit.REPORT/'changes.json'),s)
    def test_missing_script(self):
        p=audit.REPORT/'native/after';s=audit.load(p/'source.json');s['sources'].pop('scripts/systems/save_system.gd')
        with self.assertRaises(ValueError):audit.provenance(p,'after',audit.load(audit.REPORT/'changes.json'),s)
    def test_changed_artifact(self):
        p=audit.REPORT/'native/after';s=audit.load(p/'source.json');s['artifacts']['1152/plain.png']='0'*64
        with self.assertRaises(ValueError):audit.provenance(p,'after',audit.load(audit.REPORT/'changes.json'),s)
    def test_changed_pixel(self):
        p=audit.REPORT/'native/after/1152/plain.png'
        with Image.open(p) as source:image=source.convert('RGBA')
        image.putpixel((0,0),(255,0,255,255))
        with tempfile.TemporaryDirectory() as folder:
            target=Path(folder)/'wrong.png';image.save(target)
            with self.assertRaises(ValueError):audit.same_pixels(p,target,1152)

if __name__=='__main__':unittest.main()
