"""Real Foliage archives under foreign Git and nested source roots; no frames or Game launch."""
import importlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.assets.contracts.source_paths import current_source
from tools.common.git import git_environment
from tools.qa.performance.perf_contract_collect import ROOT
from tools.qa.world import test_world_context as fixtures


class BeforeFrameAnalysis(Exception):
    """Stop only after real Git/source/artifact checks, before expensive native frame analysis."""


def load_reader(name):
    """Locate the actual implementation; the test source is identical before and after relocation."""
    path=current_source(ROOT,'tools/'+name+'.py')
    return importlib.import_module('.'.join(path.relative_to(ROOT).with_suffix('').parts))


class FoliageContextTests(unittest.TestCase):
    git=fixtures.WorldContextTests.git
    repository=fixtures.WorldContextTests.repository
    foreign_context=fixtures.WorldContextTests.foreign_context

    def reader_boundary(self,name,boundary,folder=None):
        """Never replace Git, source bytes, artifact hashes, metadata or foreign index/config."""
        module=load_reader(name)
        for field in ['blob','git_blob']:
            function=getattr(module,field,None)
            if hasattr(function,'cache_clear'):function.cache_clear()
        if folder is None:
            folder=module.REPORT/('review-1/native' if name=='foliage_recovery_verify' else
                'native-windowed' if name=='foliage_pause_verify' else 'native')
        source=folder/'source.json';before=source.read_bytes()
        with patch.object(module,boundary,side_effect=BeforeFrameAnalysis),self.foreign_context():
            with self.assertRaises(BeforeFrameAnalysis):module.verify(folder)
        self.assertEqual(source.read_bytes(),before)

    def test_contact_source_before_pixels(self):
        self.reader_boundary('foliage_contact_verify','pixels')

    def test_pause_source_before_pixels(self):
        self.reader_boundary('foliage_pause_verify','pixels')

    def test_recovery_source_before_pixels(self):
        self.reader_boundary('foliage_recovery_verify','pixels')

    def test_root_source_before_frames(self):
        self.reader_boundary('foliage_root_verify','frames')

    def test_speed_source_before_pixels(self):
        self.reader_boundary('foliage_speed_verify','pixels')

    def test_uv_source_before_frames(self):
        self.reader_boundary('foliage_uv_verify','records')

    def test_visibility_source_before_coverage(self):
        module=load_reader('foliage_visibility_verify')
        self.reader_boundary('foliage_visibility_verify','verify_coverage',module.REPORT/'native')

    def test_wind_source_before_pixels(self):
        self.reader_boundary('foliage_wind_verify','pixels')

    def test_plant_depth_source_before_frames(self):
        module=load_reader('plant_depth_verify')
        # This reader owns a report with two separate native source envelopes.
        before={phase:(module.REPORT/'native'/phase/'source.json').read_bytes() for phase in ['before','after']}
        module.git_blob.cache_clear()
        with patch.object(module,'capture',side_effect=BeforeFrameAnalysis),self.foreign_context():
            with self.assertRaises(BeforeFrameAnalysis):module.verify()
        for phase,raw in before.items():self.assertEqual((module.REPORT/'native'/phase/'source.json').read_bytes(),raw)

    def test_grass_source_under_foreign_git(self):
        module=load_reader('grass_methods');folder=module.REPORT/'quality'
        before=(folder/'source.json').read_bytes()
        with self.foreign_context():result=module.provenance(folder,'quality')
        self.assertIsNotNone(result)
        self.assertEqual((folder/'source.json').read_bytes(),before)

    def test_four_actual_nested_source_roots(self):
        """Run real copied modules in a separate process; dependencies/Git are never mocked."""
        child=('import importlib.util,json,sys;'
            's=importlib.util.spec_from_file_location("foliage_nested_probe",sys.argv[1]);'
            'm=importlib.util.module_from_spec(s);sys.modules[s.name]=m;s.loader.exec_module(m);'
            'print(json.dumps(str(m.ROOT)))')
        with tempfile.TemporaryDirectory(prefix='foliage nested project ') as directory:
            root=Path(directory).resolve();(root/'project.godot').write_text('; marker\n');(root/'VERSION').write_text('qa\n')
            nested=root/'tools/qa/foliage';nested.mkdir(parents=True)
            for name in ['foliage_wind_verify','foliage_pause_verify','foliage_visibility_evidence','plant_depth_verify']:
                with self.subTest(module=name):
                    source=current_source(ROOT,'tools/'+name+'.py');target=nested/source.name;target.write_bytes(source.read_bytes())
                    result=subprocess.run([sys.executable,'-c',child,str(target)],cwd=root,
                        env=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1'),capture_output=True,text=True,timeout=30)
                    self.assertEqual(result.returncode,0,result.stderr)
                    self.assertEqual(Path(json.loads(result.stdout)),root)


if __name__=='__main__':unittest.main()
