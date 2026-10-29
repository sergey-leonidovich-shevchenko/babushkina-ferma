"""Seal actual targeted compile/source proofs without rewriting the failed first gate."""
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/ground-move'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
sha=lambda b:hashlib.sha256(b).hexdigest()
engine=os.environ['FARM_GODOT_BIN']
patch=json.loads((R/'source-bridge-patch.json').read_text())
names=list(patch)+['tools/qa/ground/compiled_sources.gd','tools/qa/ground/compiled_sources_review.gd']
rows=[]
for name in names:
    log=Path('/private/tmp')/('refactor03-bridge379-'+Path(name).stem+'.engine.log')
    result=subprocess.run([engine,'--headless','--path',str(Q),'--log-file',str(log),
        '--check-only','--script','res://'+name],capture_output=True,timeout=60)
    raw=result.stdout+result.stderr
    assert result.returncode==0 and b'ERROR' not in raw,(name,raw)
    target='bridge-compile-'+Path(name).stem+'.txt.gz'
    stored=gzip.compress(raw,mtime=0);(R/target).write_bytes(stored)
    rows.append({'source':name,'source_SHA256':sha((Q/name).read_bytes()),'exit':0,
        'log':target,'raw_SHA256':sha(raw),'stored_SHA256':sha(stored)})
resources=[]
for folder in ['ground_masks','axial_road_masks','road_network_masks','plaza_masks']:
    for path in sorted((Q/'assets/game/locations/overworld'/folder).glob('*.res')):
        name=str(path.relative_to(Q)); old=subprocess.check_output(['git','show','HEAD:'+name],cwd=Q,env=git_environment())
        assert old==path.read_bytes(),name
        resources.append({'path':name,'SHA256':sha(old),'unchanged':True})
assert len(resources)==9
raw=(R/'source-bridge-test-attempt02.txt').read_bytes()
assert b'Ran 2 tests' in raw and b'\nOK\n' in raw and b'provenance: 101 checks, 0 failed' in raw and b'fresh: 36 checks, 0 failed' in raw
uid={name:sha((Q/name).read_bytes()) for name in ['tools/qa/ground/compiled_sources.gd.uid','tools/qa/ground/compiled_sources_review.gd.uid']}
assert len(set(uid.values()))==2
editor=[]
for suffix in ['stdout','engine.log']:
    path=Path('/private/tmp/refactor03-bridge-editor379.'+suffix)
    target='bridge-editor-'+suffix+'.gz';data=path.read_bytes();stored=gzip.compress(data,mtime=0);(R/target).write_bytes(stored)
    editor.append({'log':target,'raw_SHA256':sha(data),'stored_SHA256':sha(stored)})
record={'phase':'source hash bridge after actual gate01 failures','source_patch':'source-bridge-patch.json',
    'tests':2,'provenance_checks':101,'fresh_checks':36,'fresh_masks':9,'targeted_compiles':rows,
    'test_log':'source-bridge-test-attempt02.txt','test_log_SHA256':sha(raw),'runtime_resources':resources,
    'new_QA_UID':uid,'UID_preserved':302,'all_tools_UID':304,'editor_logs':editor,
    'editor_log_limit':'exit0 UID discovery, but sandbox CA/settings errors retained; not a clean editor admission',
    'before_freeze_retained':'before-source-bridge/source-freeze.json','native_frames':0,'FPS_admission':False}
(R/'source-bridge-checks.json').write_text(json.dumps(record,indent=2)+'\n')
shutil.copy2(__file__,R/'check-source-bridge.py')
shutil.copy2('/private/tmp/refactor03-bridge-docs379.py',R/'write-bridge-docs.py')
print(json.dumps({'compiled':len(rows),'runtime_resources_unchanged':len(resources),'tests':2,'checks':137}))
