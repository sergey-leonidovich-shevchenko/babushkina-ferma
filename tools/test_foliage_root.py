#!/usr/bin/env python3
"""Negative controls corrupt temporary native evidence, never accepted originals."""
import copy,json,shutil,tempfile,unittest
from unittest.mock import patch
from pathlib import Path
from PIL import Image
import foliage_root_verify as V

class RootEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder=V.REPORT/'native';cls.data=V.load(cls.folder/'1152/capture.json')
        cls.definitions=V.passport((cls.folder/'inputs'/V.RUNTIME[0]).read_text())

    def mutated(self):return copy.deepcopy(self.data)
    def reject(self,data):
        with self.assertRaises((ValueError,KeyError)):V.frames(data,1152)

    def test_actual_complete_evidence(self):
        original=Image.open;current_art={str(V.ROOT/name) for name in V.ART}
        def immutable_only(path,*args,**kwargs):
            if isinstance(path,(str,Path)) and str(path) in current_art:raise AssertionError('historical proof read mutable current artwork')
            return original(path,*args,**kwargs)
        with patch.object(V.Image,'open',side_effect=immutable_only):result=V.verify()
        self.assertEqual(result['rgba_pairs'],20);self.assertEqual(result['game_draw_callbacks'],96)

    def test_missing_row(self):
        data=self.mutated();data['rows'].pop();self.reject(data)

    def test_duplicate_row(self):
        data=self.mutated();data['rows'][1]=data['rows'][0];self.reject(data)

    def test_wrong_physical_window(self):
        data=self.mutated();data['rows'][0]['window']=[1920,1080];self.reject(data)

    def test_hidden_window(self):
        data=self.mutated();data['rows'][0]['visible']=False;self.reject(data)

    def test_focus_is_recorded_not_fabricated(self):
        data=self.mutated()
        for row in data['rows']:row['focused']=False
        V.frames(data,1152)
        data['rows'][0]['focused']='unknown';self.reject(data)

    def test_static_protocol_cannot_accept_hardware_input(self):
        data=self.mutated();data['hardware_input_accepted']=True;self.reject(data)

    def test_changed_gameplay(self):
        data=self.mutated();data['rows'][0]['after']['coins']+=1;self.reject(data)

    def test_duplicate_draw_callback(self):
        data=self.mutated();row=data['rows'][0];row['draws'][1]['process_frame']=row['draws'][0]['process_frame'];self.reject(data)

    def test_missing_board_callback(self):
        data=self.mutated();data['rows'][0]['board_frames'].pop();self.reject(data)

    def test_root_query_changed_state(self):
        data=self.mutated();next(r for r in data['rows'] if r['id']=='west-roots')['roots'][0]['pure']=False;self.reject(data)

    def test_root_projection_is_actual(self):
        data=self.mutated();next(r for r in data['rows'] if r['id']=='west-roots')['roots'][0]['anchors'][0]['world'][1]+=2;self.reject(data)

    def test_root_coverage_cannot_repeat_one_kind(self):
        data=self.mutated();row=next(r for r in data['rows'] if r['id']=='west-roots');row['roots'][0]['anchors'][0]=row['roots'][0]['anchors'][1];self.reject(data)

    def test_approach_must_move(self):
        data=self.mutated();row=next(r for r in data['rows'] if r['id']=='west-plain');row['motion']['positions']=[row['motion']['start']]*12;self.reject(data)

    def test_pause_must_hold_position(self):
        data=self.mutated();row=next(r for r in data['rows'] if r['id']=='pause-plain');row['motion']['positions'][-1][0]+=1;self.reject(data)

    def test_same_camera_pair(self):
        data=self.mutated();next(r for r in data['rows'] if r['id']=='west-roots')['camera'][0]+=1;self.reject(data)

    def corrupt_mask(self,kind,point):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);shutil.copytree(self.folder/'1152/masks',folder/'masks')
            path=folder/'masks'/(kind+'.png');im=Image.open(path).convert('L');im.putpixel(point,255);im.save(path)
            entries=copy.deepcopy(self.data['profiles']);next(e for e in entries if e['kind']==kind)['mask_sha256']=V.sha(path)
            with self.assertRaises(ValueError):V.check_masks(folder,entries,self.definitions)

    def test_transparent_padding_cannot_bend(self):self.corrupt_mask('grass',(0,0))
    def test_root_cannot_bend(self):self.corrupt_mask('grass',(178,325))
    def test_rigid_decor_cannot_bend(self):self.corrupt_mask('mossy_stone',(180,280))

    def test_every_profile_is_required(self):
        entries=copy.deepcopy(self.data['profiles']);entries.pop()
        with self.assertRaises(ValueError):V.check_masks(self.folder/'1152',entries,self.definitions)

    def test_exact_pixels_cannot_change(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'changed.png';im=Image.open(self.folder/'1152/west-roots.png').convert('RGBA');p=im.getpixel((0,0));im.putpixel((0,0),((p[0]+1)%256,*p[1:]));im.save(path)
            with self.assertRaises(ValueError):V.same_pixels(self.folder/'1152/west-plain.png',path,(1152,648))

    def test_archived_source_is_immutable(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)/'native';shutil.copytree(self.folder,folder)
            path=folder/'inputs'/V.RUNTIME[0];path.write_text(path.read_text()+'\n# changed\n')
            with self.assertRaises(ValueError):V.verify(folder)

if __name__=='__main__':unittest.main()
