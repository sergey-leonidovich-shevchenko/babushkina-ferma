#!/usr/bin/env python3
"""Reject incomplete/tampered shadow evidence in temporary copies only."""
import json,shutil,tempfile,unittest
from pathlib import Path
from PIL import Image
import shadow_inventory_verify as check

class ShadowInventoryTests(unittest.TestCase):
    """Exercise actual native evidence rather than mirrored synthetic renderer logic."""
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.report=Path(self.temp.name)/'report';shutil.copytree(check.REPORT,self.report)

    def edit(self,name,change):
        path=self.report/name;data=json.loads(path.read_text());change(data);path.write_text(json.dumps(data)+'\n')

    def resign(self):
        folder=self.report/'native';p=folder/'source.json';data=json.loads(p.read_text())
        data['artifacts']={str(n.relative_to(folder)):check.digest(n.read_bytes()) for n in folder.rglob('*') if n.is_file() and n.name!='source.json' and 'inputs' not in n.parts}
        p.write_text(json.dumps(data)+'\n')

    def refused(self):
        with self.assertRaises((ValueError,KeyError,FileNotFoundError)):check.verify(self.report)

    def test_actual_series(self):
        result=check.verify(self.report);self.assertEqual((result['reviewed_png'],result['native_cases'],result['target_png'],result['window_png'],result['game_callbacks'],result['target_callbacks']),(45,16,48,32,32,96))

    def test_missing_raster(self):
        self.edit('inventory.json',lambda d:d['assets'].pop());self.refused()

    def test_source_hash(self):
        self.edit('inventory.json',lambda d:d['assets'][0].update(sha256='0'*64));self.refused()

    def test_owner_location(self):
        self.edit('inventory.json',lambda d:d['renderer_rules'][0].update(line=1));self.refused()

    def test_false_solar_claim(self):
        self.edit('inventory.json',lambda d:d.update(dynamic_solar_implemented=True));self.refused()

    def test_production_coverage(self):
        self.edit('native/source.json',lambda d:d['production'].pop());self.refused()

    def test_incomplete_series(self):
        self.edit('native/source.json',lambda d:d.update(complete=False));self.refused()

    def test_duplicate_case(self):
        self.edit('native/1152/capture.json',lambda d:d['rows'].__setitem__(1,d['rows'][0]));self.resign();self.refused()

    def test_hidden_window(self):
        self.edit('native/1152/capture.json',lambda d:d['rows'][0].update(visible=False));self.resign();self.refused()

    def test_gameplay_changed(self):
        self.edit('native/1152/capture.json',lambda d:d['rows'][0]['game']['after'].update(coins=9999));self.resign();self.refused()

    def test_reset_seed(self):
        def change(d):
            game=d['rows'][0]['game']
            for state in [game['before'],game['after']]+[state for draw in game['draws'] for state in [draw['before'],draw['after']]]:state['world_loot_seed']=0
        self.edit('native/1152/capture.json',change);self.resign();self.refused()

    def test_missing_draw(self):
        self.edit('native/1152/capture.json',lambda d:d['rows'][0]['samples'][0]['records'].pop());self.resign();self.refused()

    def test_off_still_dispatches_contact(self):
        self.edit('native/1152/capture.json',lambda d:d['rows'][0]['samples'][1]['records'][0]['rows'][0].update(shadow_calls=1));self.resign();self.refused()

    def test_cropped_body(self):
        def change(d):
            for sample in d['rows'][0]['samples']:
                for frame in sample['records']:frame['rows'][0]['destination'][1]=500
        self.edit('native/1152/capture.json',change);self.resign();self.refused()

    def test_disabled_contact_has_no_difference(self):
        folder=self.report/'native/1152';shutil.copyfile(folder/'720-single-plain.png',folder/'720-single-shadow.png');self.resign();self.refused()

    def test_opaque_body_removed(self):
        folder=self.report/'native/1152'
        with Image.open(folder/'720-single-body.png') as original:mask=original.convert('RGBA');point=next((x,y) for y in range(256) for x in range(768) if mask.getpixel((x,y))[3]>=250)
        with Image.open(folder/'720-single-plain.png') as original:image=original.convert('RGBA')
        image.putpixel(point,(255,0,255,255));image.save(folder/'720-single-plain.png');self.resign();self.refused()

    def test_raw_corruption(self):
        (self.report/'native/1152/720-single-plain.png').write_bytes(b'not an image');self.refused()

    def test_archived_qa_changed(self):
        p=self.report/'native/inputs/tools/shadow_inventory_canvas.gd';p.write_text(p.read_text()+'\n# changed\n');self.refused()

if __name__=='__main__':unittest.main()
