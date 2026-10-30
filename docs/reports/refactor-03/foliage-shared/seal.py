"""Seal the full03 source candidate and actual results; independent exact-head review/CI remain external."""
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
R=Q/'docs/reports/refactor-03/foliage-shared'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment

def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name):return json.loads((R/name).read_text())
def git(*args):return subprocess.check_output(['git','-C',str(Q),*args],env=git_environment())
def log(name):
 path=R/name
 return path.read_bytes() if path.exists() else gzip.decompress(Path(str(path)+'.gz').read_bytes())

freeze=load('source-freeze.json');baseline=load('baseline/inventory.json');plan=load('move-plan.json')
sources=freeze['source_SHA256'];removed=freeze['removed_paths']
assert git('rev-parse','HEAD').decode().strip()==freeze['base']==plan['base']
assert len(sources)==217 and len(removed)==111
assert all(sha((Q/n).read_bytes())==h for n,h in sources.items())
assert all(not (Q/n).exists() for n in removed)
changed=set(filter(None,git('diff','--no-renames','--name-only','-z').decode().split('\0')))
changed.update(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in sources or n in removed or n.startswith(str(R.relative_to(Q))+'/') for n in changed)
mapping={**plan['mapping'],**{n:row['target'] for n,row in baseline['moves']['ignored_UID'].items()}}
UID={str(p.relative_to(Q)):{'SHA256':sha(p.read_bytes()),'mode':stat.S_IMODE(p.stat().st_mode)}
 for p in (Q/'tools').rglob('*.uid') if p.is_file()}
assert UID=={mapping.get(n,n):row for n,row in baseline['all_UID'].items()} and len(UID)==304
assert load('full-plan-coverage.json')['original_rows_accounted_for']==779
assert len(load('full-plan-coverage.json')['root_sources'])==11
assert load('source-contract-audit.json')['fields']==37
unused=load('unused-import-audit.json');assert unused['modules']==57 and unused['test_modules']==21 and not unused['unused_candidates']
for name in ['tools/qa/art/current_paths.py','tools/qa/world/source_inputs.py','AGENTS.md']:
 assert (Q/name).read_bytes()==git('show',freeze['base']+':'+name)
def outer(raw):
 a,b=raw.index(b'## REFACTOR-03 '),raw.index(b'## REFACTOR-04 ')
 return raw[:a],raw[b:]
assert outer((Q/'docs/epics/refactoring-2026-10/TASKS.md').read_bytes())==outer(git('show',freeze['base']+':docs/epics/refactoring-2026-10/TASKS.md'))
for label in ['before','after']:
 profile=load(label+'-profile.json')
 assert len(profile['commands'])==22 and len(profile['GD'])==114 and profile['unit_cases']==243
 for row in profile['commands']+profile['GD']:
  assert row['exit']==0
  stored=(R/row['log']).read_bytes()
  assert sha(stored)==row['stored_SHA256'] and sha(gzip.decompress(stored))==row['raw_SHA256']
  if 'engine_log' in row:
   stored=(R/row['engine_log']).read_bytes()
   assert sha(stored)==row['engine_stored_SHA256'] and sha(gzip.decompress(stored))==row['engine_raw_SHA256']
 assert profile['native_frames']==0 and not profile['FPS_admission']
assert load('after-profile.json')['historical_stdout_byte_equal']==11
assert load('grass-history-stdout.json')['same_as_before_profile']
assert load('grass-history-stdout.json')['current_source_SHA256']==sha((Q/'tools/qa/foliage/grass_methods.py').read_bytes())
for name,count in [('infrastructure-launch-green.txt',13),('performance-shared-green.txt',8),('surface-shared-history-green.txt',9)]:
 raw=log(name).decode();assert 'Ran '+str(count)+' tests' in raw and raw.rstrip().endswith('OK')
assert len(load('integration-repairs.json')['modules'])==5
for name,row in load('integration-repairs.json')['modules'].items():
 assert sha((Q/name).read_bytes())==row['after_SHA256']
assert load('unused-import-cleanup.json')['imports_removed']==13
assert load('test-contract-audit.json')['context_test_methods_removed']==0
assert load('fresh-editor.json')['exit']==0

