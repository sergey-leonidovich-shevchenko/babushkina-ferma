"""Freeze the accepted compatibility family and ownership before its physical move."""
import gzip, hashlib, json, subprocess
from pathlib import Path

ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
PRIMARY=Path('/Users/sergeyshevchenko/my farm')
REPORT=ROOT/'docs/reports/refactor-03/compatibility-move'
BASE='81bec22e0b447054a631707e9e12179e222a57c2'
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])
def sha(raw):return hashlib.sha256(raw).hexdigest()
assert git(ROOT,'status','--porcelain')==b''
assert git(ROOT,'rev-parse','HEAD').decode().strip()==BASE==git(PRIMARY,'rev-parse','HEAD').decode().strip()
assert not REPORT.exists()
plan=json.loads((ROOT/'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())['assignments']
assignments={n:r for n,r in plan.items()if r['family']=='compatibility'}
assert len(assignments)==153 and sum(n.endswith('.gd')for n in assignments)==87
documents=['PERFORMANCE.md','QA_CHECKLIST.md','TESTING.md','assets/game/characters/grandmother_v2/README.md',
 'docs/COMPACT_HUD.md','docs/DEVELOPMENT.md','docs/PLAYABILITY_POLISH.md','docs/TREE_COMFORT.md','docs/UI_AUDIT.md','docs/UI_GUIDE.md']
consumers=['.gitignore','.gitattributes','VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist',
 'tools/assets/slicing/slice_review.gd','tools/water_fishing_review.gd','tools/water_navigation_review.gd','tools/water_topology_review.gd',
 'tools/quality/check_architecture.sh','tools/README.md','wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md',*documents]
sources={}
baseline=REPORT/'baseline';baseline.mkdir(parents=True)
for n in [*assignments,*consumers]:
 raw=(ROOT/n).read_bytes();assert raw==git(ROOT,'show',BASE+':'+n),n
 sources[n]={'sha256':sha(raw),'mode':(ROOT/n).stat().st_mode&0o777}
 (baseline/(n.replace('/','--')+'.gz')).write_bytes(gzip.compress(raw,mtime=0))
uids=[]
for n,row in assignments.items():
 if n.endswith('.gd'):
  local=ROOT/(n+'.uid')
  if local.exists()and n+'.uid'not in assignments:
   assert git(ROOT,'check-ignore','--',n+'.uid').strip()
   uids.append({'old_path':n+'.uid','target':row['target']+'.uid','sha256':sha(local.read_bytes()),'mode':local.stat().st_mode&0o777})
inventory={'base':BASE,'version':'0.0.368','root_sources':403,'assignments':assignments,'consumers':consumers,'live_documents':documents,
 'sources':sources,'local_UID':uids,'source_review':5689214200,'source_review_accepted_intermediate_only':True,'CI368_success':8}
(baseline/'inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+'\n')
foreign=['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']
lease={'base':BASE,'own_before':{n:sha((PRIMARY/n).read_bytes())for n in sources},
 'foreign':{n:{'working':sha((PRIMARY/n).read_bytes()),'index':sha(git(PRIMARY,'show',':'+n))}for n in foreign}}
Path('/private/tmp/refactor03-before369-primary.json').write_text(json.dumps(lease,indent=2)+'\n')
print(json.dumps({'source_assignments':len(assignments),'source_moves':89,'tracked_UID':64,'ignored_UID':len(uids),'owned_before':len(sources)}))
