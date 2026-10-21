#!/usr/bin/env python3
"""Reject incomplete or misleading seasonal acceptance records using temporary copies."""
import copy
import shutil
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from ground_seasons_verify import REPORT, load, metadata, geometry_and_retention, pixels, provenance


class GroundSeasonsEvidenceTests(unittest.TestCase):
    """A colour change must not conceal lost geometry, saves or GPU retention."""
    @classmethod
    def setUpClass(cls):
        cls.folder=REPORT/'native/1152';cls.capture=load(cls.folder/'capture.json');cls.retained=load(cls.folder/'retained.json')

    def test_complete_views_calendar_and_retention(self):
        self.assertEqual(len(metadata(self.capture,1152)),38)
        self.assertEqual(len(geometry_and_retention(self.capture,self.retained)),5)

    def test_wrong_window_performance_and_fixture_claim_rejected(self):
        for key,value in [('window',[1280,720]),('performance_eligible',True),('gpu_time_ms',1),('plot_water_fixed_by_fixture',False)]:
            data=copy.deepcopy(self.capture);data[key]=value
            with self.assertRaises(ValueError):metadata(data,1152)

    def test_missing_or_duplicated_view_rejected(self):
        for duplicate in [False,True]:
            data=copy.deepcopy(self.capture)
            if duplicate:data['rows'][-1]=data['rows'][0]
            else:data['rows'].pop()
            with self.assertRaises(ValueError):metadata(data,1152)

    def test_changed_inventory_camera_or_weather_rejected(self):
        for key,value in [('camera',[0,0]),('weather','snow'),('reference',False),('focused',False)]:
            data=copy.deepcopy(self.capture);data['rows'][7][key]=value
            with self.assertRaises(ValueError):metadata(data,1152)
        data=copy.deepcopy(self.capture);data['rows'][7]['snapshot']['coins']+=1
        with self.assertRaisesRegex(ValueError,'saved field'):metadata(data,1152)

    def test_mesh_alpha_identity_or_route_change_rejected(self):
        for field in ['mesh_hashes','mesh_ids']:
            data=copy.deepcopy(self.capture);data['climates'][1]['geometry'][field]['meadow']='changed'
            with self.assertRaises(ValueError):geometry_and_retention(data,self.retained)
        for field in ['rules','motions']:
            data=copy.deepcopy(self.capture);data['climates'][1]['navigation'][field][0]=[]
            with self.assertRaises(ValueError):geometry_and_retention(data,self.retained)

    def test_rebuild_on_repeated_climate_rejected(self):
        data=copy.deepcopy(self.capture);data['climates'][0]['idempotent_after']['paints']+=1
        with self.assertRaisesRegex(ValueError,'repeated climate'):geometry_and_retention(data,self.retained)

    def test_extra_gpu_target_rejected(self):
        data=copy.deepcopy(self.capture);data['rows'][7]['metrics']['target_id']+=1
        with self.assertRaisesRegex(ValueError,'recreated'):metadata(data,1152)

    def test_idle_repaint_or_pause_save_change_rejected(self):
        for field in ['after','save_after']:
            retained=copy.deepcopy(self.retained)
            if field=='after':retained[field]['paints']+=1
            else:retained[field]['coins']+=1
            with self.assertRaisesRegex(ValueError,'idle/pause'):geometry_and_retention(self.capture,retained)

    def test_incomplete_native_source_rejected(self):
        with tempfile.TemporaryDirectory(prefix='ground-seasons-source-') as tmp:
            folder=Path(tmp);source=load(REPORT/'native/source.json');source['complete']=False
            import json
            (folder/'source.json').write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError,'incomplete'):provenance(folder)

    def test_changed_alpha_even_at_transparent_pixel_rejected(self):
        with tempfile.TemporaryDirectory(prefix='ground-seasons-alpha-') as tmp:
            folder=Path(tmp)
            for name in ['spring','summer','autumn','winter','wet']:shutil.copyfile(self.folder/(name+'-cache.png'),folder/(name+'-cache.png'))
            image=Image.open(folder/'winter-cache.png').convert('RGBA');pixel=image.getpixel((12,12))
            image.putpixel((12,12),(*pixel[:3],(pixel[3]+1)%256));image.save(folder/'winter-cache.png')
            with self.assertRaisesRegex(ValueError,'alpha coverage'):pixels(folder)

    def test_noop_season_or_false_spring_return_rejected(self):
        for broken in ['summer-cache.png','spring-return-cache.png']:
            with tempfile.TemporaryDirectory(prefix='ground-seasons-pixels-') as tmp:
                folder=Path(tmp)
                for path in self.folder.glob('*.png'):shutil.copyfile(path,folder/path.name)
                if broken=='summer-cache.png':shutil.copyfile(folder/'spring-cache.png',folder/broken)
                else:
                    image=Image.open(folder/broken).convert('RGBA');image.putpixel((12,12),(1,2,3,4));image.save(folder/broken)
                with self.assertRaises(ValueError):pixels(folder)


if __name__=='__main__':unittest.main()
