#!/usr/bin/env python3
"""VRENDER-003 negative admission checks operate on copies, not player slots or signed native sources."""
import copy
import gzip
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock
from PIL import Image
import ground_layers as g


class GroundLayersTests(unittest.TestCase):
    """Protects actual cache ownership, first frame, full snapshots and the declared pixel bound."""
    @classmethod
    def setUpClass(cls):
        """Reads one immutable native witness; each test mutates only an independent copy."""
        cls.folder=g.REPORT/'native'
        data=g.load(cls.folder/'1152/capture.json')
        cls.row=next(r for r in data['records'] if r['id']=='village-split')
        cls.hot=g.load(cls.folder/'1152/hot-loop.json')
        with gzip.open(cls.folder/'1152/cold-first-draws.json.gz','rt') as stream: cls.cold=json.load(stream)

    def test_complete_native_evidence(self):
        """Complete actual callbacks retain narrow scope and the published source-bound result."""
        result=g.verify(); self.assertEqual((result['frames'],result['draws']),(64,250))
        self.assertEqual(result,g.load(g.REPORT/'summary.json'))
        for key in ['whole_map_accepted','new_water_art_accepted','live_gameplay_fps_accepted']: self.assertFalse(result[key])
        self.assertIsNone(result['gpu_time_ms'])

    def test_extra_viewport(self):
        """A hidden second full-map target cannot satisfy the one-target contract."""
        row=copy.deepcopy(self.row); row['child_viewports']=2
        with self.assertRaisesRegex(ValueError,'ownership'): g.state(row)

    def test_repeated_target_render(self):
        """Retained commands alone do not excuse rendering the static target on every frame."""
        row=copy.deepcopy(self.row); row['viewport_mode']=4
        with self.assertRaisesRegex(ValueError,'ownership'): g.state(row)

    def test_wrong_static_coverage(self):
        """A full-water bake cannot be relabelled as a separated base."""
        row=copy.deepcopy(self.row); row['base_only']=False
        with self.assertRaisesRegex(ValueError,'coverage'): g.state(row)

    def test_surface_above_bridge(self):
        """The surface cannot be allowed to draw over the cached bridge deck."""
        row=copy.deepcopy(self.row); row['surface_behind_parent']=False
        with self.assertRaisesRegex(ValueError,'bridge/fence'): g.state(row)

    def test_interior_layer_leak(self):
        """A different map must not inherit either cached first-map cover or its live surface."""
        row=copy.deepcopy(self.row); row['location']='cottage_interior'
        with self.assertRaisesRegex(ValueError,'visibility'): g.state(row)

    def test_legacy_double_draw(self):
        """Fallback and split surface cannot both be visible under the same camera."""
        row=copy.deepcopy(self.row); row['split']=False
        with self.assertRaisesRegex(ValueError,'visibility'): g.state(row)

    def test_hot_rebuilds(self):
        """Every retained pass, including the hole stencil, is independently guarded."""
        for field in ['requests','base_paints','surface_paints','cover_paints','cutout_paints']:
            with self.subTest(field=field):
                data=copy.deepcopy(self.hot); data['after'][field]+=1
                with self.assertRaisesRegex(ValueError,'rebuilt'): g.hot_loop(data)

    def test_static_texture_changed(self):
        """Unchanged CPU counters cannot hide changed offscreen RGBA bytes."""
        data=copy.deepcopy(self.hot); data['cache_after']='0'*64
        with self.assertRaisesRegex(ValueError,'texture'): g.hot_loop(data)

    def test_static_clock_cannot_fake_hot_loop(self):
        """A frozen decorative clock cannot make the hot-cache experiment pass."""
        data=copy.deepcopy(self.hot); data['after']['time']=data['before']['time']
        with self.assertRaisesRegex(ValueError,'advancing'): g.hot_loop(data)

    def test_cold_hp_mutation(self):
        """The first frame still compares all saved fields despite having only one callback."""
        draws=copy.deepcopy(self.cold); draws[0]['after']['hp']-=1
        with self.assertRaisesRegex(ValueError,'saved gameplay'): g.cold_draws(draws)

    def test_cold_geometry_mutation(self):
        """A green self-report cannot conceal a changed camera in the first frame."""
        draws=copy.deepcopy(self.cold); draws[0]['geometry_after']['camera']='(999, 999)'
        with self.assertRaisesRegex(ValueError,'geometry'): g.cold_draws(draws)

    def test_cold_missing_or_duplicated_draw(self):
        """One first frame is neither missing nor inflated to a four-callback regular case."""
        for draws in [[],self.cold*4]:
            with self.assertRaisesRegex(ValueError,'missing'): g.cold_draws(draws)

    def test_cold_foreground_queue(self):
        """An unconsumed tree queue is rejected in the first frame too."""
        draws=copy.deepcopy(self.cold); draws[0]['queue_after']=1
        with self.assertRaisesRegex(ValueError,'foreground'): g.cold_draws(draws)

    def test_pixel_bound(self):
        """Single-step quantization is allowed, a two-step or broad colour error is not."""
        g.image_quality({'mean_channel_error':.05,'max_channel_error':1})
        for metric in [{'mean_channel_error':0,'max_channel_error':2},{'mean_channel_error':.2,'max_channel_error':1}]:
            with self.assertRaisesRegex(ValueError,'quantization'): g.image_quality(metric)

    def test_opaque_hud_pixel(self):
        """World compositing never excuses a changed pixel inside an opaque HUD panel."""
        with tempfile.TemporaryDirectory(prefix='ground-hud-') as name:
            a=Path(name)/'a.png'; b=Path(name)/'b.png'; image=Image.new('RGB',(1152,648),'black'); image.save(a)
            image.putpixel((40,40),(1,0,0)); image.save(b)
            with self.assertRaisesRegex(ValueError,'HUD'): g.opaque_hud(a,b,1152)

    def test_cold_image_must_be_exact(self):
        """The first direct frame must not hide missing water behind valid counters or a general tolerance."""
        g.cold_image_quality({'max_channel_error':0})
        with self.assertRaisesRegex(ValueError,'complete direct reference'): g.cold_image_quality({'max_channel_error':1})

    def test_archived_input_damage(self):
        """A changed frozen overlay is rejected before trusting any native self-report."""
        with tempfile.TemporaryDirectory(prefix='ground-input-') as name:
            folder=Path(name); shutil.copyfile(self.folder/'source.json',folder/'source.json'); shutil.copytree(self.folder/'inputs',folder/'inputs')
            p=folder/'inputs'/g.SOURCES[0]; p.write_bytes(p.read_bytes()+b'\n# changed\n')
            with self.assertRaisesRegex(ValueError,'input changed'): g.provenance(folder)

    def test_resigned_production_input(self):
        """Re-signing an unrelated main scene cannot override its historical Git base."""
        with tempfile.TemporaryDirectory(prefix='ground-base-') as name:
            folder=Path(name); shutil.copytree(self.folder/'inputs',folder/'inputs'); source=g.load(self.folder/'source.json')
            p=folder/'inputs/main.tscn'; p.write_bytes(p.read_bytes()+b'\n; changed\n'); source['sources']['main.tscn']=g.sha(p)
            (folder/'source.json').write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError,'unreviewed'): g.provenance(folder)

    def test_historical_project_is_not_current(self):
        """Later project versions cannot silently rewrite a completed historical experiment."""
        original=g.sha
        def guarded(path):
            self.assertNotEqual(Path(path).resolve(),(g.ROOT/'project.godot').resolve()); return original(path)
        with mock.patch.object(g,'sha',side_effect=guarded): self.assertTrue(g.provenance(self.folder)['complete'])


if __name__=='__main__': unittest.main()
