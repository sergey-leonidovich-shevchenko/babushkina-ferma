#!/usr/bin/env python3
"""Corrupt copies of real native evidence; never mutate historical captures or gameplay."""
import copy,json,tempfile,unittest
from pathlib import Path
from PIL import Image
from tools.qa.world import post_motion_verify as audit

class PostMotionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before=audit.capture(audit.REPORT/'native/before/1152')
        cls.after=audit.capture(audit.REPORT/'native/after/1152')

    def changed(self,edit,phase='after'):
        data=copy.deepcopy(self.after if phase=='after' else self.before);edit(data)
        with self.assertRaises(ValueError):audit.validate_rows(data,phase,1152)

    def test_actual_series_and_sources(self):
        result=audit.verify();self.assertTrue(result['production_publisher']);self.assertFalse(result['performance_eligible'])
        self.assertEqual(sum(w['draw_callbacks'] for w in result['windows'].values()),320)

    def test_missing_frame(self):self.changed(lambda d:d['rows'].pop())
    def test_duplicate_physical_frame(self):self.changed(lambda d:d['rows'][1].update(index=0))
    def test_hidden_native_window(self):self.changed(lambda d:d['rows'][0].update(visible=False))
    def test_lost_focus(self):self.changed(lambda d:d['rows'][0].update(focused=False))
    def test_wrong_physical_size(self):self.changed(lambda d:d['rows'][0].update(window=[1280,720]))
    def test_fake_shader_uniform(self):self.changed(lambda d:d['rows'][0].update(shader_contact=[0.8,0.8]))
    def test_pre_movement_point(self):self.changed(lambda d:d['rows'][0]['packet'].update(player_world=d['rows'][0]['start']))
    def test_previous_world_after_door(self):
        self.changed(lambda d:next(r for r in d['rows'] if r['id']=='interior')['packet'].update(world='overworld'))
    def test_gameplay_mutation(self):self.changed(lambda d:d['rows'][0]['after'].update(coins=999))
    def test_duplicate_draw(self):self.changed(lambda d:d['rows'][0]['draws'].append(copy.deepcopy(d['rows'][0]['draws'][0])))
    def test_undrained_foreground(self):self.changed(lambda d:d['rows'][0]['draws'][0].update(queue_after=1))
    def test_future_clock_delta(self):self.changed(lambda d:d['rows'][0]['packet'].update(seconds=42))
    def test_pause_catchup(self):self.changed(lambda d:next(r for r in d['rows'] if r['id']=='pause').update(seconds=100))
    def test_wall_held_input(self):self.changed(lambda d:next(r for r in d['rows'] if r['id']=='wall').update(contact=[0,0.5],shader_contact=[0,0.5]))
    def test_mutable_published_packet(self):self.changed(lambda d:d['rows'][0]['packet'].update(read_only=False))
    def test_cross_route_state_difference(self):
        data=copy.deepcopy(self.after);data['rows'][0]['before']['coins']+=1
        with self.assertRaises(ValueError):audit.compare_rows(self.before,data)
    def test_incomplete_source(self):
        folder=audit.REPORT/'native/after';source=json.loads((folder/'source.json').read_text());source['complete']=False
        with self.assertRaises(ValueError):audit.validate_source(folder,'after',source)
    def test_missing_source_coverage(self):
        folder=audit.REPORT/'native/after';source=json.loads((folder/'source.json').read_text());source['sources'].pop(audit.LOOP)
        with self.assertRaises(ValueError):audit.validate_source(folder,'after',source)
    def test_artifact_hash_change(self):
        folder=audit.REPORT/'native/after';source=json.loads((folder/'source.json').read_text());source['artifacts']['1152/frames/0000.png']='0'*64
        with self.assertRaises(ValueError):audit.validate_source(folder,'after',source)

if __name__=='__main__':unittest.main()
