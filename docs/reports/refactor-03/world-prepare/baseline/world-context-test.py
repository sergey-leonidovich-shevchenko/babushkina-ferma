"""Real World Git readers and source producers; no native window or new FPS admission."""
from contextlib import contextmanager, ExitStack
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import object_command_collect as object_collect
import object_command_verify as object_verify
import pilot_pass_verify as pilot_pass
import pilot_static_audit as pilot_audit
import pilot_static_verify as pilot_static
import post_motion_verify as post_motion
import render_order
import shadow_inventory as shadow
import shadow_inventory_collect as shadow_collect
import shadow_inventory_verify as shadow_verify
import transient_save_verify as transient
import village_bench_verify as bench
import village_board_verify as board
import village_fence_verify as fence
import village_lamp_verify as lamp
import village_street_verify as street
import village_trade_verify as trade
from tools.qa.performance import perf_contract_collect as perf
from tools.common.git import git_environment
from tools.assets.contracts.source_paths import current_source


class BeforeNativeLaunch(Exception):
    """Explicitly stop after real source.json; this is not a native capture."""


class BeforeContactSheets(Exception):
    """Inventory JSON/CSV are real; platform-specific font/sheets are not part of this test."""


class WorldContextTests(unittest.TestCase):
    """Exercise actual Git/hash/archive paths without replacing Git or accepting partial evidence."""

    def git(self, root, *args):
        """Read an explicit fixture repository using a separately cleared environment."""
        return subprocess.check_output(['git','-C',str(root),*args],env=git_environment()).decode().strip()

    def repository(self, root):
        """Create a real foreign repository, index, config and distinct non-project commit."""
        root.mkdir();(root/'foreign.txt').write_text('unrelated world QA repository\n')
        subprocess.run(['git','init','-q',str(root)],env=git_environment(),check=True)
        subprocess.run(['git','-C',str(root),'add','.'],env=git_environment(),check=True)
        subprocess.run(['git','-C',str(root),'-c','user.name=World QA','-c',
                        'user.email=qa@example.invalid','commit','-qm','foreign'],env=git_environment(),check=True)
        return root

    @contextmanager
    def foreign_context(self):
        """Keep the caller environment and the foreign repository's index/config unchanged."""
        with tempfile.TemporaryDirectory(prefix='world foreign Git ')as directory:
            root=self.repository(Path(directory).resolve()/'foreign project')
            before={n:(root/'.git'/n).read_bytes()for n in ['index','config']};cwd=Path.cwd()
            try:
                os.chdir(root)
                with patch.dict(os.environ,GIT_DIR=str(root/'.git'),GIT_WORK_TREE=str(root),
                    GIT_INDEX_FILE=str(root/'.git/index'),GIT_CONFIG_COUNT='1',
                    GIT_CONFIG_KEY_0='core.bare',GIT_CONFIG_VALUE_0='true'):
                    environment=dict(os.environ)
                    yield root
                    self.assertEqual(dict(os.environ),environment)
            finally:
                os.chdir(cwd)
                for name,raw in before.items():self.assertEqual((root/'.git'/name).read_bytes(),raw)

    def test_nested_actual_source_roots(self):
        """Nine real source copies locate their project at arbitrary depth, including paths with spaces."""
        names=['post_motion_verify','render_order','shadow_inventory','village_bench_assets',
               'village_board_assets','village_fence_assets','village_lamp_assets',
               'village_street_assets','village_trade_assets']
        with tempfile.TemporaryDirectory(prefix='world nested project ')as directory:
            root=Path(directory).resolve();(root/'project.godot').write_text('; marker\n');(root/'VERSION').write_text('qa\n')
            nested=root/'tools/qa/world';nested.mkdir(parents=True)
            child=('import importlib.util,json,sys;from pathlib import Path;'
                   'sys.path[:0]=[sys.argv[1],sys.argv[1]+"/tools"];'
                   's=importlib.util.spec_from_file_location("world_nested_probe",sys.argv[2]);'
                   'm=importlib.util.module_from_spec(s);s.loader.exec_module(m);print(json.dumps(str(m.ROOT)))')
            for name in names:
                with self.subTest(module=name):
                    source=current_source(render_order.ROOT,'tools/'+name+'.py');target=nested/source.name
                    target.write_bytes(source.read_bytes())
                    result=subprocess.run([sys.executable,'-c',child,str(render_order.ROOT),str(target)],
                        cwd=root,env=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1'),capture_output=True,text=True,timeout=30)
                    self.assertEqual(result.returncode,0,result.stderr)
                    self.assertEqual(Path(json.loads(result.stdout)),root)

    def prop_reader(self, module):
        """Both immutable archived phases must be returned exactly, with real base/index/hash checks."""
        with self.foreign_context():
            for phase in ['before','after']:
                with self.subTest(phase=phase):
                    folder=module.REPORT/'native'/phase
                    self.assertEqual(module.provenance(folder,phase),json.loads((folder/'source.json').read_text()))

    def test_bench_archive_under_foreign_git(self):
        """Bench's historical blobs and tracked native proof use their own repository."""
        self.prop_reader(bench)

    def test_board_archive_under_foreign_git(self):
        """Board's two complete phases retain every source/artifact signature."""
        self.prop_reader(board)

    def test_fence_archive_under_foreign_git(self):
        """Fence's Git commit/index checks ignore caller overrides."""
        self.prop_reader(fence)

    def test_lamp_archive_under_foreign_git(self):
        """Lamp's existing native archives are read without modifying them."""
        self.prop_reader(lamp)

    def test_street_archive_under_foreign_git(self):
        """Already repaired street reader remains a positive control."""
        self.prop_reader(street)

    def test_trade_archive_under_foreign_git(self):
        """Trade's original source coverage and artifact/index policy remain exact."""
        self.prop_reader(trade)

    def test_render_order_archive_under_foreign_git(self):
        """The real historical rendering verifier still accepts exactly its preserved report."""
        with self.foreign_context():
            self.assertEqual(render_order.verify(),json.loads((render_order.REPORT/'summary.json').read_text()))

    def test_object_archive_under_foreign_git(self):
        """Descriptor provenance retains real Git blobs, overlay constraints and indexed artifacts."""
        folder=object_verify.REPORT/'native'
        with self.foreign_context():
            self.assertEqual(object_verify.provenance(folder),json.loads((folder/'source.json').read_text()))

    def test_pilot_pass_archive_under_foreign_git(self):
        """Both source-bound pass phases enforce the same one-adapter production diff."""
        with self.foreign_context():
            for phase in ['before','after']:
                self.assertEqual(pilot_pass.provenance(phase),json.loads((pilot_pass.REPORT/'native'/phase/'source.json').read_text()))

    def test_static_archive_under_foreign_git(self):
        """Static archive preserves the repaired historical alias and own Git-index requirement."""
        with self.foreign_context():
            self.assertEqual(pilot_static.provenance(),json.loads((pilot_static.REPORT/'native/static/source.json').read_text()))

    def test_dependency_audit_under_foreign_git(self):
        """All51 canonical predecessor claims still resolve to exact evidence at the old base."""
        with self.foreign_context():
            self.assertEqual(pilot_audit.verify(),json.loads((pilot_audit.REPORT/'dependency-audit.json').read_text()))

    def test_post_motion_archive_under_foreign_git(self):
        """Both post-motion phases retain exact source changes and native artifact signatures."""
        with self.foreign_context():
            for phase in ['before','after']:
                folder=post_motion.REPORT/'native'/phase
                self.assertEqual(post_motion.validate_source(folder,phase),json.loads((folder/'source.json').read_text()))

    def test_transient_archive_under_foreign_git(self):
        """Accepted asset tree/full script coverage/save diff remain bound to the historical base."""
        transient.blob.cache_clear()
        try:
            with self.foreign_context():
                changes=json.loads((transient.REPORT/'changes.json').read_text())
                for phase in ['before','after']:
                    folder=transient.REPORT/'native'/phase
                    self.assertEqual(transient.provenance(folder,phase,changes),json.loads((folder/'source.json').read_text()))
        finally:transient.blob.cache_clear()

    def test_shadow_archive_under_foreign_git(self):
        """Complete raster ownership/native contacts still use real historical Git blobs and tree."""
        shadow_verify.git.cache_clear()
        try:
            with self.foreign_context():
                self.assertEqual(shadow_verify.verify(),json.loads((shadow_verify.REPORT/'summary.json').read_text()))
        finally:shadow_verify.git.cache_clear()

    def test_fresh_render_contract_uses_own_git(self):
        """The real writer authors fresh JSON only in owned scratch; source SHA and own commit are real."""
        expected=self.git(render_order.ROOT,'rev-parse','HEAD')
        with tempfile.TemporaryDirectory(prefix='world fresh contract ')as directory:
            report=Path(directory).resolve()
            with patch.object(render_order,'REPORT',report),self.foreign_context():render_order.build_contract()
            source=json.loads((report/'contract.json').read_text())
            self.assertEqual(source['base_commit'],expected)
            self.assertEqual(source['sources'],{n:hashlib.sha256((render_order.ROOT/n).read_bytes()).hexdigest()for n in render_order.SOURCES})

    def test_fresh_shadow_inventory_uses_own_git(self):
        """Real inventory JSON/CSV writes precede the explicitly stopped platform-specific contact sheets."""
        expected=self.git(shadow.ROOT,'rev-parse','HEAD')
        with tempfile.TemporaryDirectory(prefix='world fresh inventory ')as directory:
            report=Path(directory).resolve()
            with patch.object(shadow,'REPORT',report),patch.object(shadow.ImageFont,'truetype',side_effect=BeforeContactSheets),self.foreign_context():
                with self.assertRaises(BeforeContactSheets):shadow.build()
            source=json.loads((report/'inventory.json').read_text())
            self.assertEqual(source['base_commit'],expected)
            self.assertEqual({r['file']:r['sha256']for r in source['assets']},
                {n:hashlib.sha256((shadow.ROOT/n).read_bytes()).hexdigest()for n in shadow.paths()})
            self.assertTrue((report/'inventory.csv').stat().st_size>100)
            self.assertEqual(list(report.glob('*.png')),[])

    def producer_envelope(self,module):
        """Stop an actual collector after real source/hash/Git/copy, before any native Popen/context."""
        original=render_order.ROOT
        with tempfile.TemporaryDirectory(prefix='world actual producer ')as directory:
            parent=Path(directory).resolve();own=parent/'own project';own.mkdir()
            names=set(object_collect.SOURCES)if module is object_collect else set(shadow_collect.QA)|{'scripts/probe.gd','project.godot','main.tscn','assets/game/probe.txt','VERSION'}
            names.add('VERSION')
            for name in names:
                target=own/name;target.parent.mkdir(parents=True,exist_ok=True)
                raw=(b'extends Node\n'if name=='scripts/probe.gd'else b'asset fixture\n'if name=='assets/game/probe.txt'else current_source(original,name).read_bytes())
                target.write_bytes(raw)
            subprocess.run(['git','init','-q',str(own)],env=git_environment(),check=True)
            subprocess.run(['git','-C',str(own),'add','.'],env=git_environment(),check=True)
            subprocess.run(['git','-C',str(own),'-c','user.name=World QA','-c','user.email=qa@example.invalid','commit','-qm','own sources'],env=git_environment(),check=True)
            expected=self.git(own,'rev-parse','HEAD');output=parent/'new source envelope'
            # Object checks context before Popen; shadow first inspects jobs after writing source.json.
            # Stop at those precise prelaunch boundaries; Git, SHA and copies remain real.
            stop='context'if module is object_collect else'jobs'
            with patch.object(module,'ROOT',own),patch.object(perf,'ROOT',own),patch.object(module,stop,side_effect=BeforeNativeLaunch),self.foreign_context():
                try:
                    if module is object_collect:module.collect(output,static_coexistence=True)
                    else:module.collect(output)
                except BeforeNativeLaunch:pass
                self.assertTrue((output/'source.json').is_file())
                source=json.loads((output/'source.json').read_text());self.assertEqual(source['base_commit'],expected)
                self.assertFalse(source['complete']);self.assertFalse(source['performance_eligible'])
                for name,digest in source['sources'].items():
                    self.assertEqual(digest,hashlib.sha256((own/name).read_bytes()).hexdigest())
                    if module is object_collect:
                        self.assertEqual(source['base_sources'][name],digest)
                        self.assertEqual((output/'inputs'/name).read_bytes(),(own/name).read_bytes())
                if module is shadow_collect:
                    self.assertEqual(source['production'],['scripts/probe.gd'])
                    self.assertEqual(source['asset_tree'],self.git(own,'rev-parse',expected+':assets/game'))
                    for name in source['overlay']:self.assertEqual((output/'inputs'/name).read_bytes(),(own/name).read_bytes())
                with self.assertRaises((ValueError,FileNotFoundError)):
                    if module is object_collect:object_verify.provenance(output)
                    else:shadow_verify.verify(output)
                before=(output/'source.json').read_bytes()
                with self.assertRaises(ValueError):module.collect(output)
                self.assertEqual((output/'source.json').read_bytes(),before)

    def test_fresh_object_source_envelope(self):
        """Actual object collector must preserve own base-source digests under foreign Git overrides."""
        self.producer_envelope(object_collect)

    def test_fresh_shadow_source_envelope(self):
        """Actual shadow collector validates its own production bytes before the explicit native stop."""
        self.producer_envelope(shadow_collect)


if __name__=='__main__':unittest.main()
