#!/usr/bin/env python3
"""Reject damaged copies of actual lamp captures and authoring geometry."""
import copy,json,shutil,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from PIL import Image
import village_lamp_assets as assets
from village_lamp_verify import REPORT,load,metadata,changed_pixels,provenance,separated_glow

class VillageLampEvidenceTests(unittest.TestCase):
    """Native evidence is mandatory; corruption is confined to disposable copies."""
    @classmethod
    def setUpClass(cls):
        cls.path=REPORT/'native/after/1152';cls.data=load(cls.path/'capture.json')

    def test_complete_actual_views_in_both_windows(self):
        for width in [1152,1280]:
            for phase,count in [('before',17),('after',25)]:self.assertEqual(len(metadata(load(REPORT/'native'/phase/str(width)/'capture.json'),width,phase)),count)

    def test_fullscreen_override_cannot_pass_readback_only(self):
        data=copy.deepcopy(self.data);data['rows'][0]['window']=[3584,2240]
        with self.assertRaisesRegex(ValueError,'window'):metadata(data,1152,'after')

    def test_changed_save_or_focus_is_rejected(self):
        data=copy.deepcopy(self.data);data['rows'][0]['after']['coins']+=1
        with self.assertRaisesRegex(ValueError,'saved world'):metadata(data,1152,'after')
        data=copy.deepcopy(self.data);data['rows'][0]['focused']=False
        with self.assertRaises(ValueError):metadata(data,1152,'after')

    def test_missing_or_duplicated_camera_case_is_rejected(self):
        for duplicate in [False,True]:
            data=copy.deepcopy(self.data)
            if duplicate:data['rows'][-1]=data['rows'][0]
            else:data['rows'].pop()
            with self.assertRaisesRegex(ValueError,'coverage'):metadata(data,1152,'after')

    def test_actual_hud_pixel_corruption_is_rejected(self):
        name=self.data['rows'][0]['id'];row=self.data['rows'][0]
        with tempfile.TemporaryDirectory(prefix='lamp-pixel-') as tmp:
            target=Path(tmp)/'changed.png'
            with Image.open(self.path/(name+'.png')) as native:
                image=native.convert('RGBA');r,g,b,a=image.getpixel((0,0));image.putpixel((0,0),((r+1)%256,g,b,a));image.save(target)
            with self.assertRaisesRegex(ValueError,'outside lamp'):changed_pixels(REPORT/'native/before/1152'/(name+'.png'),target,row,1152)

    def test_noop_art_replacement_is_rejected(self):
        row=self.data['rows'][0];before=REPORT/'native/before/1152'/(row['id']+'.png')
        with self.assertRaisesRegex(ValueError,'visible change'):changed_pixels(before,before,row,1152)

    def test_removed_emitter_in_runtime_profile_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='lamp-contacts-') as tmp:
            root=Path(tmp);report=root/'docs/reports/visual-overhaul/vprop-004';runtime=root/'assets/game/locations/overworld/lamps'
            shutil.copytree(assets.REPORT/'masters',report/'masters');shutil.copyfile(assets.REPORT/'source.json',report/'source.json');shutil.copytree(assets.RUNTIME,runtime)
            profile=load(runtime/'profile.json');profile['views']['west'].pop('emitter');(runtime/'profile.json').write_text(json.dumps(profile))
            with patch.multiple(assets,ROOT=root,REPORT=report,RUNTIME=runtime):
                with self.assertRaises(AssertionError):assets.verify()

    def test_partial_native_phase_is_never_accepted(self):
        with tempfile.TemporaryDirectory(prefix='lamp-partial-') as tmp:
            folder=Path(tmp);source=load(REPORT/'native/after/source.json');source['complete']=False;(folder/'source.json').write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError,'incomplete'):provenance(folder,'after')

    def test_relabelled_historical_commit_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='lamp-git-base-') as tmp:
            folder=Path(tmp);shutil.copytree(REPORT/'native/before/inputs',folder/'inputs')
            source=load(REPORT/'native/before/source.json');source['base_commit']='91620aa716924555640557c541a455ca8e1afa2a';(folder/'source.json').write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError,'Git base'):provenance(folder,'before')

    def test_shifted_canonical_anchor_is_rejected(self):
        data=copy.deepcopy(self.data);data['rows'][0]['lamp_anchors'][0][0]+=24
        with self.assertRaisesRegex(ValueError,'canonical lamp anchor'):metadata(data,1152,'after')

    def test_wrong_night_clock_or_effect_mode_is_rejected(self):
        data=copy.deepcopy(self.data);row=next(r for r in data['rows'] if r['id']=='normal-night');row['darkness']=0
        with self.assertRaisesRegex(ValueError,'night control'):metadata(data,1152,'after')
        data=copy.deepcopy(self.data);row=next(r for r in data['rows'] if r['id']=='normal-day');row['normal_effects']=False
        with self.assertRaisesRegex(ValueError,'effect mode'):metadata(data,1152,'after')

    def test_corrupted_glow_profile_requires_new_derivatives(self):
        with tempfile.TemporaryDirectory(prefix='lamp-profile-') as tmp:
            root=Path(tmp);report=root/'docs/reports/visual-overhaul/vprop-004';runtime=root/'assets/game/locations/overworld/lamps'
            shutil.copytree(assets.REPORT/'masters',report/'masters');shutil.copyfile(assets.REPORT/'source.json',report/'source.json');shutil.copytree(assets.RUNTIME,runtime)
            profile=load(runtime/'profile.json');profile['glow']['alpha'][0]=0;(runtime/'profile.json').write_text(json.dumps(profile))
            with patch.multiple(assets,ROOT=root,REPORT=report,RUNTIME=runtime):
                with self.assertRaises(AssertionError):assets.verify()

    def test_pixel_outside_separate_glow_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='lamp-glow-') as tmp:
            folder=Path(tmp)
            for p in self.path.glob('gallery-*.png'):shutil.copyfile(p,folder/p.name)
            target=folder/'gallery-lit-dark.png'
            with Image.open(target) as original:
                image=original.convert('RGBA');r,g,b,a=image.getpixel((0,0));image.putpixel((0,0),((r+1)%256,g,b,a));image.save(target)
            with self.assertRaisesRegex(ValueError,'outside separate glow'):separated_glow(folder,1152)

if __name__=='__main__':unittest.main()
