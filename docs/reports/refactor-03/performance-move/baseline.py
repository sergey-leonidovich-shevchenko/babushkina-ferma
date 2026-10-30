"""Freeze exact accepted370 inputs and primary ownership before the physical performance move."""
import ast,gzip,hashlib,json,re,shutil,subprocess
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
PRIMARY=Path('/Users/sergeyshevchenko/my farm')
REPORT=ROOT/'docs/reports/refactor-03/performance-move'
BASE='9a2ad81fb77282c4f52261e694653b28b21f01b8'
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])
def sha(raw):return hashlib.sha256(raw).hexdigest()
assert git(ROOT,'status','--porcelain')==b'' and git(ROOT,'rev-parse','HEAD').decode().strip()==BASE
assert git(PRIMARY,'rev-parse','HEAD').decode().strip()==BASE and not REPORT.exists()
plan=json.loads((ROOT/'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())['assignments']
assignments={n:r for n,r in plan.items()if r['family']=='performance'and n!=r['target']}
assert len(assignments)==47
modules={Path(n).stem for n in assignments if n.endswith('.py')}
python_consumers=[];gd_consumers=[]
for n in git(ROOT,'ls-files','-z').decode().split('\0'):
 if not n.startswith('tools/') or n in assignments:continue
 if n.endswith('.py'):
  tree=ast.parse((ROOT/n).read_text())
  if any(isinstance(t,ast.ImportFrom)and t.module in modules or isinstance(t,ast.Import)and any(a.name in modules for a in t.names)for t in ast.walk(tree)):
   python_consumers.append(n)
 if n.endswith('.gd'):
  text=(ROOT/n).read_text()
  if any('"res://'+old+'"'in text for old in assignments if old.endswith('.gd')):gd_consumers.append(n)
documents=['PERFORMANCE.md','QA_CHECKLIST.md','TESTING.md','docs/DEVELOPMENT.md','docs/MODULAR_VILLAGE.md']
consumers=list(dict.fromkeys(['.gitignore','.gitattributes','VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist',
 'tools/quality/check_architecture.sh','run_tests.sh','tools/README.md','wiki/articles/project-refactoring.md',
 'docs/epics/refactoring-2026-10/TASKS.md',*documents,*python_consumers,*gd_consumers]))
sources={};baseline=REPORT/'baseline';baseline.mkdir(parents=True)
for n in [*assignments,*consumers]:
 raw=(ROOT/n).read_bytes();assert raw==git(ROOT,'show',BASE+':'+n),n
 sources[n]={'sha256':sha(raw),'mode':(ROOT/n).stat().st_mode&0o777}
 (baseline/(n.replace('/','--')+'.gz')).write_bytes(gzip.compress(raw,mtime=0))
uids=[]
for n,row in assignments.items():
 if n.endswith('.gd')and n+'.uid'not in assignments and(ROOT/(n+'.uid')).exists():
  p=ROOT/(n+'.uid');assert git(ROOT,'check-ignore','--',n+'.uid').strip()
  uids.append({'old_path':n+'.uid','target':row['target']+'.uid','sha256':sha(p.read_bytes()),'mode':p.stat().st_mode&0o777})
inventory={'base':BASE,'version':'0.0.370','root_sources':314,'assignments':assignments,'sources':sources,
 'consumers':consumers,'python_consumers':python_consumers,'gd_consumers':gd_consumers,'live_documents':documents,
 'local_UID':uids,'source_review':5690964419,'Team_intermediate_accepted':True,'CI370_final_pending':True}
(baseline/'inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(__file__,REPORT/'baseline.py')
foreign=['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']
lease={'base':BASE,'own_before':{n:sha((PRIMARY/n).read_bytes())for n in sources},
 'foreign':{n:{'working':sha((PRIMARY/n).read_bytes()),'index':sha(git(PRIMARY,'show',':'+n))}for n in foreign}}
Path('/private/tmp/refactor03-before371-primary.json').write_text(json.dumps(lease,indent=2)+'\n')
text=(ROOT/'docs/reports/refactor-03/performance-prepare/profile.py').read_text()
text=text.replace("        for short, script, original in [", "        def cli(name):\n            if phase == 'after' and name != 'performance_gate.py':\n                return [sys.executable, str(ROOT / 'tools/run.py'), 'qa.performance.' + name[:-3]]\n            return [sys.executable, str(ROOT / 'tools' / name)]\n\n        for short, script, original in [")
text=text.replace("[sys.executable, str(ROOT / 'tools' / script), '--folder', str(folder)]", "[*cli(script), '--folder', str(folder)]")
text=text.replace("[sys.executable, str(ROOT / 'tools/optimization_asset_audit.py'), '--output', str(assets)]", "[*cli('optimization_asset_audit.py'), '--output', str(assets)]")
text=text.replace("[sys.executable, str(ROOT / 'tools/perf_contract.py'), *options]", "[*cli('perf_contract.py'), *options]")
text=text.replace("[sys.executable, str(ROOT / 'tools/perf_contract_collect.py'), '--help']", "[*cli('perf_contract_collect.py'), '--help']")
text=text.replace("[sys.executable, str(ROOT / 'tools' / script), '--output', str(previous)]", "[*cli(script), '--output', str(previous)]")
text=text.replace("[sys.executable, str(ROOT / 'tools/audit_save_crashes.py'), '--godot',", "[*cli('audit_save_crashes.py'), '--godot',")
text=text.replace("'test_storage_perf', 'test_performance_gate', 'test_perf_contract', 'test_redraw_output']", "'test_storage_perf', 'test_performance_gate', 'test_perf_contract', 'test_redraw_output', 'test_performance_layout']")
text=text.replace("                run([sys.executable, str(ROOT / 'tools/run.py'), command], foreign, environment)", "                command = command if command.startswith('qa.') else 'qa.performance.' + command\n                run([sys.executable, str(ROOT / 'tools/run.py'), command], foreign, environment)")
text=text.replace("            assert digest(raw_test) == digest((REPORT / 'baseline/performance-context-test.py').read_bytes())", "            # The same five context tests retain their bodies/assertions; only two imports move.\n            old = gzip.decompress((REPORT / 'baseline/tools--qa--performance--test_performance_context.py.gz').read_bytes()).decode()\n            expected = old.replace('import perf_contract as contract', 'from tools.qa.performance import perf_contract as contract').replace('import perf_contract_collect as collector', 'from tools.qa.performance import perf_contract_collect as collector')\n            assert raw_test.decode() == expected")
(REPORT/'profile.py').write_text(text.replace('before/after source-root/Git preparation','before/after the physical performance move'))
print(json.dumps({'assignments':len(assignments),'source':33,'tracked_UID':14,'ignored_UID':len(uids),'python_consumers':len(python_consumers),'gd_consumers':gd_consumers,'owned_before':len(sources)}))
