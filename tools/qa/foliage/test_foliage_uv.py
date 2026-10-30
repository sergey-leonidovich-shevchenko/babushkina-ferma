#!/usr/bin/env python3
"""Corrupt copies of actual GPU evidence; accepted native files remain untouched."""
import copy, shutil, tempfile, unittest
from pathlib import Path
from PIL import Image
from tools.qa.foliage import foliage_uv_verify as V

class UVEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder=V.REPORT/'native';cls.data=V.load(cls.folder/'1152/capture.json')
        cls.base=V.load(cls.folder/'source.json')['base_commit']
        cls.definitions=V.passport(V.blob(cls.base,'scripts/presentation/foliage_root_profile.gd').decode())
        cls.shader=(cls.folder/'inputs'/V.RUNTIME[1]).read_text()

    def mutated(self):return copy.deepcopy(self.data)
    def reject(self,data):
        with self.assertRaises((ValueError,KeyError)):V.records(data,1152,self.definitions,self.shader)

    def test_actual_gpu_evidence(self):
        result=V.verify();self.assertEqual(result['positive_gpu_triplets'],156);self.assertEqual(result['quad_callbacks'],960)

    def test_missing_case(self):
        data=self.mutated();data['rows'].pop();self.reject(data)

    def test_duplicate_case(self):
        data=self.mutated();data['rows'][1]=data['rows'][0];self.reject(data)

    def test_wrong_projection(self):
        data=self.mutated();data['rows'][0]['projection']=[1,1];self.reject(data)

    def test_wrong_physical_window(self):
        data=self.mutated();data['rows'][0]['window']=[1920,1080];self.reject(data)

    def test_hidden_window(self):
        data=self.mutated();data['rows'][0]['visible']=False;self.reject(data)

    def test_hardware_or_performance_claim(self):
        data=self.mutated();data['hardware_input_accepted']=True;self.reject(data)
        data=self.mutated();data['performance_eligible']=True;self.reject(data)

    def test_wrong_source_rectangle(self):
        data=self.mutated();data['rows'][0]['uniforms'][0][0]['region'][0]+=362;self.reject(data)

    def test_sampler_must_exist_on_gpu(self):
        data=self.mutated();data['rows'][0]['uniforms'][0][0]['source_valid']=False;self.reject(data)

    def test_own_shader_is_observed(self):
        data=self.mutated();data['rows'][0]['uniforms'][0][0]['shader_sha']='0'*64;self.reject(data)

    def test_duplicate_quad_draw(self):
        data=self.mutated();row=data['rows'][0]['uniforms'][0];row[1]['frame']=row[0]['frame'];self.reject(data)

    def test_ownership_must_return_to_zero(self):
        data=self.mutated();data['rows'][0]['active_after']=[1,0,0];self.reject(data)

    def test_full_gameplay_witness(self):
        data=self.mutated();data['snapshot_text']+=' ';self.reject(data)

    def test_draw_cannot_change_saved_state(self):
        data=self.mutated();data['rows'][0]['game_draws'][0]['after_sha']='0'*64;self.reject(data)

    def test_independent_reflection_is_geometric(self):
        data=self.mutated();row=next(r for r in data['rows'] if r['flip']);row['uniforms'][2][0]['scale']=[1,1];self.reject(data)

    def test_reflection_cannot_invert_vertical_mesh(self):
        data=self.mutated();data['rows'][0]['vertices'][0][1]*=-1;self.reject(data)

    def test_root_lock_cannot_change(self):
        data=self.mutated();data['rows'][0]['uniforms'][0][0]['lock_v']=0;self.reject(data)

    def test_unfocused_static_data_are_not_hardware_acceptance(self):
        data=self.mutated()
        for row in data['rows']:row['focused']=False
        V.records(data,1152,self.definitions,self.shader)
        data['rows'][0]['focused']='unknown';self.reject(data)

    def test_corrupt_gpu_pixel_is_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);shutil.copytree(self.folder/'1152/pairs',folder/'pairs')
            path=folder/'pairs/grass-0-0/atlas.png'
            with Image.open(path) as original:im=original.convert('RGBA')
            im.putpixel((0,0),(255,0,255,255));im.save(path)
            with self.assertRaises(ValueError):V.pixels(folder,{r['id']:r for r in self.data['rows']},self.definitions)

    def test_negative_control_must_actually_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);shutil.copytree(self.folder/'1152/pairs',folder/'pairs')
            target=folder/'pairs/grass-0-8-unsafe';shutil.copyfile(target/'isolated.png',target/'atlas.png')
            with self.assertRaises(ValueError):V.pixels(folder,{r['id']:r for r in self.data['rows']},self.definitions)

    def test_archived_runtime_source_is_immutable(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)/'native';shutil.copytree(self.folder,folder)
            path=folder/'inputs'/V.RUNTIME[1];path.write_text(path.read_text()+'\n// changed\n')
            with self.assertRaises(ValueError):V.verify(folder)

if __name__=='__main__':unittest.main()
