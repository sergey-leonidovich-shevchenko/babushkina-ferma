"""Freeze accepted372 before camera context preparation; preserve parallel plan07 ownership."""
import gzip,hashlib,json,shutil,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm');R=Q/'docs/reports/refactor-03/camera-prepare'
BASE='57612b6291a88253d5a2f5e46aca21457555f302'
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])
def sha(raw):return hashlib.sha256(raw).hexdigest()
assert git(Q,'status','--porcelain')==b'' and git(Q,'rev-parse','HEAD').decode().strip()==BASE==git(P,'rev-parse','HEAD').decode().strip()
plan=json.loads(Path('/private/tmp/refactor03-camera-plan373.json').read_text());assert plan['base']==BASE and not plan['applied']
red=json.loads(Path('/private/tmp/refactor03-camera-red373.json').read_text());assert red['exit']==1 and red['methods']==12
assert 'FAILED (failures=16)'in Path('/private/tmp/refactor03-camera-red373.txt').read_text()
assert sha(Path('/private/tmp/refactor03-test-camera-context373.py').read_bytes())==red['test_SHA256']
assert not R.exists();B=R/'baseline';B.mkdir(parents=True)
consumers=['.gitignore','VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist','tools/quality/check_architecture.sh','TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md','tools/README.md','wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md']
sources={}
for n in [*plan['changes'],*consumers]:
 p=Q/n;raw=p.read_bytes();assert raw==git(Q,'show',BASE+':'+n)
 sources[n]={'sha256':sha(raw),'mode':p.stat().st_mode&0o777};(B/(n.replace('/','--')+'.gz')).write_bytes(gzip.compress(raw,mtime=0))
for source,target in [('refactor03-camera-plan373.json','baseline/adaptation-plan.json'),('refactor03-test-camera-context373.py','baseline/camera-context-test.py'),('refactor03-camera-red373.txt','context-red.txt'),('refactor03-camera-red373.json','context-red.json'),('refactor03-ci372-final.json','baseline/ci372-final.json'),('refactor03-reviews372.json','baseline/reviews372.json')]:shutil.copyfile(Path('/private/tmp')/source,R/target)
(B/'inventory.json').write_text(json.dumps({'base':BASE,'version':'0.0.372','root_sources':285,'sources':sources,'consumers':consumers,'preparation_source_paths':list(plan['changes']),'new_tests':12,'source_root_sites':6,'Git_read_sites':9,'source_review':5692067678,'Team_intermediate_accepted':True,'CI372_success':8,'physical_moves':0,'local_UID':[]},ensure_ascii=False,indent=2)+'\n')
foreign=['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']
Path('/private/tmp/refactor03-before373-primary.json').write_text(json.dumps({'base':BASE,'own_before':{n:sha((P/n).read_bytes())for n in sources},'foreign':{n:{'working':sha((P/n).read_bytes()),'index':sha(git(P,'show',':'+n))}for n in foreign}},indent=2)+'\n')
shutil.copyfile(__file__,R/'baseline.py');shutil.copyfile('/private/tmp/refactor03-camera-plan373.py',R/'plan.py');shutil.copyfile('/private/tmp/refactor03-camera-regression373.py',R/'regression-runner.py')
print(json.dumps({'baseline_source_paths':len(sources),'real_red_methods':12,'red_failures_with_subtests':16,'root':285,'physical_moves':0}))
