#!/usr/bin/env python3
"""Corrupt only copies of actual VRENDER-005 native data; never weaken historical proof."""
import copy,gzip,json,tempfile,unittest
from pathlib import Path
from PIL import Image
import pilot_pass_verify as v

class PassProofTests(unittest.TestCase):
    def setUp(self):
        self.data=v.load(v.REPORT/'native/after/1152/capture.json')
        self.rows={r['id']:r for r in self.data['rows']}
        self.routes=json.loads(gzip.decompress((v.REPORT/'native/after/1152/board-front-command-routes.json.gz').read_bytes()))

    def rejected_meta(self):
        with self.assertRaises((AssertionError,ValueError)):v.metadata(self.data,1152,'after')

    def rejected_routes(self,values=None,row=None):
        with self.assertRaises((AssertionError,ValueError)):v.routes(values or self.routes,row or self.rows['board-front-command'],'after')

    def test_actual_production_data(self):
        self.assertEqual(len(v.metadata(self.data,1152,'after')),45)
        self.assertEqual(v.routes(self.routes,self.rows['board-front-command'],'after')['command'],4)

    def test_missing_focus(self):
        self.data['rows'][0]['focused']=False;self.rejected_meta()

    def test_wrong_window(self):
        self.data['rows'][0]['window']=[2304,1296];self.rejected_meta()

    def test_partial_series(self):
        self.data['rows'].pop();self.rejected_meta()

    def test_duplicate_case(self):
        self.data['rows'].append(copy.deepcopy(self.data['rows'][0]));self.rejected_meta()

    def test_save_mutation(self):
        self.data['rows'][0]['after']['coins']+=1;self.rejected_meta()

    def test_false_flag(self):
        self.rows['board-front-command']['flag']='true';self.rejected_meta()

    def test_false_default(self):
        self.rows['default']['flag']=False;self.rejected_meta()

    def test_material_leak(self):
        self.routes[0]['material_equal']=False;self.rejected_routes()

    def test_cache_growth(self):
        self.routes[0]['cache_count']=4;self.rejected_routes()

    def test_per_frame_packet_rebuild(self):
        self.routes[1]['cache_builds']+=1;self.rejected_routes()

    def test_command_outside_scope(self):
        self.routes[0]['trace'][0]['position']=[1656,528];self.rejected_routes()

    def test_command_in_foreground(self):
        self.routes[0]['trace'][0]['foreground']=True;self.rejected_routes()

    def test_double_fallback(self):
        p=v.REPORT/'native/after/1152/invalid-source-command-routes.json.gz';values=json.loads(gzip.decompress(p.read_bytes()));values[0]['trace'][0]['fallback_calls']=2
        self.rejected_routes(values,self.rows['invalid-source-command'])

    def test_default_not_actually_exercised(self):
        values=copy.deepcopy(self.routes)
        for value in values:value['trace']=[]
        self.rejected_routes(values,self.rows['default'])

    def test_hidden_rgba_change(self):
        folder=v.REPORT/'native/after/1152'
        with tempfile.TemporaryDirectory() as tmp,Image.open(folder/'board-front-command.png') as im:
            changed=im.convert('RGBA');changed.putpixel((40,25),(1,2,3,0));p=Path(tmp)/'changed.png';changed.save(p)
            with self.assertRaises((AssertionError,ValueError)):v.equal_png(folder/'board-front-legacy.png',p,1152)

if __name__=='__main__':unittest.main()
