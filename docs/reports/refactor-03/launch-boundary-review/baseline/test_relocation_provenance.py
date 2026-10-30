"""Real source bytes and controlled metadata copies; never new native/FPS evidence."""
import copy
import hashlib
import importlib
import json
from pathlib import Path
import tempfile
import unittest

from tools.assets.contracts.source_paths import current_source
from tools.qa.performance.perf_contract_collect import ROOT

PLAN=json.loads((ROOT/'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())['assignments']
CAPTURE='tools/grass_compare/capture.gd'
SHORE=('tools/shore_kit_canvas.gd','tools/shore_kit_capture.gd')


def module(logical):
    path=current_source(ROOT,'tools/'+logical+'.py')
    return importlib.import_module('.'.join(path.relative_to(ROOT).with_suffix('').parts))


class RelocationProvenanceTests(unittest.TestCase):
    def launch_fixture(self,folder,uri):
        profile='Codex-VRENDER-002-control'
        env={'exit_code':0,'jobs_after':[],'profile':profile,'command':['open','-n','--script',uri]}
        (folder/'environment.json').write_text(json.dumps(env));(folder/'engine.txt').write_text('controlled metadata fixture; no native run\n')
        return profile,env

    def test_grass_legacy_launch_positive_control(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary);profile,env=self.launch_fixture(folder,'res://'+CAPTURE)
            self.assertEqual(module('grass_methods').launch(folder,profile),env)

    def test_grass_complete_canonical_capture_record(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary);profile,env=self.launch_fixture(folder,'res://'+PLAN[CAPTURE]['target'])
            source={'source_paths':{CAPTURE:PLAN[CAPTURE]['target']}}
            self.assertEqual(module('grass_methods').launch(folder,profile,source),env)

    def test_grass_wrong_script_cannot_hide_expected_uri_in_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary);profile,env=self.launch_fixture(folder,'res://tools/wrong.gd')
            env['command']+=['--','res://'+CAPTURE];(folder/'environment.json').write_text(json.dumps(env))
            with self.assertRaises(ValueError):module('grass_methods').launch(folder,profile)

    def test_grass_unknown_partial_or_invalid_capture_record(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary);profile,_=self.launch_fixture(folder,'res://'+PLAN[CAPTURE]['target'])
            for reported in [None,{CAPTURE:'elsewhere.gd'},{CAPTURE:PLAN[CAPTURE]['target'],'unknown':'bad'}]:
                with self.subTest(reported=reported),self.assertRaises(ValueError):
                    module('grass_methods').launch(folder,profile,{'source_paths':reported})

    def source_fixture(self,temporary):
        root=Path(temporary);(root/'project.godot').write_text('; marker\n');(root/'VERSION').write_text('qa\n')
        logical=SHORE[1];path=root/PLAN[logical]['target'];path.parent.mkdir(parents=True)
        raw=current_source(ROOT,logical).read_bytes();path.write_bytes(raw)
        inventory=json.loads((ROOT/'docs/reports/refactor-03/foliage-shared/baseline/inventory.json').read_text())
        return root,logical,path,raw,inventory['sources'][logical]['SHA256']

    def test_shore_exact_current_and_uri_only_legacy_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root,logical,path,raw,legacy=self.source_fixture(temporary)
            proof=module('shore_kit');current=hashlib.sha256(raw).hexdigest()
            self.assertTrue(proof.relocated_source_matches(root,logical,current,legacy=False))
            self.assertTrue(proof.relocated_source_matches(root,logical,legacy,legacy=True))
            self.assertNotEqual(current,legacy)
            self.assertFalse(proof.relocated_source_matches(root,logical,legacy,legacy=False))

    def test_shore_content_tampering_is_not_an_address_move(self):
        with tempfile.TemporaryDirectory() as temporary:
            root,logical,path,raw,legacy=self.source_fixture(temporary)
            path.write_bytes(raw+b'\n# semantic/content edit\n')
            self.assertFalse(module('shore_kit').relocated_source_matches(root,logical,legacy,legacy=True))

    def test_shore_missing_canonical_rejects_stale_old_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            root,logical,path,raw,legacy=self.source_fixture(temporary);path.unlink()
            old=root/logical;old.parent.mkdir(parents=True,exist_ok=True);old.write_bytes(raw)
            self.assertFalse(module('shore_kit').relocated_source_matches(root,logical,legacy,legacy=True))

    def native_metadata(self):
        proof=module('shore_kit');folder=ROOT/proof.REPORT
        return proof,folder,json.loads((folder/'profile.json').read_text()),json.loads((folder/'native/capture.json').read_text())

    def test_shore_actual_legacy_metadata_positive_control(self):
        proof,folder,data,metadata=self.native_metadata()
        self.assertEqual(proof.verify_native(ROOT,folder,data,metadata),[])

    def test_shore_canonical_metadata_keys_and_actual_current_hashes(self):
        proof,folder,data,metadata=self.native_metadata();fixture=copy.deepcopy(metadata)
        for logical in SHORE:
            fixture['sources'].pop('res://'+logical)
            fixture['sources']['res://'+PLAN[logical]['target']]=hashlib.sha256(current_source(ROOT,logical).read_bytes()).hexdigest()
        self.assertEqual(proof.verify_native(ROOT,folder,data,fixture),[])

    def test_shore_mixed_aliases_are_rejected(self):
        proof,folder,data,metadata=self.native_metadata();fixture=copy.deepcopy(metadata)
        for logical in SHORE:
            fixture['sources']['res://'+PLAN[logical]['target']]=hashlib.sha256(current_source(ROOT,logical).read_bytes()).hexdigest()
        self.assertIn('missing capture sources',proof.verify_native(ROOT,folder,data,fixture))


if __name__=='__main__':unittest.main()
