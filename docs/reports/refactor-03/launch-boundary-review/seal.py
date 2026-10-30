"""Seal the bounded P2 correction only after the actual full gates finish."""
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
from PIL import Image

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/launch-boundary-review'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment

def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name):return json.loads((R/name).read_text())
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args],env=git_environment())
def raw(name):
    p=R/name
    return p.read_bytes() if p.exists() else gzip.decompress(Path(str(p)+'.gz').read_bytes())
def outer(blob):
    a,b=blob.index(b'## REFACTOR-03 '),blob.index(b'## REFACTOR-04 ')
    return blob[:a],blob[b:]

freeze=load('source-freeze.json');sources=freeze['source_SHA256'];baseline=load('baseline/UID-and-foreign.json')
assert git(Q,'rev-parse','HEAD').decode().strip()==freeze['base']
assert (R/'baseline/grass_methods.py').read_bytes()==git(Q,'show',freeze['base']+':tools/qa/foliage/grass_methods.py')
assert (R/'current-grass_methods.py').read_bytes()==(Q/'tools/qa/foliage/grass_methods.py').read_bytes()
assert len(sources)==8 and all(sha((Q/n).read_bytes())==h for n,h in sources.items())
assert all(sha((R/n).read_bytes())==h for n,h in freeze['report_content_inputs'].items())
changed=set(filter(None,git(Q,'diff','--no-renames','--name-only','-z').decode().split('\0')))
changed.update(filter(None,git(Q,'ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in sources or n.startswith(str(R.relative_to(Q))+'/') for n in changed)
assert outer((Q/'docs/epics/refactoring-2026-10/TASKS.md').read_bytes())==outer(git(Q,'show',freeze['base']+':docs/epics/refactoring-2026-10/TASKS.md'))
UID={str(p.relative_to(Q)):{'SHA256':sha(p.read_bytes()),'mode':stat.S_IMODE(p.stat().st_mode)} for p in (Q/'tools').rglob('*.uid') if p.is_file()}
assert UID==baseline['UID'] and len(UID)==304
for name,row in baseline['primary_foreign'].items():
    assert sha((P/name).read_bytes())==row['working_SHA256'],name
    assert sha(git(P,'show',':'+name))==row['index_SHA256'],name
coverage=json.loads((Q/'docs/reports/refactor-03/foliage-shared/full-plan-coverage.json').read_text())
assert coverage['original_rows_accounted_for']==779
suffixes={'.py','.gd','.gdshader','.swift','.sh'}
roots=sorted(str(p.relative_to(Q)) for p in (Q/'tools').iterdir() if p.is_file() and p.suffix in suffixes)
assert roots==coverage['root_sources'] and len(roots)==11
assert load('source-contract-audit.json')['fields']==37
bounded=load('bounded-change-audit.json')
assert bounded['all_non_launch_AST_equal'] and bounded['old_test_methods_unchanged']==10
assert sha((Q/'tools/qa/foliage/test_relocation_provenance.py').read_bytes())==bounded['same_red_green_test_SHA256']
assert (R/'baseline/test_red_green.py').read_bytes()==(Q/'tools/qa/foliage/test_relocation_provenance.py').read_bytes()
assert 'Ran 20 tests' in raw('parent-red.txt').decode() and 'FAILED (failures=32, errors=4)' in raw('parent-red.txt').decode()
assert 'Ran 20 tests' in raw('current-green.txt').decode() and raw('current-green.txt').decode().rstrip().endswith('OK')
assert 'Ran 20 tests' in raw('repro-parent-red.txt').decode() and 'FAILED (failures=32, errors=4)' in raw('repro-parent-red.txt').decode()
assert 'Ran 20 tests' in raw('repro-current-green.txt').decode() and raw('repro-current-green.txt').decode().rstrip().endswith('OK')
assert 'Ran 18 tests' in raw('old-grass-controls.txt').decode() and raw('old-grass-controls.txt').decode().rstrip().endswith('OK')
matrix=load('reviewer-matrix-replay.json')
assert len(matrix['rows'])==12 and matrix['valid_accepted']==4 and matrix['invalid_rejected']==8 and matrix['parent_false_accepts']==8
assert all(r['current_accept']==r['expected_accept'] for r in matrix['rows'])
assert sha((Q/'tools/qa/foliage/grass_methods.py').read_bytes())==matrix['current_source_SHA256']
assert sha(raw('historical-current.txt'))==bounded['historical_stdout_SHA256']
gates=load('gates-01/gate-exits.json')
assert [g['gate'] for g in gates]==['wiki','architecture','game']
assert all(g['exit']==0 and g['version']=='0.0.381' for g in gates)
counts=list(map(int,re.findall(r'^Ran (\d+) tests? in ',raw('gates-01/architecture.txt').decode(),re.M)))
assert (len(counts),sum(counts))==(107,1414),(len(counts),sum(counts))
game=raw('gates-01/game.txt').decode()
assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed')==2
wiki=raw('gates-01/wiki.txt').decode();assert 'ℹ pass 145' in wiki and 'ℹ fail 0' in wiki
browser=load('browser.json')
for name,width,height in [('desktop',1280,900),('mobile',390,844)]:
    data=browser[name];assert data['version'] and data['width']==data['scrollWidth']==width and data['height']==height
    assert Image.open(R/('browser-'+name+'.jpg')).size==(width,height)
assert all(browser['card'][k] for k in ['in_progress','candidate381','pr'])
assert load('browser-link-http.json')['exact_report_bytes']
cleanup=load('browser-cleanup.json');assert cleanup['own_server_exit']==143 and cleanup['own_tab_closed']=='27' and cleanup['viewport_reset']
assert cleanup['retake']['own_server_exit']==143 and cleanup['retake']['own_tab_closed']=='28' and cleanup['retake']['viewport_reset']
assert (Q/'VERSION').read_text().strip()=='0.0.381'
with (R/'README.md').open('a') as stream:
    stream.write('\nФактический итог gates-01 на зафиксированном кандидате381: architecture107 suites/1414 cases, Game53502/0, normal/F10 по90/0, Wiki145/0; все три команды exit0. Проверки и полный raw относятся к восьми source SHA из source-freeze.json. Это готовность к независимому exact-head ревью/CI, а не завершённая приёмка или merge03.\n')
transcoding=[]
for path in sorted(R.rglob('*.txt')):
    data=path.read_bytes();packed=gzip.compress(data,mtime=0);target=Path(str(path)+'.gz')
    assert not target.exists();target.write_bytes(packed);path.unlink()
    transcoding.append({'raw_path':str(path.relative_to(R)),'stored_path':str(target.relative_to(R)),
        'raw_SHA256':sha(data),'stored_SHA256':sha(packed),'raw_bytes_changed':False})
(R/'raw-log-transcoding.json').write_text(json.dumps(transcoding,indent=2)+'\n')
for source,name in [(__file__,'seal.py'),('/private/tmp/refactor03-publish381.py','publish.py')]:shutil.copy2(source,R/name)
files=[{'path':str(p.relative_to(R)),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size} for p in sorted(R.rglob('*')) if p.is_file() and p.name!='checks.json']
checks={'task':'REFACTOR-03','version':'0.0.381','phase':'P2 engine/user launch boundary','base':freeze['base'],
    'source_SHA256':sources,'removed_source_paths':[],'physical_moves':0,'UID_bytes_mode_preserved':304,
    'old_test_methods_unchanged':10,'new_test_methods':10,'new_semantic_subcases':54,
    'same_test_parent_red':{'tests':20,'failed_subtests':32,'errors':4},'current_green':20,'old_controls':18,
    'reviewer_matrix':{'correct_accepted':4,'invalid_rejected':8},'historical_stdout_equal':True,
    'architecture_suites':107,'architecture_cases':1414,'Game_passed':53502,'Game_failed':0,'normal_F10_each':90,'Wiki_passed':145,
    'root_sources':11,'root_budget':30,'map':491,'original_plan_rows_accounted_for':779,'frozen_contract_fields':37,
    'new_native_frames':0,'FPS_admission':False,'full03_source_scope_complete':True,'full03_done':False,
    'Task_Complete':False,'main_changed':False,'current_head_review_CI':'required; parent380 CHANGES REQUESTED',
    'report_files':files}
(R/'checks.json').write_text(json.dumps(checks,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'sources':len(sources),'report_files':len(files)+1,'architecture':[107,1414],'Game':53502,'Wiki':145,'reviewer_matrix':[4,8]}))
