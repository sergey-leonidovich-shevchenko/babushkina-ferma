#!/usr/bin/env python3
"""VRENDER-002 admission tests mutate owned temporary copies, never native sources or user saves."""
import copy
import gzip
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
from PIL import Image
from tools.qa.foliage import grass_methods as g


class GrassMethodsTests(unittest.TestCase):
    """Keeps scope, clocks, phase equivalence, native conditions and immutable sources testable offline."""
    @classmethod
    def setUpClass(cls):
        """Read one raw run/quality row once; individual mutations remain independent."""
        target=g.REPORT/'bench/r1-256-cpu'
        cls.data=g.read(target/'run.json'); cls.values=g.rows(target/'rows.csv.gz',g.FIELDS); cls.render=g.rows(target/'render.csv.gz',g.RENDER_FIELDS)
        target=g.REPORT/'quality/1152'; cls.quality_case=g.read(target/'quality.json')['results'][0]
        cls.draws=g.zipped(target/(cls.quality_case['id']+'-draws.json.gz'))

    def setUp(self):
        """Fresh records make a failure local to the stated mutation."""
        self.data=copy.deepcopy(type(self).data); self.values=copy.deepcopy(type(self).values); self.render=copy.deepcopy(type(self).render)
        self.case=copy.deepcopy(self.quality_case); self.draws=copy.deepcopy(type(self).draws)

    def reject(self,text):
        """Requires a relevant admission error rather than an unrelated exception."""
        with self.assertRaisesRegex(ValueError,text): g.validate_rows(self.data,self.values,self.render)

    def test_complete_native_packets(self):
        """All native evidence remains reproducible without claiming live-game FPS or contact foliage."""
        result=g.combined(); q=result['quality']; b=result['original_cost']; cpu=result['optimized_cpu_cost']
        self.assertEqual((q['frames'],q['draws']),(54,216)); self.assertEqual(b['run_count'],24); self.assertEqual(cpu['run_count'],6)
        self.assertFalse(q['full_foliage_contact_accepted']); self.assertFalse(b['live_gameplay_fps_accepted']); self.assertIsNone(b['gpu_time_ms'])
        self.assertEqual(result,g.read(g.REPORT/'summary.json'))

    def test_wrong_host(self):
        """Logical design size cannot excuse a smaller physical readback."""
        self.data['readback']=[960,540]; self.reject('host/focus')

    def test_focus_loss(self):
        """One lost-focus sample rejects comparison despite a focused final witness."""
        self.values[10]['focused']=0; self.reject('mid-run')

    def test_mid_run_pause(self):
        """A stopped visual clock cannot make the effect look artificially cheap."""
        self.values[10]['modal']=1; self.reject('mid-run')

    def test_gpu_inference(self):
        """CPU/update intervals cannot become GPU timings by relabelling."""
        self.data['gpu_time_ms']=1; self.reject('GPU inference')

    def test_render_counter(self):
        """Repeated idle observations cannot masquerade as completed rendering boundaries."""
        self.render[10]['render_frame']=self.render[9]['render_frame']; self.reject('render clock')

    def test_truncated_sample(self):
        """The declared full duration does not excuse a missing tail."""
        self.values=self.values[:100]; self.data['samples']=100; self.reject('shortened')

    def test_camera_shift(self):
        """Different visible content cannot enter the same comparison."""
        self.values[10]['camera_x']+=24; self.reject('mid-run')

    def test_stopped_clock(self):
        """A static shader image is not a valid moving-effect benchmark."""
        for row in self.values: row['wind_time']=1
        self.reject('not advancing')

    def test_hitch_retained(self):
        """A synthetic one-second hitch stays in both maxima instead of being trimmed."""
        for rows in [self.values,self.render]:
            middle=len(rows)//2; rows[middle]['interval_ms']+=1000
            for row in rows[middle:]: row['usec']+=1000000
        self.data['ended_utc']+=1
        result=g.validate_rows(self.data,self.values,self.render)
        self.assertGreater(result['idle_ms']['max'],1000); self.assertGreater(result['render_interval_ms']['max'],1000)

    def test_upload_in_static_gpu_method(self):
        """The supposed static implementation must not secretly upload vertices every frame."""
        stats=copy.deepcopy(self.case['statistics']); stats.update(method='batch',vertex_updates=1,cpu_upload_bytes=100)
        with self.assertRaisesRegex(ValueError,'CPU vertex upload'): g.statistics_shape(stats,'batch',256)

    def test_hidden_state_mutation(self):
        """Equal=true cannot conceal an actual changed HP value in a snapshot."""
        self.draws[0]['after']['hp']-=1
        with self.assertRaisesRegex(ValueError,'saved gameplay'): g.quality_row(self.case,1152,648,self.draws)

    def test_wrong_uniform(self):
        """The material's actual uniform must match its declared controlled phase."""
        self.case['shader_time']+=1
        with self.assertRaisesRegex(ValueError,'uniform clock'): g.quality_row(self.case,1152,648,self.draws)

    def test_interior_leak(self):
        """A new layer must not follow the hero visibly into an existing interior."""
        self.case.update(id='cpu-interior',location='cottage_interior',visible=True)
        with self.assertRaisesRegex(ValueError,'lifecycle'): g.quality_row(self.case,1152,648,self.draws)

    def test_nonfinite_csv(self):
        """Unknown timings are rejected rather than removed from a quantile."""
        with tempfile.TemporaryDirectory(prefix='grass-nan-') as name:
            path=Path(name)/'rows.csv.gz'
            with gzip.open(path,'wt') as stream: stream.write(','.join(g.FIELDS)+'\n'+','.join(['nan']+['0']*(len(g.FIELDS)-1))+'\n')
            with self.assertRaisesRegex(ValueError,'non-finite'): g.rows(path,g.FIELDS)

    def test_changed_image_detected(self):
        """A wrong pixel exceeds the declared method-equivalence maximum, without relying on SHA."""
        with tempfile.TemporaryDirectory(prefix='grass-image-') as name:
            first=Path(name)/'a.png'; second=Path(name)/'b.png'
            image=Image.new('RGB',(32,32),'black'); image.save(first); image.putpixel((4,4),(255,0,255)); image.save(second)
            metric=g.image_difference(first,second); self.assertEqual(metric['changed_pixels'],1); self.assertEqual(metric['max_channel_error'],255)

    def test_incomplete_collection(self):
        """An interrupted experiment never receives positive admission."""
        with tempfile.TemporaryDirectory(prefix='grass-incomplete-') as name:
            path=Path(name); (path/'source.json').write_text(json.dumps({'complete':False}))
            with self.assertRaisesRegex(ValueError,'incomplete'): g.provenance(path,'bench')

    def test_historical_overlay_is_not_current_version(self):
        """Future version/collector edits do not rewrite the captured input version."""
        original=g.sha
        def guarded(path):
            self.assertNotEqual(Path(path).resolve(),(g.ROOT/'project.godot').resolve())
            return original(path)
        with mock.patch.object(g,'sha',side_effect=guarded): self.assertTrue(g.provenance(g.REPORT/'bench','bench')['complete'])


if __name__=='__main__': unittest.main()
