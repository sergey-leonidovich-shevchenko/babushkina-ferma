"""Freeze accepted373 and the complete bounded40-source camera move before applying it."""
import gzip,hashlib,json,shutil,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');P=Path('/Users/sergeyshevchenko/my farm');R=Q/'docs/reports/refactor-03/camera-move';BASE='d2ff4bde558196f808bef0486db1c0aaa0302ab9'
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])
def sha(raw):return hashlib.sha256(raw).hexdigest()
assert not git(Q,'diff','--name-only')and not git(Q,'diff','--cached','--name-only')
untracked=git(Q,'ls-files','--others','--exclude-standard','-z').decode().split('\0');assert all(not n or n.startswith(str(R.relative_to(Q))+'/')for n in untracked)
assert git(Q,'rev-parse','HEAD').decode().strip()==BASE==git(P,'rev-parse','HEAD').decode().strip()
plan=json.loads(Path('/private/tmp/refactor03-camera-plan374.json').read_text());assert plan['base']==BASE
B=R/'baseline'
consumers=['.gitignore','VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist','tools/quality/check_architecture.sh','TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md','tools/README.md','wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md']
names=set(plan['changes'])|{r['old_path']for r in plan['moves']}|set(consumers)
expected_partial={B/(n.replace('/','--')+'.gz')for n in names}
if R.exists():
 assert {p for p in R.rglob('*')if p.is_file()}<=expected_partial
 for p in expected_partial:
  if p.exists():
   name=next(n for n in names if B/(n.replace('/','--')+'.gz')==p)
   assert gzip.decompress(p.read_bytes())==git(Q,'show',BASE+':'+name)
B.mkdir(parents=True,exist_ok=True)
sources={}
for n in sorted(names):
 p=Q/n;raw=p.read_bytes();assert raw==git(Q,'show',BASE+':'+n);sources[n]={'sha256':sha(raw),'mode':p.stat().st_mode&0o777};(B/(n.replace('/','--')+'.gz')).write_bytes(gzip.compress(raw,mtime=0))
for row in plan['moves']:assert not(Q/row['target']).exists(),row['target']
for row in plan['local_UID']:assert sha((Q/row['old_path']).read_bytes())==row['sha256']and not(Q/row['target']).exists()
anchors={}
for n in ['tools/visual_camera_points.gd','tools/visual_camera_points.gd.uid','tools/encode_coordinate_video.swift']:
 p=Q/n;anchors[n]={'sha256':sha(p.read_bytes()),'mode':p.stat().st_mode&0o777}
for source,target in [('refactor03-camera-plan374.json','baseline/move-plan.json'),('refactor03-ci373-final.json','baseline/ci373-final.json'),('refactor03-reviews373.json','baseline/reviews373.json'),('refactor03-test-camera-layout374.py','baseline/camera-layout-test.py'),('refactor03-camera-layout374-red-final.txt','layout-red.txt'),('refactor03-camera-layout374-red-final.json','layout-red.json'),('refactor03-test-camera-layout374-before-anchor.py.gz','baseline/layout-test-before-anchor.py.gz'),('refactor03-camera-layout374-red-attempt01.txt','layout-red-attempt01.txt'),('refactor03-camera-layout374-red-attempt01.json','layout-red-attempt01.json')]:shutil.copyfile(Path('/private/tmp')/source,R/target)
red=json.loads((R/'layout-red.json').read_text());assert red['test_SHA256']==sha((B/'camera-layout-test.py').read_bytes())and red['exit']==1 and 'FAILED (failures=6, errors=1)'in(R/'layout-red.txt').read_text()
(B/'inventory.json').write_text(json.dumps({'base':BASE,'version':'0.0.373','root_before':285,'root_after':245,'sources':sources,'consumers':consumers,'moves':plan['moves'],'local_UID':plan['local_UID'],'deferred_shared_anchors':anchors,'source_review':5692493268,'Team_intermediate_accepted':True,'CI373_success':8,'new_layout_methods':3},ensure_ascii=False,indent=2)+'\n')
foreign=['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']
Path('/private/tmp/refactor03-before374-primary.json').write_text(json.dumps({'base':BASE,'own_before':{n:sha((P/n).read_bytes())for n in sources},'foreign':{n:{'working':sha((P/n).read_bytes()),'index':sha(git(P,'show',':'+n))}for n in foreign}},indent=2)+'\n')
shutil.copyfile(__file__,R/'baseline.py');shutil.copyfile('/private/tmp/refactor03-camera-plan374.py',R/'plan.py')
for name,target in [('refactor03-camera-baseline374-repair.json','baseline-preparation-repair.json'),('refactor03-camera-baseline374.py.before-uid-schema.gz','baseline-before-uid-schema.py.gz'),('refactor03-camera-plan374.py.before-uid-schema.gz','plan-before-uid-schema.py.gz'),('refactor03-camera-plan374.json.before-uid-schema.gz','plan-before-uid-schema.json.gz')]:shutil.copyfile(Path('/private/tmp')/name,R/target)
print(json.dumps({'baseline_sources':len(sources),'source_moves':40,'tracked_UID':2,'ignored_UID':15,'root_after':245,'deferred_anchors':2}))
