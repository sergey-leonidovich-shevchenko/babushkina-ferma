#!/usr/bin/env python3
"""Mutate only copies of actual evidence; enforce native contact and failure detection."""
import copy,json,unittest
from tools.qa.foliage import foliage_contact_verify as audit

class ContactEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder=audit.REPORT/'native/1152';cls.data=json.loads((cls.folder/'capture.json').read_text());cls.shader=json.loads((audit.REPORT/'native/source.json').read_text())['sources']['scripts/presentation/foliage_wind.gdshader']
    def reject(self,change):
        data=copy.deepcopy(self.data);change(data)
        with self.assertRaises((ValueError,KeyError,IndexError)):audit.metadata(data,1152,self.shader)
    def test_accepted(self):self.assertEqual(len(audit.metadata(self.data,1152,self.shader)),89)
    def test_headless(self):self.reject(lambda d:d.update(display='headless'))
    def test_false_hardware(self):self.reject(lambda d:d.update(hardware_input_accepted=True))
    def test_false_fps(self):self.reject(lambda d:d.update(performance_eligible=True))
    def test_incomplete(self):self.reject(lambda d:d['rows'].pop())
    def test_hidden(self):self.reject(lambda d:d['rows'][0].update(visible=False))
    def test_wrong_root(self):self.reject(lambda d:d['anchors'][6].__setitem__(0,1900))
    def test_wrong_gpu_index(self):self.reject(lambda d:d['rows'][0]['variants'][0]['callbacks'][1].update(slots=[0,1]))
    def test_wrong_shader(self):self.reject(lambda d:d['rows'][0]['variants'][0]['callbacks'][0].update(shader_sha='0'*64))
    def test_wrong_save(self):self.reject(lambda d:d['rows'][0]['variants'][0].update(after_sha='0'*64))
    def test_missing_draw(self):self.reject(lambda d:d['rows'][0]['variants'][0]['draws'].pop())
    def test_reallocation(self):self.reject(lambda d:d['rows'][0]['variants'][0]['stats'].update(builds=2))
    def test_nonfinite(self):self.reject(lambda d:d['rows'][0]['variants'][0]['callbacks'][0]['contacts'][6].__setitem__(0,float('nan')))
    def test_pointing_toward_hero(self):self.reject(lambda d:d['rows'][4]['expected'][6].__setitem__(0,-2))
    def test_pause_clock(self):self.reject(lambda d:next(r for r in d['rows'] if r['id']=='pause-0').update(seconds=200))
    def test_physical_instead_of_presented(self):self.reject(lambda d:next(r for r in d['rows'] if r['id']=='interpolated-25').update(presented=next(r for r in d['rows'] if r['id']=='interpolated-25')['player']))
    def test_fake_transfer(self):self.reject(lambda d:next(r for r in d['rows'] if r['id']=='teleport-overworld').update(teleport_success=False))
    def test_actual_no_effect_shader(self):
        off=audit.image(self.folder/'sweep-0-04/off.png')
        with self.assertRaisesRegex(ValueError,'visibly affect'):audit.pair(off,off,off,2.0)
    def test_actual_moving_root(self):
        source=audit.image(self.folder/'center/on.png');changed=source.copy();pixel=changed.getpixel((90,165));changed.putpixel((90,165),((pixel[0]+1)%256,*pixel[1:]))
        with self.assertRaisesRegex(ValueError,'root/lower'):audit.locked_bands(changed,source)
    def test_wrong_gpu_pixel(self):
        source=audit.image(self.folder/'center/on.png');wrong=source.copy();wrong.putpixel((90,80),(255,0,255,255))
        with self.assertRaisesRegex(ValueError,'GPU/CPU'):audit.pair(wrong,source,None,0)

if __name__=='__main__':unittest.main()
