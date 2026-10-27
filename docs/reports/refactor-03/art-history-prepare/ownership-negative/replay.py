import argparse,gzip,hashlib,json,subprocess,sys,tempfile
from pathlib import Path
root=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').is_file());sys.path.insert(0,str(root))
from tools.common.git import git_environment
parser=argparse.ArgumentParser(description='Reproduce the isolated ownership-guard negative control');parser.add_argument('--output',type=Path,required=True);out=parser.parse_args().output.resolve()
if out.exists() or out.is_relative_to(root/'assets'):parser.error('new output outside assets required')
out.mkdir()
current=(root/'tools/common/history.py').read_bytes();tests=(root/'tools/common/test_history.py').read_bytes();git=(root/'tools/common/git.py').read_bytes()
guard=b"    if (root / '.git').is_file():\n        git_dir = Path(git('rev-parse', '--absolute-git-dir').decode().strip()).resolve()\n        backlink = git_dir / 'gitdir'\n        if (not backlink.is_file() or backlink.is_symlink()\n                or Path(backlink.read_text().strip()).resolve() != root / '.git'):\n            raise ValueError('historical source requires a registered linked worktree')\n"
assert current.count(guard)==1
variant=current.replace(guard,b'')
for name,raw in [('history-current.py',current),('history-without-registration.py',variant),('test_history.py',tests),('git.py',git)]:
 (out/(name+'.gz')).write_bytes(gzip.compress(raw,mtime=0))
rows=[]
with tempfile.TemporaryDirectory(prefix='history guard negative capsule ') as temporary:
 for name,raw in [('without-registration',variant),('current',current)]:
  folder=Path(temporary)/name;(folder/'tools/common').mkdir(parents=True)
  (folder/'tools/__init__.py').write_text('');(folder/'tools/common/__init__.py').write_text('')
  (folder/'tools/common/history.py').write_bytes(raw);(folder/'tools/common/test_history.py').write_bytes(tests);(folder/'tools/common/git.py').write_bytes(git)
  run=subprocess.run([sys.executable,'-m','tools.common.test_history'],cwd=folder,env=git_environment(),capture_output=True,text=True,timeout=120)
  text=run.stdout+run.stderr;(out/(name+'.txt')).write_text(text)
  if name=='current':assert run.returncode==0 and 'Ran 21 tests' in text and 'OK' in text
  else:assert run.returncode==1 and 'test_unregistered_git_file_cannot_borrow_another_checkout' in text and 'FAILED (failures=1)' in text and 'Ran 21 tests' in text
  rows.append(dict(variant=name,exit=run.returncode,source_sha256=hashlib.sha256(raw).hexdigest(),test_sha256=hashlib.sha256(tests).hexdigest()))
assert not Path(temporary).exists() and (root/'tools/common/history.py').read_bytes()==current
(out/'result.json').write_text(json.dumps(dict(kind='explicit mutation control, not an archived original red source',only_registration_guard_removed=True,production_unchanged=True,temporary_removed=True,cases=rows),indent=2)+'\n')
print('Same 21 real tests: ownership guard removed -> one failure; current -> pass; production unchanged')
