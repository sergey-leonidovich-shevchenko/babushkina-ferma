#!/usr/bin/env python3
"""Negative controls for real native wind evidence; never modify accepted files."""
import copy,json,tempfile,unittest
from pathlib import Path
from PIL import Image
import foliage_wind_verify as audit

class WindEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder=audit.REPORT/'native/1152';cls.data=json.loads((cls.folder/'capture.json').read_text())
        cls.shader=json.loads((audit.REPORT/'native/source.json').read_text())['sources']['scripts/presentation/foliage_wind.gdshader']

    def reject(self,change):
        data=copy.deepcopy(self.data);change(data)
        with self.assertRaises((ValueError,KeyError,IndexError)):audit.metadata(data,1152,self.shader)

    def test_accepted_native_records(self):
        self.assertEqual(len(audit.metadata(self.data,1152,self.shader)),68)

    def test_missing_sample(self):self.reject(lambda d:d['rows'].pop(5))
    def test_duplicate_case(self):self.reject(lambda d:d['rows'][1].update(id='wind-00'))
    def test_headless(self):self.reject(lambda d:d.update(display='headless'))
    def test_hidden_window(self):self.reject(lambda d:d['rows'][2].update(visible=False))
    def test_false_hardware_claim(self):self.reject(lambda d:d.update(hardware_input_accepted=True))
    def test_false_fps_claim(self):self.reject(lambda d:d.update(performance_eligible=True))
    def test_changed_save(self):self.reject(lambda d:d['rows'][1].update(after_sha='0'*64))
    def test_removed_game_draw(self):self.reject(lambda d:d['rows'][1]['draws'].pop())
    def test_wrong_shader(self):self.reject(lambda d:d['rows'][1]['callbacks'][0].update(shader_sha='0'*64))
    def test_all_roots_same_phase(self):self.reject(lambda d:d['rows'][1]['callbacks'][0].update(phases=[0]*6))
    def test_rebuilt_group(self):self.reject(lambda d:d['rows'][1]['stats'].update(builds=2))
    def test_changed_material_owner(self):self.reject(lambda d:d['rows'][1]['callbacks'][0].update(material_rid='RID(0)'))
    def test_pause_clock_debt(self):self.reject(lambda d:next(r for r in d['rows'] if r['id']=='pause-1').update(seconds=9))
    def test_offscreen_still_active(self):self.reject(lambda d:next(r for r in d['rows'] if r['id']=='offscreen')['stats'].update(active=5))
    def test_return_forgets_cancelled_frame(self):self.reject(lambda d:next(r for r in d['rows'] if r['id']=='return').update(target_update_request=0))
    def test_fake_approach(self):self.reject(lambda d:next(r for r in d['rows'] if r['id'].startswith('approach-'))['movement'].update(after=next(r for r in d['rows'] if r['id'].startswith('approach-'))['movement']['before']))
    def test_fake_teleport(self):self.reject(lambda d:next(r for r in d['rows'] if r['id']=='teleport-forest').update(teleport_success=False))

    def test_real_root_pixel_mutation(self):
        original=audit.image(self.folder/'wind-00/atlas.png');changed=original.copy()
        point=(90,165);pixel=changed.getpixel(point);changed.putpixel(point,((pixel[0]+1)%256,*pixel[1:]))
        with self.assertRaisesRegex(ValueError,'root/lower strip moved'):audit.locked_bands(changed,original)
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);p=folder/'original.png';original.save(p);entries={'original.png':audit.sha(p)};audit.artifacts(folder,entries)
            changed.save(p)
            with self.assertRaisesRegex(ValueError,'native artifact'):audit.artifacts(folder,entries)
            with self.assertRaisesRegex(ValueError,'coverage'):audit.artifacts(folder,{})

if __name__=='__main__':unittest.main()
