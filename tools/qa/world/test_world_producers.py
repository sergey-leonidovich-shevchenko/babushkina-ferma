"""Actual World source producers with real Git/hash/copy and an explicit failed fake-open child; no Game."""
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.qa.world import object_command_collect as objects
from tools.qa.world import object_command_verify as object_verify
from tools.qa.world import pilot_pass_collect as pilot_pass
from tools.qa.world import pilot_pass_verify
from tools.qa.world import pilot_static_collect as static
from tools.qa.world import pilot_static_verify
from tools.qa.world import post_motion_collect as motion
from tools.qa.world import post_motion_verify
from tools.qa.world import render_order
from tools.qa.world import shadow_inventory_collect as shadow
from tools.qa.world import shadow_inventory_verify
from tools.qa.world import transient_save_collect as transient
from tools.qa.world import transient_save_verify
from tools.qa.world import village_bench_collect as bench
from tools.qa.world import village_bench_verify
from tools.qa.world import village_board_collect as board
from tools.qa.world import village_board_verify
from tools.qa.world import village_fence_collect as fence
from tools.qa.world import village_fence_verify
from tools.qa.world import village_lamp_collect as lamp
from tools.qa.world import village_lamp_verify
from tools.qa.world import village_street_collect as street
from tools.qa.world import village_street_verify
from tools.qa.world import village_trade_collect as trade
from tools.qa.world import village_trade_verify
import plant_depth_collect as plant_depth
import plant_depth_verify
from tools.assets.contracts.source_paths import current_source
from tools.qa.art.current_paths import MOVED_PATHS as ART_PATHS
from tools.qa.performance import perf_contract_collect as perf
from tools.qa.world import test_world_context as context_fixtures
from tools.common.git import git_environment

PRODUCERS=[objects,pilot_pass,static,motion,shadow,transient,bench,board,fence,lamp,street,trade,render_order,plant_depth]
CAPTURES=dict(zip(PRODUCERS,['object_command_capture.gd','pilot_pass_capture.gd','pilot_static_capture.gd',
    'post_motion_capture.gd','shadow_inventory_capture.gd','transient_save_capture.gd',
    'village_bench_capture.gd','village_board_capture.gd','village_fence_capture.gd',
    'village_lamp_capture.gd','village_street_capture.gd','village_trade_capture.gd','render_order_capture.gd','plant_depth_capture.gd']))
VERIFIERS={objects:object_verify,pilot_pass:pilot_pass_verify,static:pilot_static_verify,
    motion:post_motion_verify,shadow:shadow_inventory_verify,transient:transient_save_verify,
    bench:village_bench_verify,board:village_board_verify,fence:village_fence_verify,
    lamp:village_lamp_verify,street:village_street_verify,trade:village_trade_verify,render_order:render_order,plant_depth:plant_depth_verify}


