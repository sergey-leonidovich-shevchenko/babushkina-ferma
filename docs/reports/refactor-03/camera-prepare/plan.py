"""Prepare only camera source-root and Git context; do not move the accepted files yet."""
import ast,hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
BASE='57612b6291a88253d5a2f5e46aca21457555f302'
assert subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()==BASE
def original(name):return subprocess.check_output(['git','-C',str(ROOT),'show',BASE+':'+name]).decode()
changes={}
roots=['visual_camera.py','camera_quantization.py','visual_coordinates.py','visual_motion.py','run_visual_baseline.py','check_native_frame_reports.py']
for name in roots:
 p='tools/'+name;before=original(p)
 replacement='from common.paths import project_root\nfrom common.launch import prepare_imports\n\nROOT = project_root(__file__)\nprepare_imports(ROOT)'
 after,n=re.subn(r'(?m)^ROOT\s*=\s*Path\(__file__\)\.resolve\(\)\.parents\[1\]$',lambda _:replacement,before)
 assert n==1,(p,n);changes[p]={'before':before,'after':after}
sites={}
for name,expected in [('visual_camera.py',1),('visual_static.py',1),('visual_coordinates.py',2),('camera_quantization.py',1),('presentation_pose.py',1),('reference_zoom.py',1),('reference_zoom_perf.py',1)]:
 p='tools/'+name;before=original(p);text=changes.get(p,{}).get('after',before);lines=text.splitlines(keepends=True);ends=[]
 for n in ast.walk(ast.parse(text)):
  if isinstance(n,ast.Call)and isinstance(n.func,ast.Attribute)and isinstance(n.func.value,ast.Name)and n.func.value.id=='subprocess'and n.func.attr in{'run','check_output'}and n.args and isinstance(n.args[0],ast.List)and n.args[0].elts and isinstance(n.args[0].elts[0],ast.Constant)and n.args[0].elts[0].value=='git':
   assert all(k.arg!='env'for k in n.keywords);ends.append(sum(map(len,lines[:n.end_lineno-1]))+n.end_col_offset-1)
 assert len(ends)==expected,(name,len(ends))
 for end in sorted(ends,reverse=True):assert text[end]==')';text=text[:end]+', env=git_environment()'+text[end:]
 text=text.replace('import subprocess\n','import subprocess\nfrom common.git import git_environment\n',1)
 changes[p]={'before':before,'after':text};sites[p]=len(ends)
p='tools/run_visual_baseline.py';text=changes[p]['after'];old='        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=15).strip()'
assert text.count(old)==1
text=text.replace(old,'        options = {"text": True, "stderr": subprocess.STDOUT, "timeout": 15}\n        # Git читает проект исходника; системные запросы сохраняют контекст вызывающего процесса.\n        if args and args[0] == "git":\n            options.update(cwd=ROOT, env=git_environment())\n        return subprocess.check_output(args, **options).strip()')
text=text.replace('import subprocess\n','import subprocess\nfrom common.git import git_environment\n',1);changes[p]['after']=text;sites[p]=1
for p,row in changes.items():
 compile(row['after'],p,'exec');row.update(before_sha256=hashlib.sha256(row['before'].encode()).hexdigest(),after_sha256=hashlib.sha256(row['after'].encode()).hexdigest())
output=Path('/private/tmp/refactor03-camera-plan373.json');assert not output.exists();output.write_text(json.dumps({'base':BASE,'applied':False,'roots':roots,'git_sites':sites,'changes':changes},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'files':len(changes),'root_sites':len(roots),'git_sites':sum(sites.values()),'moves':0,'compile':'PASS'}))
