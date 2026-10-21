#!/usr/bin/env python3
"""Negative controls operate on copies of genuine native fence evidence."""
import copy,tempfile,unittest,shutil
from unittest.mock import patch
from pathlib import Path
from PIL import Image
import village_trade_verify as v

class TradeProofTests(unittest.TestCase):
    def setUp(self):
        """Load a real 1152px capture, not an invented optimistic fixture."""
        self.data=v.load(v.REPORT/'native/after/1152/capture.json')

    def rejected(self,data):
        """Require the acceptance gate to fail the damaged copy."""
        with self.assertRaises((AssertionError,ValueError)):v.metadata(data,1152,'after')

    def test_actual_evidence(self):
        self.assertEqual(len(v.metadata(self.data,1152,'after')),41)

    def test_hidden_window(self):
        self.data['rows'][0]['visible']=False;self.rejected(self.data)

    def test_different_physical_window(self):
        self.data['rows'][0]['window']=[2048,1152];self.rejected(self.data)

    def test_partial_phase(self):
        self.data['rows'].pop();self.rejected(self.data)

    def test_duplicate_case(self):
        self.data['rows'].append(copy.deepcopy(self.data['rows'][0]));self.rejected(self.data)

    def test_save_mutation(self):
        self.data['rows'][0]['after']['coins']+=1;self.rejected(self.data)

    def test_wrong_live_locale(self):
        row=self.data['rows'][0];row['locale']='en';self.rejected(self.data)

    def test_wrong_camera_configuration(self):
        self.data['rows'][0]['normal_effects']=True;self.rejected(self.data)

    def test_hud_change_is_rejected(self):
        row=next(r for r in self.data['rows'] if r['id']=='market-0-72')
        before=v.REPORT/'native/before/1152/market-0-72.png';after=v.REPORT/'native/after/1152/market-0-72.png'
        with tempfile.TemporaryDirectory() as folder,Image.open(after) as im:
            damaged=im.convert('RGBA');damaged.putpixel((40,25),(1,2,3,255));p=Path(folder)/'hud.png';damaged.save(p)
            with self.assertRaises((AssertionError,ValueError)):v.changed_pixels(before,p,row,1152)

    def test_noop_fence_rejected(self):
        row=next(r for r in self.data['rows'] if r['id']=='market-0-72');path=v.REPORT/'native/before/1152/market-0-72.png'
        with self.assertRaises((AssertionError,ValueError)):v.changed_pixels(path,path,row,1152)

    def test_focus_policy_cannot_claim_input_acceptance(self):
        self.data['rows'][0]['focus_required']=True;self.rejected(self.data)

if __name__=='__main__':unittest.main()
