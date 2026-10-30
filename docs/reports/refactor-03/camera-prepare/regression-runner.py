"""Run one unchanged camera-context test source before/after the address-only preparation."""
import argparse,hashlib,json,os,re,subprocess,sys,time
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
TEST=Path('/private/tmp/refactor03-test-camera-context373.py')
p=argparse.ArgumentParser();p.add_argument('phase',choices=['red','green']);a=p.parse_args()
raw=Path('/private/tmp/refactor03-camera-'+a.phase+'373.txt');assert not raw.exists()
source=TEST if a.phase=='red'else Q/'tools/qa/camera/test_camera_context.py'
child='import runpy,sys;sys.path[:0]=[sys.argv[1],sys.argv[1]+"/tools"];p=sys.argv.pop(2);sys.argv.pop(1);runpy.run_path(p,run_name="__main__")'
start=time.monotonic()
with raw.open('x')as f:r=subprocess.run([sys.executable,'-c',child,str(Q),str(source)],cwd=Q,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),stdout=f,stderr=subprocess.STDOUT,timeout=600)
text=raw.read_text();result={'phase':a.phase,'base':subprocess.check_output(['git','-C',str(Q),'rev-parse','HEAD'],text=True).strip(),'test_SHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'exit':r.returncode,'seconds':time.monotonic()-start,'raw_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'summary':text[-2000:],'methods':int(re.search(r'Ran (\d+) tests? in',text)[1])if re.search(r'Ran (\d+) tests? in',text)else None}
Path('/private/tmp/refactor03-camera-'+a.phase+'373.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));raise SystemExit(0)
