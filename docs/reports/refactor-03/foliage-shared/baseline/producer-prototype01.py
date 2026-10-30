"""Real Foliage producers with canonical files/Git/hash/copy and an explicit fake-open17 boundary."""
from contextlib import ExitStack
import hashlib
import importlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.assets.contracts.source_paths import current_source
from tools.common.git import git_environment
from tools.qa.performance import perf_contract_collect as common
from tools.qa.world import test_world_context as fixtures
from tools.qa.world.source_inputs import input_path

ROOT=common.ROOT
MOVES=json.loads((ROOT/'docs/reports/refactor-03/foliage-shared/PLAN.json').read_text())['rows']


def load(name):
    path=current_source(ROOT,'tools/'+name+'.py')
    return importlib.import_module('.'.join(path.relative_to(ROOT).with_suffix('').parts))


class FoliageProducerTests(unittest.TestCase):
    git=fixtures.WorldContextTests.git
    repository=fixtures.WorldContextTests.repository
    foreign_context=fixtures.WorldContextTests.foreign_context

    def future_name(self,logical):
        return MOVES[logical]['target'] if logical in MOVES else str(input_path(ROOT,logical).relative_to(ROOT))

    def producer(self,name):
        """Hash/copy/index/commit are real; the only child is a declared fake-open that exits17."""
        mod=load(name)
        plan=None
        if name in {'foliage_pause_collect','foliage_visibility_collect'}:
            original=mod.REPORT/('plan-windowed.json' if name=='foliage_pause_collect' else 'plan.json')
            plan=json.loads(original.read_text());logical=set(plan['sources'])
        elif name=='grass_compare_collect':logical=set(mod.FROZEN)
        elif name=='plant_depth_collect':logical=set(mod.ORIGINAL)|set(mod.EXTRA)
        else:logical=set(mod.RUNTIME)|set(mod.QA)|set(getattr(mod,'ART',[]))
        logical.update({'project.godot','main.tscn','VERSION','assets/game/environment/village_ambient_atlas_v1.png'})
        with tempfile.TemporaryDirectory(prefix='Foliage actual producer ') as directory:
            parent=Path(directory).resolve();own=self.repository(parent/'own project')
            self.git(own,'branch','-M','main')
            for key in sorted(logical):
                source=input_path(ROOT,key);self.assertTrue(source.is_file(),key)
                target=own/self.future_name(key);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes())
            self.git(own,'add','.')
            self.git(own,'-c','user.name=Foliage QA','-c','user.email=qa@example.invalid','commit','-qm','real source fixture')
            base=self.git(own,'rev-parse','HEAD');stable={n:(own/'.git'/n).read_bytes() for n in ['index','config']}
            plan_file=parent/'new-plan.json'
            if plan is not None:
                plan['sources']={n:hashlib.sha256((own/self.future_name(n)).read_bytes()).hexdigest() for n in plan['sources']}
                plan_file.write_text(json.dumps(plan))
            fake=parent/'fake-open17'
            fake.write_text('#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\n'
                'Path(os.environ["FARM_FOLIAGE_OPEN_WITNESS"]).write_text(json.dumps({"argv":sys.argv[1:],"cwd":os.getcwd()}))\n'
                'for arg in sys.argv[1:]:\n'
                ' if arg.startswith("--output="):\n'
                '  p=Path(arg.split("=",1)[1]);p.mkdir(parents=True,exist_ok=True);(p/"capture.json").write_text(json.dumps({"errors":[],"explicit_fake_partial":True}))\n'
                'raise SystemExit(17)\n')
            fake.chmod(0o755);real_popen=subprocess.Popen
            def open_only(argv,*args,**kwargs):
                if argv[0] in {'open','/usr/bin/open'}:argv=[str(fake),*argv[1:]]
                return real_popen(argv,*args,**kwargs)
            output=parent/'new archive'
            with ExitStack() as stack:
                stack.enter_context(self.foreign_context())
                stack.enter_context(patch.object(mod,'ROOT',own));stack.enter_context(patch.object(common,'ROOT',own))
                stack.enter_context(patch.object(mod,'jobs',return_value=[]))
                stack.enter_context(patch.object(mod,'context',return_value={'explicit_source_only_fixture':True}))
                stack.enter_context(patch.object(subprocess,'Popen',side_effect=open_only))
                stack.enter_context(patch.dict(os.environ,FARM_FOLIAGE_OPEN_WITNESS=str(parent/'open.json'),PYTHONDONTWRITEBYTECODE='1'))
                with self.assertRaises(ValueError):
                    if plan is not None:mod.collect(output,plan_file)
                    elif name=='grass_compare_collect':mod.collect(output,'quality')
                    elif name=='plant_depth_collect':mod.collect(output,'after')
                    else:mod.collect(output)
                source=json.loads((output/'source.json').read_text())
                self.assertEqual(source['base_commit'],base);self.assertFalse(source['complete'])
                self.assertIsNot(source.get('performance_eligible'),True)
                for key,digest in source.get('sources',{}).items():
                    raw=(own/self.future_name(key)).read_bytes();self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
                    archive=output/('instrumentation' if name=='grass_compare_collect' else 'inputs')/key
                    if key in source.get('overlay',[]) or name in {'grass_compare_collect','plant_depth_collect'}:
                        self.assertEqual(archive.read_bytes(),raw)
                witness=json.loads((parent/'open.json').read_text());argv=witness['argv']
                self.assertEqual(witness['cwd'],str(own));self.assertEqual(argv[argv.index('--path')+1],str(own))
                capture='tools/grass_compare/capture.gd' if name=='grass_compare_collect' else 'tools/'+name.removesuffix('_collect')+'_capture.gd'
                self.assertEqual(argv[argv.index('--script')+1],'res://'+self.future_name(capture))
                self.assertFalse(any(p for p in output.rglob('*.png') if not any(part in {'inputs','instrumentation'} for part in p.relative_to(output).parts)))
            for key,raw in stable.items():self.assertEqual((own/'.git'/key).read_bytes(),raw)

    def test_root(self):self.producer('foliage_root_collect')
    def test_uv(self):self.producer('foliage_uv_collect')
    def test_wind(self):self.producer('foliage_wind_collect')
    def test_contact(self):self.producer('foliage_contact_collect')
    def test_speed(self):self.producer('foliage_speed_collect')
    def test_recovery(self):self.producer('foliage_recovery_collect')
    def test_pause(self):self.producer('foliage_pause_collect')
    def test_visibility(self):self.producer('foliage_visibility_collect')
    def test_grass(self):self.producer('grass_compare_collect')
    def test_plant_depth(self):self.producer('plant_depth_collect')


if __name__=='__main__':unittest.main()
