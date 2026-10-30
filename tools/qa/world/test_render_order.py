#!/usr/bin/env python3
"""VRENDER-001: negative copies must fail even if their artifact hash is recomputed."""
import copy
import gzip
import json
from tools.common.git import git_environment
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock
from PIL import Image
from tools.qa.world import render_order as r


class RenderOrderTests(unittest.TestCase):
    """Uses copied native evidence; never changes runtime files or launches Godot."""
    def test_actual_native_pairs(self):
        """A clean checkout reproduces all native pairs without closing future shader/FPS/map gates."""
        result=r.verify()
        self.assertEqual(result['pairs'],18)
        self.assertGreaterEqual(result['draws'],72)
        self.assertFalse(result['fps_accepted'])
        self.assertFalse(result['new_shader_accepted'])
        self.assertFalse(result['whole_map_accepted'])

    def test_required_evidence_tracked(self):
        """Local ignored files cannot masquerade as evidence reproducible from Git."""
        paths=[str(p.relative_to(r.ROOT)) for p in (r.REPORT/'native').rglob('*') if p.is_file()]
        result=subprocess.run(['git','ls-files','--error-unmatch','--',*paths],cwd=r.ROOT,capture_output=True, env=git_environment())
        self.assertEqual(result.returncode,0,result.stderr.decode())

    def test_inventory_preserves_multiple_guarded_calls(self):
        """A single guarded source line may hold several ordered renderer calls."""
        text='static func draw(game):\n\tif game.title_screen: game.draw_title_screen(); game.UiFeedbackRenderer.draw(game); return\n'
        values=r.inventory(text)
        self.assertEqual([v['method'] for v in values],['draw_title_screen','draw'])
        self.assertTrue(all('if game.title_screen:' in v['source'] for v in values))

    def test_inventory_preload_receiver(self):
        """Inline preloads retain the actual module address instead of losing their renderer name."""
        values=r.inventory('static func draw(game):\n\tpreload("res://front.gd").draw(game)\n')
        self.assertEqual(values[0]['receiver'],'preload("res://front.gd")')

    def row(self):
        """Creates deliberately synthetic state to test purity admission, not native graphics."""
        return {'before':{'hp':100},'after':{'hp':100},'equal':True,'geometry_equal':True,
            'geometry_before':{'camera':[1,2]},'geometry_after':{'camera':[1,2]},'queue_after':0}

    def test_hidden_gameplay_mutation(self):
        """A falsely green flag cannot conceal changed HP in the actual snapshot."""
        rows=[self.row() for _ in range(4)]; rows[2]['after']['hp']=99
        with self.assertRaisesRegex(ValueError,'saved gameplay'): r.validate_draws(rows)

    def test_camera_mutation(self):
        """Saved gameplay equality alone does not permit moving the comparison camera."""
        rows=[self.row() for _ in range(4)]; rows[1]['geometry_after']['camera']=[2,2]
        with self.assertRaisesRegex(ValueError,'camera/location'): r.validate_draws(rows)

    def test_unflushed_foreground(self):
        """A skipped foreground flush cannot silently survive the draw boundary."""
        rows=[self.row() for _ in range(4)]; rows[0]['queue_after']=1
        with self.assertRaisesRegex(ValueError,'queue'): r.validate_draws(rows)

    def test_missing_callbacks(self):
        """A screenshot without the required actual draw callbacks is insufficient."""
        with self.assertRaisesRegex(ValueError,'callbacks'): r.validate_draws([self.row()])

    def copy_packet(self,name):
        """Copies only the current evidence packet into an owned temporary directory."""
        target=Path(name)/'native'; shutil.copytree(r.REPORT/'native',target); return target

    def resign(self,folder,path):
        """Only the negative temporary copy is re-signed to exercise semantic checks beyond SHA."""
        source=r.read(folder/'source.json'); source['artifacts'][str(path.relative_to(folder))]=r.sha(path); r.write(folder/'source.json',source)

    def test_resigned_pixel_change(self):
        """A modified image fails the decoded pixel comparison despite a fresh local hash."""
        with tempfile.TemporaryDirectory(prefix='vrender-pixel-') as name:
            folder=self.copy_packet(name); path=folder/'1152/village-observed.png'
            with Image.open(path) as im:
                image=im.convert('RGBA'); image.putpixel((0,0),(255,0,255,255)); image.save(path)
            self.resign(folder,path)
            with self.assertRaisesRegex(ValueError,'observer changed pixels'): r.verify(folder)

    def test_resigned_snapshot_change(self):
        """A snapshot mutation cannot pass by retaining its old equal=true assertion."""
        with tempfile.TemporaryDirectory(prefix='vrender-state-') as name:
            folder=self.copy_packet(name); path=folder/'1152/village-draws.json.gz'
            with gzip.open(path,'rt') as stream: rows=json.load(stream)
            rows[0]['after']['hp']-=1
            with gzip.open(path,'wt') as stream: json.dump(rows,stream)
            self.resign(folder,path)
            with self.assertRaisesRegex(ValueError,'saved gameplay'): r.verify(folder)

    def test_missing_trace(self):
        """Missing raw proof is not replaced by self-reported metadata."""
        with tempfile.TemporaryDirectory(prefix='vrender-missing-') as name:
            folder=self.copy_packet(name); (folder/'1280/bridge-draws.json.gz').unlink()
            with self.assertRaisesRegex(ValueError,'artifact coverage'): r.verify(folder)

    def test_wrong_tree_fixture(self):
        """A green pixel pair at an unrelated location cannot stand in for actual tree occlusion."""
        with tempfile.TemporaryDirectory(prefix='vrender-tree-') as name:
            folder=self.copy_packet(name); path=folder/'1152/capture.json'; data=r.read(path)
            next(c for c in data['cases'] if c['id']=='tree-behind')['tree_alpha']=1
            r.write(path,data); self.resign(folder,path)
            with self.assertRaisesRegex(ValueError,'actual tree occlusion'): r.verify(folder)

    def test_stale_call_inventory(self):
        """Editing the published call order cannot keep the accepted source snapshot."""
        value=copy.deepcopy(r.read(r.REPORT/'contract.json')); value['calls'].reverse()
        with self.assertRaisesRegex(ValueError,'inventory stale'): r.validate_contract(value,r.REPORT/'native/instrumentation')

    def test_historical_proof_does_not_read_current_overlay(self):
        """Later version/collector edits do not invalidate the immutable captured source snapshot."""
        original=r.sha
        def guarded(path):
            self.assertNotIn(Path(path).resolve(),[(r.ROOT/'project.godot').resolve(),(r.ROOT/'tools/render_order.py').resolve()])
            return original(path)
        with mock.patch.object(r,'sha',side_effect=guarded):
            self.assertTrue(r.verify()['accepted'])

    def test_resigned_runtime_must_match_git_base(self):
        """Re-signing both temporary manifests cannot replace an archived production renderer."""
        with tempfile.TemporaryDirectory(prefix='vrender-base-') as name:
            folder=self.copy_packet(name); relative='scripts/systems/render_system.gd'; path=folder/'instrumentation'/relative
            path.write_text(path.read_text()+'\n# changed archive\n'); digest=r.sha(path)
            contract=r.read(r.REPORT/'contract.json'); contract['sources'][relative]=digest
            source=r.read(folder/'source.json'); source['sources'][relative]=digest; r.write(folder/'source.json',source)
            r.write(Path(name)/'contract.json',contract)
            with mock.patch.object(r,'REPORT',Path(name)):
                with self.assertRaisesRegex(ValueError,'differs from Git base'): r.verify(folder)


if __name__=='__main__': unittest.main()