gates=load('gates-05/gate-exits.json')
assert [row['gate'] for row in gates]==['wiki','architecture','game']
assert all(row['exit']==0 and row['version']=='0.0.380' for row in gates)
architecture=log('gates-05/architecture.txt').decode()
counts=list(map(int,re.findall(r'^Ran (\d+) tests? in ',architecture,re.M)))
assert len(counts)==107 and sum(counts)==1404,(len(counts),sum(counts))
game=log('gates-05/game.txt').decode()
assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed')==2
wiki=log('gates-05/wiki.txt').decode();assert 'ℹ pass 145' in wiki and 'ℹ fail 0' in wiki
for series in ['gates-01','gates-02','gates-03','gates-04']:
 previous=load(series+'/gate-exits.json');assert [r['exit'] for r in previous]==[0,1]
assert "No module named 'test_shore_kit'" in log('gates-01/architecture.txt').decode()
assert 'tools/visual_camera_points.gd' in log('gates-02/architecture.txt').decode()
assert 'FAILED (errors=4)' in log('gates-03/architecture.txt').decode()
assert load('catalog.json')==load('catalog-final.json')
catalog=load('catalog-final.json');assert catalog['root_sources']==11 and catalog['map']==491
assert catalog['profile_attachment_equal'] and catalog['full_map_attachment_equal'] and not catalog['VMAP_accepted']
article=load('browser-article.json');assert article['version'] and article['candidate380'] and article['root11']
assert article['dimensions']=={'scrollWidth':1280,'width':1280}
assert load('browser-mobile.json')['dimensions']=={'scrollWidth':390,'width':390}
task=load('browser-task.json');assert all(task[k] for k in ['status_in_progress','candidate380','root11','task_heading','pr_present'])
cleanup=load('browser-cleanup.json');assert cleanup['viewport_reset'] and cleanup['own_server_exit']==143 and cleanup['own_tabs_closed']==['25','26']
for label,size in [('desktop',(1280,900)),('mobile',(390,844))]:assert Image.open(R/('browser-'+label+'.png')).size==size
assert len(load('browser-link-http.json')['links'])==2

# Lossless storage preserves any significant whitespace in complete raw logs.
transcoding=[]
for path in sorted(R.glob('gates-*/*.txt')):
 raw=path.read_bytes();data=gzip.compress(raw,mtime=0);target=Path(str(path)+'.gz')
 assert not target.exists();target.write_bytes(data);path.unlink()
 transcoding.append({'raw_path':str(path.relative_to(R)),'stored_path':str(target.relative_to(R)),
  'raw_SHA256':sha(raw),'stored_SHA256':sha(data),'raw_bytes_changed':False})
(R/'raw-log-transcoding.json').write_text(json.dumps(transcoding,indent=2)+'\n')
for source,target in [('/private/tmp/refactor03-audit380.py','audit.py'),
 ('/private/tmp/refactor03-publish380.py','publish.py'),(__file__,'seal.py')]:shutil.copy2(source,R/target)
files=[{'path':str(p.relative_to(R)),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size}
 for p in sorted(R.rglob('*')) if p.is_file() and p.name!='checks.json']
checks={'task':'REFACTOR-03','phase':'full remaining Foliage/shared source candidate','version':'0.0.380','base':freeze['base'],
 'parent_review':5706289303,'parent_CI_success':8,'source_SHA256':sources,'removed_source_paths':removed,
 'physical_source_moves':77,'tracked_UID_moves':34,'ignored_UID_moves':4,'UID_bytes_mode_preserved':304,
 'root_before':82,'root_sources':11,'root_budget':30,'map_before':380,'map':491,'original_plan_rows_accounted_for':779,
 'profile_CLI_each':22,'profile_old_cases_each':243,'GD_checks_each':114,'historical_stdout_equal':11,
 'profile_precedes_explicit_import_and_integration_repairs':True,'current_grass_stdout_refreshed':True,
 'new_context_cases':11,'new_provenance_cases':10,'new_actual_producer_cases':10,'new_native_frames':0,'FPS_admission':False,
 'expanded_import_audit_modules':57,'tools_test_modules_included':21,'frozen_contract_fields':37,
 'authoritative_gates':'gates-05','architecture_suites':107,'architecture_cases':1404,
 'Game_passed':53502,'Game_failed':0,'normal_F10_each':90,'Wiki_passed':145,
 'full03_source_scope_complete':True,'full03_done':False,'Task_Complete':False,'main_changed':False,
 'current_head_review_CI':'required; parent acceptance does not substitute','report_files':files}
(R/'checks.json').write_text(json.dumps(checks,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'sources':len(sources),'removed':len(removed),'report_files':len(files)+1,'architecture':[107,1404],
 'Game':53502,'Wiki':145,'root':11,'full03_independent_acceptance':'pending'}))
