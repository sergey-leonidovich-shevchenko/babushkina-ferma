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
        env={'exit_code':0,'jobs_after':[],'profile':profile,
             'command':['open','-n','--args','--path',str(ROOT),'--script',uri]}
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

    def grass_layouts(self):
        """Exercise both trusted source schemes; payload cannot choose either URI."""
        return [('legacy','res://'+CAPTURE,None),
                ('current','res://'+PLAN[CAPTURE]['target'],{'source_paths':{CAPTURE:PLAN[CAPTURE]['target']}})]

    def check_grass_command(self,command,source,*,accepted):
        """Call the real reader on owned metadata files; no engine or native frames are fabricated."""
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary);profile,env=self.launch_fixture(folder,'unused')
            env['command']=command;(folder/'environment.json').write_text(json.dumps(env))
            if accepted:
                self.assertEqual(module('grass_methods').launch(folder,profile,source),env)
            else:
                with self.assertRaisesRegex(ValueError,'wrong launch'):
                    module('grass_methods').launch(folder,profile,source)

    def test_grass_script_only_in_user_payload_is_rejected(self):
        for layout,uri,source in self.grass_layouts():
            for separator in ['--','++']:
                for engine in [[],['--script=res://tools/wrong.gd'],['-s','res://tools/wrong.gd']]:
                    with self.subTest(layout=layout,separator=separator,engine=engine):
                        command=['open','-n','--args','--path',str(ROOT),*engine,separator,'--script',uri]
                        self.check_grass_command(command,source,accepted=False)

    def test_grass_first_user_separator_ends_engine_arguments(self):
        for layout,uri,source in self.grass_layouts():
            for first,second in [('--','++'),('++','--')]:
                with self.subTest(layout=layout,first=first):
                    command=['open','-n','--args','--path',str(ROOT),first,second,'--script',uri]
                    self.check_grass_command(command,source,accepted=False)

    def test_grass_conflicting_engine_script_forms_are_rejected(self):
        for layout,uri,source in self.grass_layouts():
            for conflicting in [['--script',uri],['--script=res://tools/wrong.gd'],
                                ['-s','res://tools/wrong.gd'],['-s=res://tools/wrong.gd'],['-sres://tools/wrong.gd']]:
                with self.subTest(layout=layout,conflicting=conflicting):
                    command=['open','-n','--args','--script',uri,*conflicting,'--','--output=fixture']
                    self.check_grass_command(command,source,accepted=False)

    def test_grass_correct_engine_script_ignores_payload_flags(self):
        for layout,uri,source in self.grass_layouts():
            for separator in ['--','++']:
                with self.subTest(layout=layout,separator=separator):
                    command=['open','-n','--args','--script',uri,separator,'--script','res://tools/payload.gd',
                             '-s','payload','--script=payload','--headless']
                    self.check_grass_command(command,source,accepted=True)

    def test_grass_headless_engine_remains_rejected(self):
        for layout,uri,source in self.grass_layouts():
            for separator in ['--','++']:
                with self.subTest(layout=layout,separator=separator):
                    command=['open','-n','--args','--headless','--script',uri,separator,'--output=fixture']
                    self.check_grass_command(command,source,accepted=False)

    def test_grass_command_requires_string_arguments(self):
        for layout,uri,source in self.grass_layouts():
            for command in [None,[],['open',7,'--script',uri],['open',{},'--script',uri]]:
                with self.subTest(layout=layout,command=command):
                    self.check_grass_command(command,source,accepted=False)

    def test_grass_wrapped_engine_launch_positive_controls(self):
        for layout,uri,source in self.grass_layouts():
            for separator in [None,'--','++']:
                with self.subTest(layout=layout,separator=separator):
                    command=['open','-n','--args','--path',str(ROOT),'--script',uri]
                    if separator:command.extend([separator,'--output=fixture'])
                    self.check_grass_command(command,source,accepted=True)

    def test_grass_wrapper_options_cannot_supply_engine_script(self):
        for layout,uri,source in self.grass_layouts():
            with self.subTest(layout=layout):
                command=['open','--script',uri,'--args','--path',str(ROOT),'--','--output=fixture']
                self.check_grass_command(command,source,accepted=False)

    def test_grass_raw_engine_launch_positive_control(self):
        for layout,uri,source in self.grass_layouts():
            with self.subTest(layout=layout):
                command=['/fixture/Godot','--path',str(ROOT),'--script',uri,'++','--output=fixture']
                self.check_grass_command(command,source,accepted=True)

    def test_grass_duplicate_wrapper_forwarding_is_rejected(self):
        for layout,uri,source in self.grass_layouts():
            with self.subTest(layout=layout):
                command=['open','--args','--args','--script',uri,'--','--output=fixture']
                self.check_grass_command(command,source,accepted=False)

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
