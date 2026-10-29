#!/usr/bin/env python3
"""Negative controls operate on copies of genuine native fence evidence."""
import copy,tempfile,unittest,shutil
from unittest.mock import patch
from pathlib import Path
from PIL import Image
from tools.qa.world import village_board_verify as v

class BoardProofTests(unittest.TestCase):
    def setUp(self):
        """Load a real 1152px capture, not an invented optimistic fixture."""
        self.data=v.load(v.REPORT/'native/after/1152/capture.json')

    def rejected(self,data):
        """Require the acceptance gate to fail the damaged copy."""
        with self.assertRaises((AssertionError,ValueError)):v.metadata(data,1152,'after')

    def test_actual_evidence(self):
        self.assertEqual(len(v.metadata(self.data,1152,'after')),39)

    def test_lost_focus(self):
        self.data['rows'][0]['focused']=False;self.rejected(self.data)

    def test_different_physical_window(self):
        self.data['rows'][0]['window']=[2048,1152];self.rejected(self.data)

    def test_partial_phase(self):
        self.data['rows'].pop();self.rejected(self.data)

    def test_duplicate_case(self):
        self.data['rows'].append(copy.deepcopy(self.data['rows'][0]));self.rejected(self.data)

    def test_save_mutation(self):
        self.data['rows'][0]['after']['coins']+=1;self.rejected(self.data)

    def test_wrong_live_locale(self):
        row=next(r for r in self.data['rows'] if r['id']=='sign-right-en');row['locale']='ru';self.rejected(self.data)

    def test_wrong_camera_configuration(self):
        self.data['rows'][0]['normal_effects']=True;self.rejected(self.data)

    def test_hud_change_is_rejected(self):
        row=next(r for r in self.data['rows'] if r['id']=='board-648-0-62')
        before=v.REPORT/'native/before/1152/board-648-0-62.png';after=v.REPORT/'native/after/1152/board-648-0-62.png'
        with tempfile.TemporaryDirectory() as folder,Image.open(after) as im:
            damaged=im.convert('RGBA');damaged.putpixel((40,25),(1,2,3,255));p=Path(folder)/'hud.png';damaged.save(p)
            with self.assertRaises((AssertionError,ValueError)):v.changed_pixels(before,p,row,1152)

    def test_noop_fence_rejected(self):
        row=next(r for r in self.data['rows'] if r['id']=='board-648-0-62');path=v.REPORT/'native/before/1152/board-648-0-62.png'
        with self.assertRaises((AssertionError,ValueError)):v.changed_pixels(path,path,row,1152)

    def test_language_dependent_body_rejected(self):
        rows=v.metadata(self.data,1152,'after');row=rows['sign-right-en'];cx,cy=row['camera']
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder)
            for locale in v.LOCALES:shutil.copyfile(v.REPORT/'native/after/1152'/('sign-right-'+locale+'.png'),folder/('sign-right-'+locale+'.png'))
            p=folder/'sign-right-en.png'
            with Image.open(p) as im:
                damaged=im.convert('RGBA');damaged.putpixel((round((2232-cx)*1.2),round((648-20-cy)*1.2)),(1,2,3,255));damaged.save(p)
            with patch.object(v,'PORTS',{'right':(2232,672)}):
                with self.assertRaises((AssertionError,ValueError)):v.locale_bodies(folder,rows,1152)

if __name__=='__main__':unittest.main()
