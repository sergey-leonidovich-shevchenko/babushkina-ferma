"""Prepare a private, non-applied source-root/Git patch while exact369 is under review."""
import ast,hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
BASE='c6f323d821455bfcfb025a03ae18f00e8cbe0f05'
assert subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()==BASE

def original(name):
 return subprocess.check_output(['git','-C',str(ROOT),'show',BASE+':'+name]).decode()

changes={}
root_files=['analyze_optimization_audit.py','analyze_storage_perf.py','audit_save_crashes.py',
 'optimization_asset_audit.py','perf_contract_collect.py','performance_protocol.py',
 'test_redraw_output.py']
for name in root_files:
 p='tools/'+name;before=original(p)
 replacement=('from common.paths import project_root\nfrom common.launch import prepare_imports\n\n'
  'ROOT = project_root(__file__)\nprepare_imports(ROOT)')
 after,n=re.subn(r'(?m)^ROOT\s*=\s*Path\(__file__\)\.resolve\(\)\.parents\[1\]$',lambda _:replacement,before)
 assert n==1,(p,n);changes[p]={'before':before,'after':after}
p='tools/test_optimization_audit.py'
before=original(p)
old='Path(__file__).resolve().parents[1]'
assert before.count(old)==1 and 'from common.paths import project_root' in before
changes[p]={'before':before,'after':before.replace(old,'project_root(__file__)')}
def add_git_environment(text):
 calls=[];lines=text.splitlines(keepends=True)
 for node in ast.walk(ast.parse(text)):
  if (isinstance(node,ast.Call)and isinstance(node.func,ast.Attribute)and isinstance(node.func.value,ast.Name)
      and node.func.value.id=='subprocess'and node.func.attr in{'run','check_output'}and node.args
      and isinstance(node.args[0],ast.List)and node.args[0].elts
      and isinstance(node.args[0].elts[0],ast.Constant)and node.args[0].elts[0].value=='git'):
   assert all(k.arg!='env'for k in node.keywords)
   calls.append(sum(len(l)for l in lines[:node.end_lineno-1])+node.end_col_offset-1)
 for end in sorted(calls,reverse=True):
  assert text[end]==')';prefix=text[:end];trimmed=prefix.rstrip();space=prefix[len(trimmed):]
  addition=(' 'if trimmed.endswith(',')else', ')+'env=git_environment()'+(','if trimmed.endswith(',')else'')
  text=trimmed+addition+space+text[end:]
 return text,len(calls)
git_sites={}
for p in ['tools/performance_gate.py','tools/perf_contract.py','tools/test_redraw_output.py']:
 before=original(p)
 candidate=changes[p]['after'] if p in changes else before
 after,count=add_git_environment(candidate)
 expected_count = 4 if p.endswith('performance_gate.py') else 1 if p.endswith('test_redraw_output.py') else 3
 assert count == expected_count
 after=after.replace('import subprocess\n','import subprocess\nfrom common.git import git_environment\n',1)
 changes[p]={'before':before,'after':after};git_sites[p]=count
p='tools/perf_contract_collect.py';text=changes[p]['after'];old='    try: return subprocess.check_output(args,text=True,stderr=subprocess.STDOUT,timeout=15).strip()'
assert text.count(old)==1
text=text.replace(old,'    options = {"text": True, "stderr": subprocess.STDOUT, "timeout": 15}\n'
 '    # Только Git привязан к исходникам: системные запросы сохраняют прежний контекст.\n'
 '    if args and args[0] == "git":\n        options.update(cwd=ROOT, env=git_environment())\n'
 '    try: return subprocess.check_output(args, **options).strip()')
text=text.replace('import subprocess\n','import subprocess\nfrom common.git import git_environment\n',1);changes[p]['after']=text;git_sites[p]=1
for p in ['tools/performance_gate.sh','tools/smoke_test.sh']:
 before=original(p);old='repo_root="$(git rev-parse --show-toplevel)"';assert before.count(old)==1
 after=before.replace(old,'repo_root="$(python3 "${0:A:h}/run.py" --root)"');changes[p]={'before':before,'after':after}
for p,row in changes.items():
 assert row['before'].encode()==subprocess.check_output(['git','-C',str(ROOT),'show',BASE+':'+p])
 if p.endswith('.py'):compile(row['after'],str(ROOT/p),'exec')
 row.update(before_sha256=hashlib.sha256(row['before'].encode()).hexdigest(),after_sha256=hashlib.sha256(row['after'].encode()).hexdigest())
output=Path('/private/tmp/refactor03-performance-prepare-plan370.json');assert not output.exists()
output.write_text(json.dumps({'base':BASE,'applied':False,'root_changes':root_files,'git_sites':git_sites,'changes':changes},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'private_plan_only':True,'files':len(changes),'Root':8,'Git_read_sites':sum(git_sites.values()),'shell_roots':2,'compile':'PASS','repository_untouched':True}))
