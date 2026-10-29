#!/usr/bin/env python3
"""Check explicit schema fixtures and the separately recorded native replay evidence."""
import copy
import gzip
import json
import shutil
import tempfile
import unittest
from common.git import git_environment
from pathlib import Path
from PIL import Image
from object_command_verify import CASES,PROBES,FALLBACK,metadata,probe_draws,equal,provenance,legacy_body,ROOT,REPORT,load


def fixture():
    """A minimal parser fixture intentionally contains no native images, hashes or acceptance record."""
    rows=[]
    for name in CASES:
        saved={'hp':100,'inventory':{'wood':3}}
        rows.append({'id':name,'focused':True,'window':[1152,648],'readback':[1152,648],'visible':[1152,648],'draws':4,
            'zoom':1 if name=='interior' else 1.2,'snapshot_before':saved,'snapshot_after':copy.deepcopy(saved),'root_material_null':True,
            'background_material_null':True,'terrain_material_null':True,'pause':name=='manual-pause','storage':name=='opaque-storage',
            'location':'cottage_interior' if name=='interior' else 'overworld','tree_alpha':0.34 if name=='tree-behind' else 1})
    probes=[]
    for name in PROBES:
        width={'south':317,'west':229,'east':221}.get(name,317)
        packet={'version':1,'space':'world','world':'overworld','layer':'behind_actors','anchor':[128.25,176.5],'local_uv':[0,0,1,1],
            'bounds':[0,0,96,66],'source':[0,0,width,218],'texture_path':'res://assets/game/schema-fixture.png','material_id':1 if name=='shader' else 0,
            'modulate':[1,1,1,0.34 if name=='translucent' else 1]}
        probes.append({'id':name,'packet':packet,'draws':[4,4],'expected':'fallback' if name in FALLBACK else 'command'})
    return {'task':'VRENDER-004','errors':[],'display_server':'schema-fixture-only','simulation_frozen':True,'performance_eligible':False,
        'gpu_time_ms':None,'production_pass_enabled':False,'requested_size':[1152,648],'probe_size':[256,224],'cases':rows,'probes':probes}


def witnesses(packet,mode='command',expected='fallback'):
    """Synthetic draw witnesses test validator logic and are never persisted as a native dataset."""
    return [{'frame':i,'before':{'hp':100},'after':{'hp':100},'own_material_equal':True,'parent_material_equal':True,'transform_equal':True,
        'packet':packet,'result':'legacy' if mode=='legacy' else expected,'fallback_calls':1 if mode=='command' and expected=='fallback' else 0} for i in range(4)]


