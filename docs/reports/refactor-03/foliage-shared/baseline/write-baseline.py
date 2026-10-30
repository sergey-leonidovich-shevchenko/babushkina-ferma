"""Freeze the accepted379 inputs and complete remaining original map before code relocation."""
import hashlib
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
BASE='108ad126d00eb141658928aa3d68588c5af34db7'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def git(root,*args):
    return subprocess.check_output(['git','-C',str(root),*args],env=git_environment())
assert git(Q,'rev-parse','HEAD').decode().strip()==BASE==git(P,'rev-parse','HEAD').decode().strip()
assert not R.exists()
p3=json.loads(Path('/private/tmp/refactor03-p3-docs380.json').read_text())
dirty=set(git(Q,'diff','--name-only').decode().splitlines())
assert dirty==set(p3['files'])
for name,row in p3['files'].items():
    assert sha((Q/name).read_bytes())==row['after_SHA256']
    assert sha(git(Q,'show',BASE+':'+name))==row['before_SHA256']
proposal=json.loads(Path('/private/tmp/refactor03-remaining-moves380.json').read_text())
mapping={n:r['target'] for n,r in proposal['rows'].items()}
allmoves=dict(mapping,**{n:r['target'] for n,r in proposal['ignored_UID'].items()})
for old,target in allmoves.items():assert(Q/old).is_file() and not(Q/target).exists()
sources={}
for prefix in ['tools','scripts','tests']:
    for path in (Q/prefix).rglob('*'):
        if not path.is_file() or path.suffix not in {'.py','.gd','.gdshader','.swift','.sh','.uid'}:continue
        if any(part in {'Godot.app','__pycache__'} for part in path.relative_to(Q).parts):continue
        name=str(path.relative_to(Q))
        try:raw=git(Q,'show',BASE+':'+name)
        except subprocess.CalledProcessError:continue
        assert raw==path.read_bytes(),name
        sources[name]={'SHA256':sha(raw),'mode':stat.S_IMODE(path.stat().st_mode)}
UID={str(p.relative_to(Q)):{'SHA256':sha(p.read_bytes()),'mode':stat.S_IMODE(p.stat().st_mode)}
    for p in (Q/'tools').rglob('*.uid') if p.is_file()}
assert len(UID)==304
gd=set(n for n in proposal['rows'] if n.endswith('.gd'))
uris=['res://'+n for n in mapping if n.endswith(('.gd','.gdshader'))]
for name in sources:
    if name.endswith('.gd') and any(uri in(Q/name).read_text() for uri in uris):gd.add(name)
(R/'baseline').mkdir(parents=True)
record={'base':BASE,'parent_review':5706289303,'parent_CI_success':8,'Team_intermediate_accepted':True,
    'sources':sources,'all_UID':UID,'GD_before_logical':sorted(gd),'moves':proposal,
    'P3':p3,'root_before':82,'root_target':11,'map_before':380,'map_target':491,
    'full03_done':False,'native_frames_new':0,'FPS_admission':False,
    'primary_foreign':{n:{'working_SHA256':sha((P/n).read_bytes()),'index_SHA256':sha(git(P,'show',':'+n))}
        for n in ['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']}}
(R/'baseline/inventory.json').write_text(json.dumps(record,indent=2)+'\n')
for source,target in [
    ('/private/tmp/refactor03-ci379-final.json','baseline/ci379-final.json'),
    ('/private/tmp/refactor03-reviews379-final.json','baseline/reviews379-final.json'),
    ('/private/tmp/refactor03-remaining-moves380.json','PLAN.json'),
    ('/private/tmp/refactor03-test-foliage-context380.py','baseline/test_foliage_context.py'),
    ('/private/tmp/refactor03-test-foliage-context380-prototype01.py','baseline/context-prototype01.py'),
    ('/private/tmp/refactor03-foliage-context380-red-attempt01.txt','baseline/context-red-attempt01.txt'),
    ('/private/tmp/refactor03-foliage-context380-red-attempt02.txt','baseline/context-red.txt'),
    ('/private/tmp/refactor03-p3-docs380.json','baseline/P3-docs.json'),
]:shutil.copy2(source,R/target)
shutil.copy2(__file__,R/'baseline/write-baseline.py')
print(json.dumps({'source_inventory':len(sources),'UID':len(UID),'GD':len(gd),
    'moves_original':len(mapping),'ignored_UID_moves':len(allmoves)-len(mapping),'root_target':11}))
