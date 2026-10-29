"""Plan a bounded camera move; defer the two shared anchors until their consumer groups move."""
import ast,hashlib,json,re,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
BASE='d2ff4bde558196f808bef0486db1c0aaa0302ab9'
assert subprocess.check_output(['git','-C',str(Q),'rev-parse','HEAD'],text=True).strip()==BASE
original=json.loads((Q/'docs/reports/refactor-03/baseline/migration.json').read_text())
deferred={'tools/visual_camera_points.gd','tools/encode_coordinate_video.swift'}
rows=[r for r in original['assignments']if r['family']=='camera'and r['old_path']not in deferred]
mapping={r['old_path']:r['target']for r in rows};modules={Path(n).stem for n in mapping if n.endswith('.py')}
changes={};counts={}
def replace_nodes(text, replacements):
 lines=text.splitlines(keepends=True);offset=lambda line,col:sum(map(len,lines[:line-1]))+col
 chunks=[(offset(n.lineno,n.col_offset),offset(n.end_lineno,n.end_col_offset),value)for n,value in replacements]
 for start,end,value in sorted(chunks,reverse=True):text=text[:start]+value+text[end:]
 return text
for p in sorted((Q/'tools').rglob('*.py')):
 if '__pycache__'in p.parts:continue
 name=str(p.relative_to(Q));before=p.read_text();text=before;replacements=[]
 for n in ast.walk(ast.parse(text)):
  if isinstance(n,ast.ImportFrom)and n.module in modules:
   source=ast.get_source_segment(text,n);replacements.append((n,source.replace('from '+n.module+' import','from tools.qa.camera.'+n.module+' import',1)))
  elif isinstance(n,ast.ImportFrom)and name in mapping and n.module and n.module.startswith('common.'):
   source=ast.get_source_segment(text,n);replacements.append((n,source.replace('from common.','from tools.common.',1)))
  elif isinstance(n,ast.Import)and any(a.name in modules for a in n.names):
   assert len(n.names)==1;n0=n.names[0];replacements.append((n,'from tools.qa.camera import '+n0.name+(' as '+n0.asname if n0.asname else'')))
 text=replace_nodes(text,replacements);import_count=len(replacements)
 # Only physical ROOT input reads change. Logical SOURCES and archive destinations remain original.
 inputs=[]
 if name in mapping:
  for n in ast.walk(ast.parse(text)):
   if isinstance(n,ast.BinOp)and isinstance(n.op,ast.Div)and isinstance(n.left,ast.Name)and n.left.id=='ROOT':
    if isinstance(n.right,ast.Name)and n.right.id in{'p','path','name','n'}or isinstance(n.right,ast.Constant)and n.right.value in mapping:
     inputs.append((n,'current_source(ROOT, '+ast.get_source_segment(text,n.right)+')'))
  text=replace_nodes(text,inputs)
  if inputs:text=text.replace('from __future__ import annotations\n','from __future__ import annotations\nfrom tools.assets.contracts.source_paths import current_source\n',1)if'from __future__ import annotations\n'in text else text.replace('from pathlib import Path\n','from pathlib import Path\nfrom tools.assets.contracts.source_paths import current_source\n',1)
  # Only capture launch URI changes; legacy validator/test URIs keep their meaning below.
  for function in [n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef)and n.name in{'capture','run_capture','capture_controls','controls','main'}]:
   old=ast.get_source_segment(text,function);new=old
   for source,target in mapping.items():
    if source.endswith('.gd'):new=new.replace('res://'+source,'res://'+target)
   # Bare script argv is a physical launch path, unlike SOURCES dictionaries.
   for source,target in mapping.items():
    if source.endswith('.gd'):new=new.replace("'--script', '"+source+"'","'--script', '"+target+"'").replace("'--script','"+source+"'","'--script','"+target+"'")
   text=text.replace(old,new,1)
 if name=='tools/visual_hardware.py':
  old="[sys.executable, str(current_source(ROOT, 'tools/run_visual_baseline.py')), '--output', str(folder / 'native')]"
  assert text.count(old)==1;text=text.replace(old,"[sys.executable, str(ROOT / 'tools/run.py'), 'qa.camera.run_visual_baseline', '--output', str(folder / 'native')]")
 if name=='tools/qa/camera/test_camera_context.py':
  text=text.replace('from tools.common.git import git_environment\n','from tools.common.git import git_environment\nfrom tools.assets.contracts.source_paths import current_source\n')
  substitutions={"baseline.ROOT / 'tools' / (name + '.py')":"current_source(baseline.ROOT, 'tools/' + name + '.py')",'target = own / name':'target = current_source(own, name)','(original / name).read_bytes()':'current_source(original, name).read_bytes()','(own / name).read_bytes()':'current_source(own, name).read_bytes()'}
  for old,new in substitutions.items():assert old in text,old;text=text.replace(old,new)
 if name in {'tools/test_reference_zoom.py','tools/test_presentation_pose.py'}:
  module='Z'if name.endswith('test_reference_zoom.py')else'P'
  text=text.replace('from pathlib import Path\n','from pathlib import Path\nfrom tools.assets.contracts.source_paths import current_source\n',1)
  helper=('def current_inputs(folder):\n    """Mirror archived runtime bytes at canonical input paths, keeping the proof archive unchanged."""\n'
          "    root = folder.parent / 'current inputs'\n    root.mkdir()\n"
          f"    for name in {module}.SOURCES:\n        target = current_source(root, name)\n        target.parent.mkdir(parents=True, exist_ok=True)\n        shutil.copy2(folder / 'instrumentation' / name, target)\n    return root\n\n\n")
  marker=re.search(r'(?m)^class ',text).start();text=text[:marker]+helper+text[marker:]
  old=f"patch.object({module},'ROOT',folder/'instrumentation')";assert text.count(old)==(1 if module=='Z'else 2)
  text=text.replace(old,f"patch.object({module},'ROOT',current_inputs(folder))")
 if text!=before:compile(text,name,'exec');changes[name]={'before':before,'after':text};counts[name]={'imports':import_count,'physical_reads':len(inputs)}
