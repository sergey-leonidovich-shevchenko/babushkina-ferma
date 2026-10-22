#!/usr/bin/env python3
"""Reject corrupted copies of real recovery evidence, leaving the accepted archive untouched."""
import copy,json,unittest
import foliage_recovery_verify as audit

class RecoveryEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder=audit.REPORT/'native/1152';cls.data=json.loads((cls.folder/'capture.json').read_text());cls.shader=json.loads((audit.REPORT/'native/source.json').read_text())['sources']['scripts/presentation/foliage_wind.gdshader']
    def reject(self,change):
        data=copy.deepcopy(self.data);change(data)
        with self.assertRaises((ValueError,KeyError,IndexError,ZeroDivisionError)):audit.metadata(data,1152,self.shader)
    def row(self,data,name):return next(row for row in data['rows'] if row['id']==name)
    def test_accepted(self):self.assertEqual(len(audit.metadata(self.data,1152,self.shader)),59)
    def test_headless(self):self.reject(lambda d:d.update(display='headless'))
    def test_false_fps(self):self.reject(lambda d:d.update(performance_eligible=True))
    def test_false_hardware(self):self.reject(lambda d:d.update(hardware_input_accepted=True))
    def test_missing_case(self):self.reject(lambda d:d['rows'].pop())
    def test_hidden_window(self):self.reject(lambda d:d['rows'][0].update(visible=False))
    def test_camera(self):self.reject(lambda d:d['rows'][0].update(camera=[1,2]))
    def test_background(self):self.reject(lambda d:d['rows'][0]['background'].update(position=[0,0]))
    def test_root(self):self.reject(lambda d:d['anchors'][6].__setitem__(0,1900))
    def test_missing_intermediate_tick(self):self.reject(lambda d:d['audit'].pop(20))
    def test_false_target(self):self.reject(lambda d:d['audit'][20]['raw'][6].__setitem__(0,99))
    def test_overshoot(self):self.reject(lambda d:d['audit'][20]['actual'][6].__setitem__(0,100))
    def test_wrong_tau(self):self.reject(lambda d:d['audit'][20]['expected'][6].__setitem__(0,10))
    def test_growing_entries(self):self.reject(lambda d:d['audit'][-1].update(active=65))
    def test_missing_removal(self):self.reject(lambda d:d['audit'][-1].update(active=1))
    def test_gpu_slot(self):self.reject(lambda d:d['rows'][0]['variants'][0]['callbacks'][0].update(slots=[0,1]))
    def test_shader(self):self.reject(lambda d:d['rows'][0]['variants'][0]['callbacks'][0].update(shader_sha='0'*64))
    def test_missing_gpu_recovery(self):self.reject(lambda d:self.row(d,'sweep-0-04')['variants'][0]['callbacks'][0]['contacts'][6].__setitem__(0,99))
    def test_changed_save(self):self.reject(lambda d:d['rows'][0]['variants'][0].update(after_sha='0'*64))
    def test_missing_callback(self):self.reject(lambda d:d['rows'][0]['variants'][0]['draws'].pop())
    def test_resource_growth(self):self.reject(lambda d:d['rows'][0]['variants'][0]['stats'].update(builds=2))
    def test_pause_clock(self):self.reject(lambda d:self.row(d,'pause-0').update(seconds=999))
    def test_false_transfer(self):self.reject(lambda d:self.row(d,'teleport-overworld').update(teleport_success=False))
    def test_wrong_gpu_pixel(self):
        source=audit.image(self.folder/'sweep-0-00/on.png');wrong=source.copy();wrong.putpixel((90,80),(255,0,255,255))
        with self.assertRaisesRegex(ValueError,'GPU/CPU'):audit.pair(wrong,source,source,0)
    def test_moving_root(self):
        source=audit.image(self.folder/'sweep-0-00/on.png');wrong=source.copy();pixel=wrong.getpixel((90,165));wrong.putpixel((90,165),((pixel[0]+1)%256,*pixel[1:]))
        with self.assertRaisesRegex(ValueError,'root/lower'):audit.locked_bands(wrong,source)
    def test_no_gpu_effect(self):
        source=audit.image(self.folder/'sweep-0-00/off.png')
        with self.assertRaisesRegex(ValueError,'visibly affect'):audit.pair(source,source,source,2)

if __name__=='__main__':unittest.main()
