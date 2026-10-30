"""Execute the same World-context test bytes before/after source-root/Git preparation."""
import argparse,hashlib,json,os,re,subprocess,sys,time
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
TEST=Path('/private/tmp/refactor03-test-world-context375.py')
p=argparse.ArgumentParser();p.add_argument('phase',choices=['red','green']);a=p.parse_args()
raw=Path('/private/tmp/refactor03-world-'+a.phase+'375.txt');assert not raw.exists()
source=TEST if a.phase=='red'else Q/'tools/qa/world/test_world_context.py'
child='import runpy,sys;sys.path[:0]=[sys.argv[1],sys.argv[1]+"/tools"];p=sys.argv.pop(2);sys.argv.pop(1);runpy.run_path(p,run_name="__main__")'
start=time.monotonic()
with raw.open('x')as f:result=subprocess.run([sys.executable,'-c',child,str(Q),str(source)],cwd=Q,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),stdout=f,stderr=subprocess.STDOUT,timeout=600)
out=raw.read_text();match=re.search(r'Ran (\d+) tests? in',out)
receipt={'phase':a.phase,'base':subprocess.check_output(['git','-C',str(Q),'rev-parse','HEAD'],text=True).strip(),'test_SHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'exit':result.returncode,'seconds':time.monotonic()-start,'raw_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'summary':out[-2400:],'methods':int(match[1])if match else None}
Path('/private/tmp/refactor03-world-'+a.phase+'375.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