# The timing reader binds old/new launch URI to the full, closed source-path metadata.
p='tools/reference_zoom_perf.py';text=changes[p]['after']
text=text.replace('from tools.assets.contracts.source_paths import current_source\n','from tools.assets.contracts.source_paths import current_source, captured_paths, recorded_paths\n')
marker='REPEATS=3\n';assert text.count(marker)==1
text=text.replace(marker,marker+"_TIMING_PATHS = tuple(p for p in LEGACY_SOURCES if p.startswith('tools/') and p not in {'tools/visual_camera_points.gd', 'tools/encode_coordinate_video.swift'})\n")
text=text.replace("    archived={str(p.relative_to(folder/'instrumentation'))", "    recorded_paths(_TIMING_PATHS, source.get('source_paths', {}))\n    archived={str(p.relative_to(folder/'instrumentation'))",1)
text=text.replace('def validate_environment(env, size, amount, profile, engine_log):','def validate_environment(env, size, amount, profile, engine_log, source_paths=None):')
old="    command=env.get('command',[])";assert text.count(old)==1
text=text.replace(old,"    paths = recorded_paths(_TIMING_PATHS, {} if source_paths is None else source_paths)\n    script = 'res://' + paths.get('tools/reference_zoom_live.gd', 'tools/reference_zoom_live.gd')\n"+old)
old="['--script','res://tools/reference_zoom_live.gd']";assert text.count(old)==1;text=text.replace(old,"['--script',script]")
old="validate_environment(Z.read(path/'environment.json'),size,amount,data['profile'],(path/'engine.txt').read_text())";assert text.count(old)==1;text=text.replace(old,old[:-1]+", source.get('source_paths', {}))")
old='    provenance(folder)\n';assert text.count(old)==1;text=text.replace(old,'    source=provenance(folder)\n')
old="validate_environment(env,size,amount,data['profile'],(path/'engine.txt').read_text())";assert text.count(old)==1;text=text.replace(old,old[:-1]+", source.get('source_paths', {}))")
old="'video_provenance_sha256':";assert text.count(old)==1;text=text.replace(old,"'source_paths':captured_paths(_TIMING_PATHS),"+old)
compile(text,p,'exec');changes[p]['after']=text
# Extend the existing immutable map exactly by the chosen camera assignments.
p='tools/assets/contracts/source_paths.py';before=(Q/p).read_text();tree=ast.parse(before);assign=next(n for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='MOVED_PATHS'for t in n.targets));old=ast.literal_eval(assign.value.args[0]);assert len(old)==91
import pprint
after=replace_nodes(before,[(assign.value.args[0],pprint.pformat({**old,**mapping},width=110,sort_dicts=True))]);changes[p]={'before':before,'after':after};assert len({**old,**mapping})==133
p='tools/assets/contracts/test_source_paths.py';before=(Q/p).read_text();old="        self.assertEqual(dict(MOVED_PATHS), expected)\n        self.assertEqual(len(MOVED_PATHS), 91)"
assert before.count(old)==1
new="        self.assertEqual(len(expected), 91)\n        camera = {old: row['target'] for old, row in plan['assignments'].items() if row['family'] == 'camera' and old not in {'tools/visual_camera_points.gd', 'tools/encode_coordinate_video.swift'}}\n        self.assertEqual(len(camera), 42)\n        expected.update(camera)\n        self.assertEqual(dict(MOVED_PATHS), expected)\n        self.assertEqual(len(MOVED_PATHS), 133)"
changes[p]={'before':before,'after':before.replace(old,new)}
for base in ['tools','tests','scripts']:
 for p in sorted((Q/base).rglob('*.gd')):
  before=p.read_text();text=before
  for old,target in mapping.items():
   if old.endswith('.gd'):text=text.replace('res://'+old,'res://'+target)
  if text!=before:changes[str(p.relative_to(Q))]={'before':before,'after':text}
for n,row in changes.items():row.update(before_SHA256=hashlib.sha256(row['before'].encode()).hexdigest(),after_SHA256=hashlib.sha256(row['after'].encode()).hexdigest())
uids=json.loads((Q/'docs/reports/refactor-03/baseline/local-uids.json').read_text());local=[]
for r in uids['local_only_UID']:
 if r['old_path'].removesuffix('.uid')in mapping:
  p=Q/r['old_path'];assert p.read_text().strip()==r['value'];local.append({**r,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'mode':p.stat().st_mode&0o777})
assert len(local)==15
result={'base':BASE,'root_before':285,'root_after':245,'moves':rows,'local_UID':local,'deferred_shared_anchors':[r for r in original['assignments']if r['family']=='camera'and r['old_path']in deferred],'changes':changes,'source_counts':counts,'physical_source_moves':40,'tracked_UID_moves':2,'ignored_UID_moves':15,'new_source_map_entries':42,'source_map_total':133}
out=Path('/private/tmp/refactor03-camera-plan374.json');assert not out.exists();out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'private_plan_only':True,'moves':len(rows),'source':40,'UID':2,'ignored_UID':15,'changed_live_sources':len(changes),'root_after':245}))