class WorldProducerInputsTests(unittest.TestCase):
    """Test real producer I/O before any valid native frame; inventory/context fixtures never grant FPS."""
    git=context_fixtures.WorldContextTests.git
    repository=context_fixtures.WorldContextTests.repository
    foreign_context=context_fixtures.WorldContextTests.foreign_context

    def physical(self, root, name):
        """Fixture reference composes the existing closed source maps without using the new helper."""
        return current_source(root,ART_PATHS.get(name,name))

    def seed(self, own):
        """Copy real declared source bytes; this intentionally incomplete project cannot produce native proof."""
        original=render_order.ROOT;names={'project.godot','main.tscn','VERSION'}
        for module in PRODUCERS:
            for key in ['SOURCES','ORIGINAL','EXTRA','QA']:
                names.update(getattr(module,key,[]))
            for key,value in vars(module).items():
                if key.endswith('_ASSETS')and isinstance(value,list):names.update(value)
        for directory in['benches','boards','fences','lamps','street_props','trade']:
            names.update(str(p.relative_to(original))for p in(original/'assets/game/locations/overworld'/directory).glob('*')if p.suffix in['.png','.json','.import'])
        for name in names:
            source=self.physical(original,name);self.assertTrue(source.is_file(),name)
            target=self.physical(own,name);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes())
        subprocess.run(['git','-C',str(own),'add','.'],env=git_environment(),check=True)
        subprocess.run(['git','-C',str(own),'-c','user.name=World producer QA','-c','user.email=qa@example.invalid','commit','-qm','real current inputs'],env=git_environment(),check=True)
        base=self.git(own,'rev-parse','HEAD')
        if self.git(own,'branch','--show-current')!='main':
            subprocess.run(['git','-C',str(own),'branch','main',base],env=git_environment(),check=True)
        return base

    def expected(self, module, own):
        """Keep the producer's actual declared namespace, including its real current asset globs."""
        if module in[objects,render_order]:return set(module.SOURCES)
        if module in[shadow,transient]:
            files=self.git(own,'ls-files').splitlines()
            production={n for n in files if n.startswith('scripts/')and n.endswith(('.gd','.gdshader')if module is shadow else'.gd')}
            return production|set(module.QA)|{'project.godot','main.tscn'}
        names=set(module.ORIGINAL+module.EXTRA)
        for key,value in vars(module).items():
            if key.endswith('_ASSETS')and isinstance(value,list):names.update(value)
        if module is bench:
            names.update(str(p.relative_to(own))for p in(own/'assets/game/locations/overworld/benches').glob('*')if p.suffix in['.png','.json','.import'])
        return names

    def collect(self, module, output):
        """Preserve the real public call shape; every invocation targets a fresh owned directory."""
        if module is render_order:module.capture(output)
        elif module is objects:module.collect(output,static_coexistence=True)
        elif module is shadow:module.collect(output)
        elif module is transient:module.collect('after')
        else:module.collect(output,'after')

    def partial_must_refuse(self, module, output, report, base):
        """The actual source/native reader rejects every incomplete failed-child packet."""
        verifier=VERIFIERS[module]
        with patch.object(verifier,'REPORT',report),self.assertRaises((ValueError,FileNotFoundError)):
            if module in[bench,board,fence,lamp,street,trade]:verifier.provenance(output,'after')
            elif module is objects:verifier.provenance(output)
            elif module is pilot_pass:verifier.provenance('after')
            elif module is static:verifier.provenance()
            elif module is motion:verifier.validate_source(output,'after')
            elif module is transient:verifier.provenance(output,'after',{'base_commit':base})
            elif module is plant_depth:verifier.validate_source(output,'after',{'base_commit':base})
            elif module is shadow:verifier.verify(report)
            else:verifier.verify(output)

    def producer(self, module):
        """Actual Git/copy/hash and child argv run; fake inventory/context and fake-open cannot render Game."""
        original=render_order.ROOT
        with tempfile.TemporaryDirectory(prefix='world actual producer inputs ')as directory:
            parent=Path(directory).resolve();own=self.repository(parent/'own project');base=self.seed(own)
            report=parent/'new packet report';witness=parent/'fake-child.json';binary=parent/'owned fake bin';binary.mkdir()
            child=binary/'open'
            child.write_text('#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\n'
                'Path(os.environ["FARM_WORLD_CHILD_WITNESS"]).write_text(json.dumps({"cwd":os.getcwd(),"argv":sys.argv[1:],"fake_open":True,"native_frames":0}))\n'
                'raise SystemExit(17)\n')
            child.chmod(0o755)
            output=report/'native'
            if module is static:output=report/'native/static'
            elif module not in[objects,shadow,render_order]:output=report/'native/after'
            before={n:(own/'.git'/n).read_bytes()for n in['index','config']}
            with ExitStack()as stack:
                stack.enter_context(patch.object(perf,'ROOT',own))
                for tool in PRODUCERS:
                    stack.enter_context(patch.object(tool,'ROOT',own))
                stack.enter_context(patch.object(transient,'REPORT',report))
                stack.enter_context(patch.object(render_order,'REPORT',report))
                # These are explicit source-only prerequisites, not simulated hardware/native evidence.
                if module is render_order:
                    stack.enter_context(patch.object(module,'native_jobs',return_value=[]))
                    report.mkdir();module.build_contract()
                else:
                    stack.enter_context(patch.object(module,'jobs',return_value=[]))
                    stack.enter_context(patch.object(module,'context',return_value={'fixture_scope':'source-only; no native engine'}))
                stack.enter_context(patch.dict(os.environ,FARM_WORLD_CHILD_WITNESS=str(witness),PATH=str(binary)+os.pathsep+os.environ['PATH']))
                expected=self.expected(module,own)
                stack.enter_context(self.foreign_context())
                with self.assertRaises((ValueError,FileNotFoundError)):self.collect(module,output)
                self.assertTrue(witness.is_file(),'actual fake-open child must be reached only after source I/O')
                self.assertTrue((output/'source.json').is_file())
                source=json.loads((output/'source.json').read_text())
                self.assertEqual(source['base_commit'],base);self.assertFalse(source['complete'])
                if'performance_eligible'in source:self.assertIs(source['performance_eligible'],False)
                self.assertEqual(set(source['sources']),expected)
                archived='instrumentation'if module is render_order else'inputs'
                for name,digest in source['sources'].items():
                    self.assertEqual(digest,hashlib.sha256(self.physical(own,name).read_bytes()).hexdigest(),name)
                    copy=output/archived/name
                    if module is not shadow or name in source['overlay']:
                        self.assertEqual(copy.read_bytes(),self.physical(own,name).read_bytes())
                    if'base_sources'in source:self.assertEqual(source['base_sources'][name],digest)
                recorded=json.loads(witness.read_text());self.assertTrue(recorded['fake_open']);self.assertEqual(recorded['native_frames'],0)
                self.assertEqual(Path(recorded['cwd']),own)
                args=recorded['argv'];self.assertEqual(Path(args[args.index('--path')+1]),own)
                logical='tools/'+CAPTURES[module]
                physical=str(current_source(original,logical).relative_to(original))
                self.assertEqual(args[args.index('--script')+1],'res://'+physical)
                self.assertTrue((own/physical).is_file())
                self.partial_must_refuse(module,output,report,base)
                previous=(output/'source.json').read_bytes()
                with self.assertRaises(ValueError):self.collect(module,output)
                self.assertEqual((output/'source.json').read_bytes(),previous)
            for name,raw in before.items():self.assertEqual((own/'.git'/name).read_bytes(),raw)

    def test_object_real_inputs_and_failed_fake_child(self):
        """Actual descriptor collector preserves current input bytes and its logical namespace."""
        self.producer(objects)

    def test_pilot_pass_real_inputs_and_failed_fake_child(self):
        """Actual object-pass collector freezes its source envelope before child failure."""
        self.producer(pilot_pass)

    def test_static_real_inputs_and_failed_fake_child(self):
        """Actual static collector retains art metadata and real mapped source copies."""
        self.producer(static)

    def test_post_motion_real_inputs_and_failed_fake_child(self):
        """Actual motion collector cannot turn missing native frames into a valid report."""
        self.producer(motion)

    def test_shadow_real_inputs_and_failed_fake_child(self):
        """Actual shadow collector binds its real production Git tree and QA overlay."""
        self.producer(shadow)

    def test_transient_real_inputs_and_failed_fake_child(self):
        """Actual save collector keeps its main asset tree and full declared script coverage."""
        self.producer(transient)

    def test_bench_real_inputs_and_failed_fake_child(self):
        """Actual bench collector hashes and copies its current asset/source union."""
        self.producer(bench)

    def test_board_real_inputs_and_failed_fake_child(self):
        """Actual board collector retains complete before-native source coverage."""
        self.producer(board)

    def test_fence_real_inputs_and_failed_fake_child(self):
        """Actual fence collector binds exact source and asset bytes."""
        self.producer(fence)

    def test_lamp_real_inputs_and_failed_fake_child(self):
        """Actual lamp collector preserves logical keys and rejects its failed child."""
        self.producer(lamp)

    def test_street_real_inputs_and_failed_fake_child(self):
        """Actual street collector reaches only the owned explicit fake-open executable."""
        self.producer(street)

    def test_trade_real_inputs_and_failed_fake_child(self):
        """Actual trade collector cannot accept a partial source packet as native proof."""
        self.producer(trade)

    def test_render_order_real_inputs_and_failed_fake_child(self):
        """Actual inventory/capture writes real instrumentation and keeps complete false."""
        self.producer(render_order)


    def test_plant_depth_real_inputs_and_failed_fake_child(self):
        """The external vegetation-depth collector preserves inherited World inputs and real child argv."""
        self.producer(plant_depth)


if __name__=='__main__':unittest.main()
