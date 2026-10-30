"""Freeze the complete source candidate before mandatory gates; verify isolation and historical evidence."""
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment

def git(*args,root=Q):
 return subprocess.check_output(['git','-C',str(root),*args],env=git_environment())
def sha(raw):return hashlib.sha256(raw).hexdigest()

assert (Q/'VERSION').read_text().strip()=='0.0.380'
assert git('rev-parse','HEAD').decode().strip()=='108ad126d00eb141658928aa3d68588c5af34db7'
assert git('rev-parse','main').decode().strip()=='d609ab4fa6d82d6d013265183f018b8836abf7cc'
baseline=json.loads((R/'baseline/inventory.json').read_text())
plan=json.loads((R/'move-plan.json').read_text())
prefix=str(R.relative_to(Q))+'/'
changed=set(filter(None,git('diff','--no-renames','--name-only','-z').decode().split('\0')))
changed.update(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
names=sorted(n for n in changed if not n.startswith(prefix) and (Q/n).is_file())
removed=sorted(n for n in changed if not n.startswith(prefix) and not (Q/n).exists())
assert set(removed)==set(plan['mapping']) and len(removed)==111
assert not any(n.startswith(('assets/','scripts/')) for n in changed)
assert not any(n.startswith('docs/reports/') and not n.startswith(prefix) for n in changed)
for n in ['VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist']:
 assert (Q/n).read_bytes()==git('show',baseline['base']+':'+n).replace(b'0.0.379',b'0.0.380')
def outer(raw):
 a,b=raw.index(b'## REFACTOR-03 '),raw.index(b'## REFACTOR-04 ')
 return raw[:a],raw[b:]
assert outer((Q/'docs/epics/refactoring-2026-10/TASKS.md').read_bytes())==outer(git('show',baseline['base']+':docs/epics/refactoring-2026-10/TASKS.md'))
for n,row in baseline['primary_foreign'].items():
 assert sha((P/n).read_bytes())==row['working_SHA256'],n
 assert sha(git('show',':'+n,root=P))==row['index_SHA256'],n
assert git('rev-parse','HEAD',root=P).decode().strip()==baseline['base']

editor=[]
for old,name in [('/private/tmp/refactor03-editor380.stdout','fresh-editor.stdout.gz'),
                 ('/private/tmp/refactor03-editor380.engine.log','fresh-editor.engine.gz')]:
 raw=Path(old).read_bytes();assert b'ERROR:' not in raw and b'SCRIPT ERROR' not in raw
 compressed=gzip.compress(raw,mtime=0);(R/name).write_bytes(compressed)
 editor.append({'log':name,'raw_SHA256':sha(raw),'stored_SHA256':sha(compressed)})
(R/'fresh-editor.json').write_text(json.dumps({'exit':0,'headless_editor_import':True,'native_frames':0,'logs':editor,
 'incremental_cache_after_move':True,'QA_cache_only':True,'primary_cache_untouched':True},indent=2)+'\n')
for old,name in [('/private/tmp/refactor03-audit380.py','audit.py'),
 ('/private/tmp/refactor03-contract-audit380.py','test-contract-audit.py'),
 ('/private/tmp/refactor03-context-counterfactual380.py','context-root-counterfactual.py'),
 ('/private/tmp/refactor03-clean-imports380.py','clean-imports.py'),
 ('/private/tmp/refactor03-profile380.py','profile.py'),
 ('/private/tmp/refactor03-mechanical-plan380.py','baseline/mechanical-plan.py'),
 ('/private/tmp/refactor03-mechanical-plan380.json','baseline/mechanical-plan.json'),
 ('/private/tmp/refactor03-provenance-plan380.py','baseline/provenance-plan.py'),
 (__file__,'freeze-source.py')]:shutil.copy2(old,R/name)
scope={'base':baseline['base'],'version':'0.0.380','source_paths_after':names,'removed_paths':removed,
 'report_prefix':prefix,'ignored_UID_moves':baseline['moves']['ignored_UID'],'other_cards_unchanged':True,
 'primary_foreign_working_and_index_preserved':True,'root':11,'map':491,'original_plan_rows':779}
(R/'scope.json').write_text(json.dumps(scope,indent=2,ensure_ascii=False)+'\n')
(R/'source-freeze.json').write_text(json.dumps({'version':'0.0.380','base':baseline['base'],
 'source_SHA256':{n:sha((Q/n).read_bytes()) for n in names},'removed_paths':removed,
 'all_before_full_gates':True,'other_cards_unchanged':True,'main_unchanged':True},indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'source_paths':len(names),'removed':len(removed),'root':11,'map':491,'full_plan':779,'foreign_preserved':True}))
