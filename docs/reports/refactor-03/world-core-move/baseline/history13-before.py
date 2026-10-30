"""Actual World readers on real Git/capsule bytes in a future canonical tree; input-only, never native proof."""
from contextlib import redirect_stdout
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import object_command_verify as objects
import pilot_pass_verify as pilot_pass
import pilot_static_verify as static
import post_motion_verify as motion
import render_order
import village_bench_verify as bench
import village_board_verify as board
import village_fence_verify as fence
import village_lamp_verify as lamp
import village_street_verify as street
import village_trade_verify as trade
import plant_depth_verify as plant_depth
from tools.assets.contracts.source_paths import MOVED_PATHS
from tools.qa.art.current_paths import MOVED_PATHS as ART_PATHS
from tools.qa.world import test_world_context as context_fixtures
from tools.common.git import git_environment


class WorldSourceHistoryTests(unittest.TestCase):
    """Exercise real consumers/Git and distinguish complete inputs from a complete native capture."""
    git = context_fixtures.WorldContextTests.git
    repository = context_fixtures.WorldContextTests.repository
    foreign_context = context_fixtures.WorldContextTests.foreign_context

    def fixture_name(self, name):
        """Use the accepted immutable migration plan as an independent fixture address reference."""
        plan=json.loads((render_order.ROOT/'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())
        row=plan['assignments'].get(name)
        if row and row['family']=='world'and row['action']in{'move','move_uid_with_source'}:
            return row['target']
        targets={mapping[name]for mapping in[MOVED_PATHS,ART_PATHS]if name in mapping}
        self.assertLessEqual(len(targets),1)
        return next(iter(targets),name)

    def source_fixture(self, module, own, report, phase='before'):
        """Copy exact real archived input bytes, not fabricated frames, into a distinct actual Git commit."""
        flat=module in[objects,render_order]
        original=module.REPORT/'native'if flat else module.REPORT/'native'/phase
        if module is static:original=module.REPORT/'native/static'
        source=json.loads((original/'source.json').read_text())
        archive='instrumentation'if module is render_order else'inputs'
        for name,digest in source['sources'].items():
            raw=(original/archive/name).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            target=own/self.fixture_name(name);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
        subprocess.run(['git','-C',str(own),'add','.'],env=git_environment(),check=True)
        subprocess.run(['git','-C',str(own),'-c','user.name=World source QA','-c','user.email=qa@example.invalid','commit','-qm','canonical source-only tree'],env=git_environment(),check=True)
        base=self.git(own,'rev-parse','HEAD')
        folder=report/'native'if flat else report/'native'/phase
        if module is static:folder=report/'native/static'
        folder.mkdir(parents=True)
        for name in source['sources']:
            target=folder/archive/name;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((original/archive/name).read_bytes())
        source['base_commit']=base
        source['artifacts']={}
        source['fixture_scope']={'complete_inputs':True,'native_frames':0,'native_capture':False,'performance_eligible':False}
        if'base_sources'in source:source['base_sources']=dict(source['sources'])
        if module in [motion,plant_depth]:
            for width in[1152,1280]:
                target=folder/str(width);target.mkdir()
                (target/'environment.json').write_text(json.dumps({'exit_code':0,'fixture_scope':'input-only; no native process'})+'\n')
                (target/'engine.txt').write_text('Explicit source-only fixture; no engine was started.\n')
            source['artifacts']={str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest()for p in folder.rglob('*')if p.is_file()and archive not in p.parts}
        (folder/'source.json').write_text(json.dumps(source,indent=2)+'\n')
        if module is render_order:
            contract=json.loads((module.REPORT/'contract.json').read_text());contract['base_commit']=base
            (report/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')
        subprocess.run(['git','-C',str(own),'add','.'],env=git_environment(),check=True)
        self.assertFalse(any(p for p in folder.rglob('*.png')if archive not in p.relative_to(folder).parts))
        return folder,source

    def check_reader(self, module):
        """A future Git tree must accept the unchanged logical input namespace, while full native proof refuses."""
        with tempfile.TemporaryDirectory(prefix='world source history ')as directory:
            own=self.repository(Path(directory).resolve()/'owned project')
            report=own/'docs/reports/source-only-fixture'
            folder,source=self.source_fixture(module,own,report)
            before={name:(own/'.git'/name).read_bytes()for name in['index','config']}
            with patch.object(module,'ROOT',own),patch.object(module,'REPORT',report),self.foreign_context():
                if module in[bench,board,fence,lamp,street,trade]:result=module.provenance(folder,'before')
                elif module is objects:result=module.provenance(folder)
                elif module is pilot_pass:result=module.provenance('before')
                elif module is static:result=module.provenance()
                elif module is motion:result=module.validate_source(folder,'before')
                elif module is plant_depth:
                    changes=json.loads((render_order.ROOT/'docs/reports/visual-overhaul/vrender-006/changes.json').read_text())
                    changes['base_commit']=source['base_commit']
                    result=module.validate_source(folder,'before',changes)
                else:
                    with self.assertRaises(FileNotFoundError)as missing:module.verify(folder)
                    self.assertEqual(Path(missing.exception.filename).name,'capture.json')
                    result=source
                self.assertEqual(result,source)
                self.assertEqual(result['fixture_scope']['native_frames'],0)
                self.assertFalse(result['fixture_scope']['performance_eligible'])
                if'performance_eligible'in result:self.assertIs(result['performance_eligible'],False)
                if module is not render_order:
                    with redirect_stdout(io.StringIO()),self.assertRaises((FileNotFoundError,ValueError)):
                        if module in [motion,plant_depth]:module.verify(report)
                        else:module.verify()
            for name,raw in before.items():self.assertEqual((own/'.git'/name).read_bytes(),raw)

    def test_bench_reads_new_git_alias_with_old_archive_keys(self):
        """Actual bench provenance uses canonical Git blobs while inputs retain exact old keys."""
        self.check_reader(bench)

    def test_board_reads_new_git_alias_with_old_archive_keys(self):
        """Actual board provenance keeps its exact coverage and artifact/index checks."""
        self.check_reader(board)

    def test_fence_reads_new_git_alias_with_old_archive_keys(self):
        """Actual fence provenance reaches the same complete input envelope in the new Git tree."""
        self.check_reader(fence)

    def test_lamp_reads_new_git_alias_with_old_archive_keys(self):
        """Actual lamp provenance cannot require a deleted physical legacy tool."""
        self.check_reader(lamp)

    def test_street_reads_new_git_alias_with_old_archive_keys(self):
        """Already Git-isolated street provenance still needs the exact moved-source alias."""
        self.check_reader(street)

    def test_trade_reads_new_git_alias_with_old_archive_keys(self):
        """Actual trade provenance uses the pinned new tree without live fallback."""
        self.check_reader(trade)

    def test_object_reads_new_git_alias_with_old_archive_keys(self):
        """Actual object provenance preserves base_sources and optional overlay policy."""
        self.check_reader(objects)

    def test_pilot_pass_reads_new_git_alias_with_old_archive_keys(self):
        """Actual pilot pass source checker retains phase/source/index policy."""
        self.check_reader(pilot_pass)

    def test_static_reads_new_git_alias_with_old_archive_keys(self):
        """Actual static source checker composes its old art contract with the World aliases."""
        self.check_reader(static)

    def test_post_motion_reads_new_git_alias_with_old_archive_keys(self):
        """Actual post-motion source checker retains all source and artifact hashes without fake native frames."""
        self.check_reader(motion)

    def test_render_order_passes_source_checks_before_refusing_missing_frames(self):
        """Actual contract/instrumentation/Git checks finish before the deliberate no-capture refusal."""
        self.check_reader(render_order)

    def test_water_folder_follows_nested_source_project(self):
        """Actual water analyzer locates report output under its own project rather than a fixed parent."""
        with tempfile.TemporaryDirectory(prefix='water nested source ')as directory:
            root=Path(directory).resolve();(root/'project.godot').write_text('; marker\n');(root/'VERSION').write_text('qa\n')
            target=root/'tools/qa/world/analyze_water_audit.py';target.parent.mkdir(parents=True)
            target.write_bytes((render_order.ROOT/'tools/analyze_water_audit.py').read_bytes())
            child=('import importlib.util,json,sys;sys.path[:0]=[sys.argv[1],sys.argv[1]+"/tools"];'
                   's=importlib.util.spec_from_file_location("water_source_probe",sys.argv[2]);'
                   'm=importlib.util.module_from_spec(s);s.loader.exec_module(m);print(json.dumps(str(m.FOLDER)))')
            result=subprocess.run([sys.executable,'-c',child,str(render_order.ROOT),str(target)],cwd=root,
                env=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1'),capture_output=True,text=True,timeout=30)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(Path(json.loads(result.stdout)),root/'docs/reports/water-2026-10')


    def test_plant_depth_reads_new_git_alias_with_old_archive_keys(self):
        """The real external reader binds inherited canonical World blobs to unchanged archive keys."""
        plant_depth.git_blob.cache_clear()
        try:self.check_reader(plant_depth)
        finally:plant_depth.git_blob.cache_clear()


if __name__=='__main__':unittest.main()
