"""Freeze accepted374, actual red controls and primary ownership before World preparation."""
import gzip,hashlib,json,shutil,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/world-prepare';BASE='6b13af8ebf9ec603705c6d4e04577ce8774095da'
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])
def sha(raw):return hashlib.sha256(raw).hexdigest()
assert git(Q,'status','--porcelain')==b''and git(Q,'rev-parse','HEAD').decode().strip()==BASE==git(P,'rev-parse','HEAD').decode().strip()
plan=json.loads(Path('/private/tmp/refactor03-world-plan375.json').read_text());red=json.loads(Path('/private/tmp/refactor03-world-red375.json').read_text())
assert plan['base']==BASE and not plan['applied']and len(plan['changes'])==24
assert red['exit']==1 and red['methods']==19 and 'FAILED (failures=12, errors=19)'in Path('/private/tmp/refactor03-world-red375.txt').read_text()
assert sha(Path('/private/tmp/refactor03-test-world-context375.py').read_bytes())==red['test_SHA256']
ci=json.loads(Path('/private/tmp/refactor03-ci374-final.json').read_text());assert ci['headRevision']==BASE and len(ci['checks'])==8 and all(r['conclusion']=='success'for r in ci['checks'])
reviews=json.loads(Path('/private/tmp/refactor03-reviews374.json').read_text());assert any(BASE in r['body']for r in reviews)
assert not R.exists();B=R/'baseline';B.mkdir(parents=True)
consumers=['.gitignore','VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist','tools/quality/check_architecture.sh','TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md','tools/README.md','wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md']
sources={}
for name in [*plan['changes'],*consumers]:
    path=Q/name;raw=path.read_bytes();assert raw==git(Q,'show',BASE+':'+name)
    sources[name]={'sha256':sha(raw),'mode':path.stat().st_mode&0o777};(B/(name.replace('/','--')+'.gz')).write_bytes(gzip.compress(raw,mtime=0))
for source,target in [('refactor03-world-plan375.json','baseline/adaptation-plan.json'),('refactor03-test-world-context375.py','baseline/world-context-test.py'),('refactor03-world-red375.txt','context-red.txt'),('refactor03-world-red375.json','context-red.json'),('refactor03-world-red375-attempt01.txt','context-red-attempt01.txt'),('refactor03-world-red375-attempt01.json','context-red-attempt01.json'),('refactor03-ci374-final.json','baseline/ci374-final.json'),('refactor03-reviews374.json','baseline/reviews374.json')]:shutil.copyfile(Path('/private/tmp')/source,R/target)
(B/'inventory.json').write_text(json.dumps({'base':BASE,'version':'0.0.374','root_sources':245,'sources':sources,'consumers':consumers,'preparation_source_paths':list(plan['changes']),'new_tests':19,'source_root_sites':9,'Git_read_sites':42,'already_clean_Git_read_sites':9,'source_review':5693093074,'Team_intermediate_accepted':True,'CI374_success':8,'physical_moves':0,'local_UID':[]},ensure_ascii=False,indent=2)+'\n')
foreign=['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']
Path('/private/tmp/refactor03-before375-primary.json').write_text(json.dumps({'base':BASE,'own_before':{n:sha((P/n).read_bytes())for n in sources},'foreign':{n:{'working':sha((P/n).read_bytes()),'index':sha(git(P,'show',':'+n))}for n in foreign}},indent=2)+'\n')
for source,target in [(str(Path(__file__)),'baseline.py'),('/private/tmp/refactor03-world-plan375.py','plan.py'),('/private/tmp/refactor03-world-regression375.py','regression-runner.py')]:shutil.copyfile(source,R/target)
print(json.dumps({'baseline_source_paths':len(sources),'red_methods':19,'red_failures':12,'red_errors':19,'root':245,'physical_moves':0}))
