"""Freeze exact371 source/ownership before repairing the two real surface producers."""
import gzip,hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');PRIMARY=Path('/Users/sergeyshevchenko/my farm')
R=ROOT/'docs/reports/refactor-03/performance-review-1';BASE='f134dd9b7f2cf0741a0ace939d26fc247178cbad'
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])
def sha(raw):return hashlib.sha256(raw).hexdigest()
assert git(ROOT,'status','--porcelain')==b'' and git(ROOT,'rev-parse','HEAD').decode().strip()==BASE==git(PRIMARY,'rev-parse','HEAD').decode().strip()
assert not R.exists();b=R/'baseline';b.mkdir(parents=True)
source=['tools/grass_compare_collect.py','tools/ground_layers.py','tools/grass_methods.py','tools/assets/contracts/source_paths.py',
 'tools/assets/contracts/test_source_paths.py','tools/quality/check_architecture.sh','.gitattributes',
 'VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist','TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md',
 'tools/README.md','wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md']
records={}
for name in source:
 raw=(ROOT/name).read_bytes();assert raw==git(ROOT,'show',BASE+':'+name),name
 records[name]={'sha256':sha(raw),'mode':(ROOT/name).stat().st_mode&0o777};(b/(name.replace('/','--')+'.gz')).write_bytes(gzip.compress(raw,mtime=0))
inventory={'base':BASE,'version':'0.0.371','root_sources':285,'sources':records,'consumers':source,'local_UID':[],
 'review':5691592934,'review_state':'CHANGES_REQUESTED','Team_priority_P2':True,'CI371_success':8,
 'scope':'repair2realproducerinput/copy/recheck and subsequent Git reader alias; no newtask/noUIDmove/noGame/GPUadmission'}
(b/'inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+'\n');shutil.copyfile(__file__,R/'baseline.py')
foreign=['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']
lease={'base':BASE,'own_before':{n:sha((PRIMARY/n).read_bytes())for n in source},
 'foreign':{n:{'working':sha((PRIMARY/n).read_bytes()),'index':sha(git(PRIMARY,'show',':'+n))}for n in foreign}}
Path('/private/tmp/refactor03-before372-primary.json').write_text(json.dumps(lease,indent=2)+'\n')
print(json.dumps({'owned_before':len(source),'base':BASE,'P2':5691592934,'root':285}))
