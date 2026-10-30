#!/usr/bin/env python3
"""Corrupt copies of real native evidence; never change the accepted archive."""
import copy,json,unittest
from tools.qa.foliage import foliage_speed_verify as audit

class SpeedEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder=audit.REPORT/'native/1152';cls.data=json.loads((cls.folder/'capture.json').read_text());cls.shader=json.loads((audit.REPORT/'native/source.json').read_text())['sources']['scripts/presentation/foliage_wind.gdshader']
    def reject(self,change):
        d=copy.deepcopy(self.data);change(d)
        with self.assertRaises((ValueError,KeyError,IndexError,ZeroDivisionError)):audit.metadata(d,1152,self.shader)
    def row(self,d,name):return next(r for r in d['rows'] if r['id']==name)
    def test_accepted(self):self.assertEqual(len(audit.metadata(self.data,1152,self.shader)),100)
    def test_headless(self):self.reject(lambda d:d.update(display='headless'))
    def test_false_fps(self):self.reject(lambda d:d.update(performance_eligible=True))
    def test_false_hardware(self):self.reject(lambda d:d.update(hardware_input_accepted=True))
    def test_missing_case(self):self.reject(lambda d:d['rows'].pop())
    def test_hidden(self):self.reject(lambda d:d['rows'][0].update(visible=False))
    def test_camera(self):self.reject(lambda d:d['rows'][0].update(camera=[1,2]))
    def test_background_camera(self):self.reject(lambda d:d['rows'][0]['background'].update(position=[0,0]))
    def test_root(self):self.reject(lambda d:d['anchors'][6].__setitem__(0,1900))
    def test_requested_velocity(self):self.reject(lambda d:d['rows'][0]['motion'].update(velocity=[210,0]))
    def test_zero_delta(self):self.reject(lambda d:d['rows'][0]['motion'].update(delta=0))
    def test_wrong_origin(self):self.reject(lambda d:d['rows'][0]['trace']['origin'].__setitem__(0,1900))
    def test_mutable_record(self):self.reject(lambda d:d['rows'][0]['motion'].update(immutable=False))
    def test_hitstop_outer_delta(self):self.reject(lambda d:self.row(d,'hitstop-half')['motion'].update(delta=1/60))
    def test_wrong_gpu_slot(self):self.reject(lambda d:d['rows'][0]['variants'][0]['callbacks'][0].update(slots=[0,1]))
    def test_wrong_shader(self):self.reject(lambda d:d['rows'][0]['variants'][0]['callbacks'][0].update(shader_sha='0'*64))
    def test_stale_gpu_buffer(self):self.reject(lambda d:d['rows'][0]['variants'][0]['callbacks'][0]['contacts'][6].__setitem__(0,0))
    def test_nonfinite(self):self.reject(lambda d:d['rows'][0]['motion']['velocity'].__setitem__(0,float('nan')))
    def test_changed_save(self):self.reject(lambda d:d['rows'][0]['variants'][0].update(after_sha='0'*64))
    def test_missing_callback(self):self.reject(lambda d:d['rows'][0]['variants'][0]['draws'].pop())
    def test_growing_geometry(self):self.reject(lambda d:d['rows'][0]['variants'][0]['stats'].update(builds=2))
    def test_fake_wall(self):self.reject(lambda d:self.row(d,'wall')['trace'].update(held=[False,False,False,False]))
    def test_retained_stop_boost(self):self.reject(lambda d:self.row(d,'stop')['variants'][0].update(gain=1.9))
    def test_pause_clock(self):self.reject(lambda d:self.row(d,'pause-0').update(seconds=13))
    def test_wrong_interpolation(self):self.reject(lambda d:self.row(d,'interpolated-75').update(presented=self.row(d,'interpolated-25')['presented']))
    def test_fake_transfer(self):self.reject(lambda d:self.row(d,'teleport-overworld').update(teleport_success=False))
    def test_actual_no_effect(self):
        off=audit.image(self.folder/'rate-30-0-273/off.png')
        with self.assertRaisesRegex(ValueError,'visibly affect'):audit.pair(off,off,off,2)
    def test_actual_moving_root(self):
        source=audit.image(self.folder/'center-70/on.png');wrong=source.copy();p=wrong.getpixel((90,165));wrong.putpixel((90,165),((p[0]+1)%256,*p[1:]))
        with self.assertRaisesRegex(ValueError,'root/lower'):audit.locked_bands(wrong,source)
    def test_wrong_gpu_pixel(self):
        source=audit.image(self.folder/'center-70/on.png');wrong=source.copy();wrong.putpixel((90,80),(255,0,255,255))
        with self.assertRaisesRegex(ValueError,'GPU/CPU'):audit.pair(wrong,source,source,0)

if __name__=='__main__':unittest.main()
