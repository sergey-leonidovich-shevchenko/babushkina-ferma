#!/usr/bin/env python3
"""Reject corrupted copies of actual static-pilot evidence, without altering the retained archive."""
import copy,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from PIL import Image
import pilot_static_verify as v
import pilot_static_audit as a

class PilotProofTests(unittest.TestCase):
    def setUp(self):
        self.data=v.load(v.REPORT/'native/static/1152/capture.json')

    def rejected(self):
        with self.assertRaises((AssertionError,ValueError)):v.metadata(self.data,1152)

    def test_actual_native_evidence(self):
        self.assertEqual(len(v.metadata(self.data,1152)),22)

    def test_hidden_window(self):
        self.data['rows'][0]['visible']=False;self.rejected()

    def test_wrong_framebuffer(self):
        self.data['rows'][0]['image']=[2304,1296];self.rejected()

    def test_incomplete_run(self):
        self.data['rows'].pop();self.rejected()

    def test_duplicate_case(self):
        self.data['rows'].append(copy.deepcopy(self.data['rows'][0]));self.rejected()

    def test_save_mutation(self):
        self.data['rows'][0]['after']['coins']+=1;self.rejected()

    def test_study_is_not_ordinary_game(self):
        row=next(r for r in self.data['rows'] if r['id']=='study-painted-a-front');row['study']=False;self.rejected()

    def test_old_slot_grants_remain_exact(self):
        row=next(r for r in self.data['rows'] if r['id']=='old-slot-interior');row['before']['coins']=1;row['after']['coins']=1;self.rejected()

    def test_rollback_cannot_relocate_game(self):
        row=next(r for r in self.data['rows'] if r['id']=='rollback');row['camera'][0]+=24;self.rejected()

    def test_outside_prop_pixels_rejected(self):
        folder=v.REPORT/'native/static/1152'
        with tempfile.TemporaryDirectory() as tmp,Image.open(folder/'study-painted-a-front.png') as im:
            image=im.convert('RGBA');image.putpixel((20,20),(1,2,3,255));path=Path(tmp)/'changed.png';image.save(path)
            with self.assertRaises((AssertionError,ValueError)):v.pixels(folder/'study-legacy-a-front.png',path,1152)

    def test_noop_study_rejected(self):
        p=v.REPORT/'native/static/1152/study-legacy-a-front.png'
        with self.assertRaises((AssertionError,ValueError)):v.pixels(p,p,1152)

    def test_false_predecessor_status_rejected(self):
        base=v.load(v.REPORT/'dependency-audit.json')['base_commit'];original=a.git_json
        def damaged(ref,path):
            data=original(ref,path)
            if path.endswith('backlog.json'):
                next(t for t in data['tasks'] if t['id']=='VPROP-007')['status']='in_progress'
            return data
        with patch.object(a,'git_json',damaged):
            with self.assertRaises((AssertionError,ValueError)):a.audit(base)

if __name__=='__main__':unittest.main()