class ObjectCommandEvidenceTests(unittest.TestCase):
    """A permissive schema must not turn missing native evidence into a green acceptance."""
    def test_schema_fixture_accepts_complete_shapes(self):
        rows,probes=metadata(fixture(),1152);self.assertEqual((len(rows),len(probes)),(9,11))

    def test_false_live_pass_or_fps_claim_rejected(self):
        for key,value in [('production_pass_enabled',True),('performance_eligible',True),('gpu_time_ms',1)]:
            data=fixture();data[key]=value
            with self.assertRaises(ValueError):metadata(data,1152)

    def test_missing_native_case_or_wrong_focus_rejected(self):
        data=fixture();data['cases'].pop()
        with self.assertRaises(ValueError):metadata(data,1152)
        data=fixture();data['cases'][0]['focused']=False
        with self.assertRaises(ValueError):metadata(data,1152)

    def test_changed_save_and_material_leak_rejected(self):
        data=fixture();data['cases'][0]['snapshot_after']['inventory']['wood']+=1
        with self.assertRaisesRegex(ValueError,'saved gameplay'):metadata(data,1152)
        data=fixture();data['cases'][0]['root_material_null']=False
        with self.assertRaisesRegex(ValueError,'leaked'):metadata(data,1152)

    def test_atlas_uv_or_reused_direction_rejected(self):
        data=fixture();data['probes'][0]['packet']['local_uv']=[0.1,0,0.2,1]
        with self.assertRaises(ValueError):metadata(data,1152)
        data=fixture()
        for probe in data['probes'][:3]:probe['packet']['source']=[0,0,10,10]
        with self.assertRaises(ValueError):metadata(data,1152)

    def test_one_fallback_per_genuine_callback(self):
        packet=fixture()['probes'][0]['packet'];draws=witnesses(packet);probe_draws(draws,'command','fallback',packet)
        draws[0]['fallback_calls']=2
        with self.assertRaisesRegex(ValueError,'duplicate fallback'):probe_draws(draws,'command','fallback',packet)

    def test_missing_callback_or_changed_transform_rejected(self):
        packet=fixture()['probes'][0]['packet'];draws=witnesses(packet);draws[1]['transform_equal']=False
        with self.assertRaises(ValueError):probe_draws(draws,'command','fallback',packet)
        with self.assertRaises(ValueError):probe_draws(draws[:3],'command','fallback',packet)

    def test_hidden_rgba_change_rejected(self):
        with tempfile.TemporaryDirectory(prefix='object-command-pixels-') as tmp:
            a,b=Path(tmp)/'a.png',Path(tmp)/'b.png';image=Image.new('RGBA',(4,4),(5,6,7,0));image.save(a);image.save(b);equal(a,b)
            image.putpixel((0,0),(6,6,7,0));image.save(b)
            with self.assertRaises(ValueError):equal(a,b)

    def test_incomplete_archive_never_accepted(self):
        with tempfile.TemporaryDirectory(prefix='object-command-source-') as tmp:
            folder=Path(tmp);(folder/'source.json').write_text('{"complete":false}')
            with self.assertRaisesRegex(ValueError,'incomplete'):provenance(folder)

    def test_production_legacy_draw_is_preserved(self):
        import subprocess
        name='scripts/presentation/world_workbench_visual_system.gd'
        old=subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT,text=True, env=git_environment())
        self.assertEqual(legacy_body(old),legacy_body((ROOT/name).read_text()))


class RecordedObjectCommandTests(unittest.TestCase):
    """Actual archived captures must survive validation and reject temporary corruptions."""
    def test_two_recorded_windows_have_complete_native_cases(self):
        for width in [1152,1280]:
            data=load(REPORT/'native'/str(width)/'capture.json')
            rows,probes=metadata(data,width)
            self.assertEqual((len(rows),len(probes)),(9,11))
            self.assertNotEqual(data['display_server'],'headless')

    def test_real_fallbacks_are_atomic_and_reject_a_duplicate(self):
        path=REPORT/'native/1152';_,probes=metadata(load(path/'capture.json'),1152)
        for name in FALLBACK:
            draws=json.loads(gzip.decompress((path/('probe-'+name+'-command-draws.json.gz')).read_bytes()))
            probe_draws(draws,'command','fallback',probes[name]['packet'])
            draws[0]['fallback_calls']+=1
            with self.assertRaisesRegex(ValueError,'duplicate fallback'):probe_draws(draws,'command','fallback',probes[name]['packet'])

    def test_real_shader_callbacks_reject_save_mutation(self):
        path=REPORT/'native/1280';_,probes=metadata(load(path/'capture.json'),1280)
        draws=json.loads(gzip.decompress((path/'probe-shader-command-draws.json.gz').read_bytes()))
        probe_draws(draws,'command','command',probes['shader']['packet'])
        draws[0]['after']['coins']+=1
        with self.assertRaisesRegex(ValueError,'mutated gameplay'):probe_draws(draws,'command','command',probes['shader']['packet'])

    def test_archived_runtime_tampering_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='object-command-archive-') as tmp:
            folder=Path(tmp)/'native';shutil.copytree(REPORT/'native',folder)
            target=folder/'inputs/scripts/presentation/object_draw_replay.gd'
            target.write_text(target.read_text()+'\n# temporary corruption\n')
            with self.assertRaisesRegex(ValueError,'archived source changed'):provenance(folder)

    def test_actual_png_pixel_tampering_is_rejected(self):
        source=REPORT/'native/1152/probe-source-region-command.png'
        with tempfile.TemporaryDirectory(prefix='object-command-native-pixel-') as tmp:
            target=Path(tmp)/'changed.png'
            with Image.open(source) as native:
                image=native.convert('RGBA');r,g,b,a=image.getpixel((0,0));image.putpixel((0,0),((r+1)%256,g,b,a));image.save(target)
            with self.assertRaisesRegex(ValueError,'pixel equality'):equal(source,target)


if __name__=='__main__':unittest.main()
