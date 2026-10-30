"""Run the identical current regression file against the verified parent or current reader."""
import argparse
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').is_file())
REPORT=Path(__file__).resolve().parent
sys.path[:0]=[str(ROOT),str(ROOT/'tools')]
from tools.common.git import git_environment
from tools.qa.foliage import grass_methods, test_relocation_provenance

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reader',choices=['parent','current'],required=True)
args=parser.parse_args()
test_path=ROOT/'tools/qa/foliage/test_relocation_provenance.py'
assert test_path.read_bytes()==(REPORT/'baseline/test_red_green.py').read_bytes()
if args.reader=='parent':
    source=REPORT/'baseline/grass_methods.py'
    recorded=subprocess.check_output(['git','-C',str(ROOT),'show',
        '2c856d7d3d0a185735f17bdc5fa3f8c258b836d8:tools/qa/foliage/grass_methods.py'],env=git_environment())
    assert source.read_bytes()==recorded
    spec=importlib.util.spec_from_file_location('verified_parent_reader381',source)
    reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
else:
    reader=grass_methods
original=test_relocation_provenance.module
test_relocation_provenance.module=lambda name:reader if name=='grass_methods' else original(name)
print('reader='+args.reader+' test_SHA256='+hashlib.sha256(test_path.read_bytes()).hexdigest(),flush=True)
suite=unittest.defaultTestLoader.loadTestsFromModule(test_relocation_provenance)
result=unittest.TextTestRunner(verbosity=1).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
