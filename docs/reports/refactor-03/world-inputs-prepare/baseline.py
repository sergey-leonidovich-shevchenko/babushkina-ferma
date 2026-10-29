"""Freeze accepted375 and actual integration red/producer before controls; do not mutate product yet."""
import gzip,hashlib,json,shutil,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/world-inputs-prepare';BASE='e205c00729214358308f14c46b63c3bd2fdde2d9'
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])
def sha(raw):return hashlib.sha256(raw).hexdigest()
assert git(Q,'status','--porcelain')==b''and git(Q,'rev-parse','HEAD').decode().strip()==BASE==git(P,'rev-parse','HEAD').decode().strip()
plan=json.loads(Path('/private/tmp/refactor03-world-plan376.json').read_text());assert plan['base']==BASE and not plan['applied']and len(plan['changes'])==25
red=json.loads(Path('/private/tmp/refactor03-world-history-red376.json').read_text());assert red['methods']==12 and red['exit']==1 and'FAILED (failures=1, errors=10)'in Path('/private/tmp/refactor03-world-history-red376.txt').read_text()
assert red['test_SHA256']==sha(Path('/private/tmp/refactor03-test-world-source-history376.py').read_bytes())
producers=json.loads(Path('/private/tmp/refactor03-world-producers-before376.json').read_text());assert producers['exit']==0 and producers['methods']==13
assert producers['test_SHA256']==sha(Path('/private/tmp/refactor03-test-world-producers376.py').read_bytes())
assert'Ran 16 tests'in Path('/private/tmp/refactor03-source-inputs376-design-smoke.txt').read_text()and Path('/private/tmp/refactor03-source-inputs376-design-smoke.txt').read_text().rstrip().endswith('OK')
ci=json.loads(Path('/private/tmp/refactor03-ci375-final.json').read_text());assert ci['headRevision']==BASE and len(ci['checks'])==8 and all(r['conclusion']=='success'for r in ci['checks'])
reviews=json.loads(Path('/private/tmp/refactor03-reviews375.json').read_text());assert any(BASE in r['body']and'SOURCE PASS'in r['body']for r in reviews)
assert not R.exists();B=R/'baseline';B.mkdir(parents=True)
consumers=['.gitignore','VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist','tools/quality/check_architecture.sh','TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md','tools/README.md','wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md','docs/epics/refactoring-2026-10/README.md']
sources={}
for name in[*plan['changes'],*consumers]:
    path=Q/name;raw=path.read_bytes();assert raw==git(Q,'show',BASE+':'+name)
    sources[name]={'sha256':sha(raw),'mode':path.stat().st_mode&0o777};(B/(name.replace('/','--')+'.gz')).write_bytes(gzip.compress(raw,mtime=0))
files=[('refactor03-world-plan376.json','baseline/adaptation-plan.json'),('refactor03-source-inputs376.py','baseline/source-inputs.py'),
 ('refactor03-test-world-source-history376.py','baseline/test-world-source-history.py'),('refactor03-test-source-inputs376.py','baseline/test-source-inputs.py'),('refactor03-test-world-producers376.py','baseline/test-world-producers.py'),
 ('refactor03-world-history-red376.txt','history-red.txt'),('refactor03-world-history-red376.json','history-red.json'),
 ('refactor03-world-history-red376-attempt01.txt','history-red-attempt01.txt'),('refactor03-world-history-red376-attempt01.json','history-red-attempt01.json'),('refactor03-test-world-source-history376-attempt01.py.gz','baseline/history-test-attempt01.py.gz'),
 ('refactor03-source-inputs376-design-smoke.txt','helper-design-smoke.txt'),('refactor03-source-inputs376-design-smoke-attempt01.txt','helper-design-smoke-attempt01.txt'),('refactor03-test-source-inputs376-draft01.py.gz','baseline/helper-test-draft01.py.gz'),
 ('refactor03-world-producers-before376.txt','producers-before.txt'),('refactor03-world-producers-before376.json','producers-before.json'),('refactor03-ci375-final.json','baseline/ci375-final.json'),('refactor03-reviews375.json','baseline/reviews375.json')]
for source,target in files:shutil.copyfile(Path('/private/tmp')/source,R/target)
uids=json.loads((Q/'docs/reports/refactor-03/baseline/local-uids.json').read_text());exact=[]
for row in uids['local_only_UID']:
    paths=[Q/n for n in[row['old_path'],row['target']]if(Q/n).is_file()];assert len(paths)==1
    path=paths[0];counterpart=P/path.relative_to(Q);assert path.read_bytes()==counterpart.read_bytes()and path.stat().st_mode&0o777==counterpart.stat().st_mode&0o777
    exact.append({'path':str(path.relative_to(Q)),'sha256':sha(path.read_bytes()),'mode':path.stat().st_mode&0o777,'value':row['value']})
assert len(exact)==85
(B/'inventory.json').write_text(json.dumps({'base':BASE,'version':'0.0.375','root_sources':245,'sources':sources,'consumers':consumers,'preparation_source_paths':list(plan['changes']),'history_integration_methods':12,'helper_API_methods':16,'actual_producer_methods':13,'existing_context_methods':19,'current_input_sites':37,'historical_sites':14,'future_history_aliases':141,'current_source_map':133,'source_review':5693715399,'Team_intermediate_accepted':True,'CI375_success':8,'physical_moves':0,'local_UID':[],'author_UID_exact':exact,'anchor':uids['retained_anchor_local_UID']},ensure_ascii=False,indent=2)+'\n')
foreign=['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']
Path('/private/tmp/refactor03-before376-primary.json').write_text(json.dumps({'base':BASE,'own_before':{n:sha((P/n).read_bytes())for n in sources},'foreign':{n:{'working':sha((P/n).read_bytes()),'index':sha(git(P,'show',':'+n))}for n in foreign}},indent=2)+'\n')
for source,target in[(str(Path(__file__)),'baseline.py'),('/private/tmp/refactor03-world-plan376.py','plan.py'),('/private/tmp/refactor03-build-helper376.py','build-helper.py'),('/private/tmp/refactor03-source-inputs376-template.py','source-inputs-template.py')]:shutil.copyfile(source,R/target)
(B/'private-design-attempts.json').write_text(json.dumps({'before_product_edits':True,'history_first_attempt':'PNG source inputs wrongly counted as native frames; imported TestCase accidentally added19 extra cases; render legacy header has no top-level performance_eligible. All corrected before final red.','final_history_red':'12 methods,1failure/10errors,render-order positive control','helper_private_smoke_first_attempt':'reference root selected tmp test path; anchored to existing project context fixture source;16/0 private design smoke after correction. This is not a product regression replay.','native_frames_generated':0,'Game_started':False},indent=2)+'\n')
print(json.dumps({'baseline_source_paths':len(sources),'new_files_planned':4,'root':245,'physical_moves':0,'history_red_methods':12,'before_actual_producers':13,'author_UID_exact':85}))
