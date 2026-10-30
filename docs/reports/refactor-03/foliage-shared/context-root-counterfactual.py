"""Replay only the four old ROOT expressions with corrected child imports on disposable copies."""
import ast
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
test=Q/'tools/qa/foliage/test_foliage_context.py'
tree=ast.parse(test.read_text())
method=next(n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name=='test_four_actual_nested_source_roots')
child=next(ast.literal_eval(n.value) for n in method.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='child' for t in n.targets))
rows=[]
with tempfile.TemporaryDirectory(prefix='03 ROOT counterfactual ') as folder:
 root=Path(folder).resolve();(root/'project.godot').write_text('; marker\n');(root/'VERSION').write_text('qa\n')
 nested=root/'tools/qa/foliage';nested.mkdir(parents=True)
 for name in ['foliage_wind_verify','foliage_pause_verify','foliage_visibility_evidence','plant_depth_verify']:
  source=(Q/'tools/qa/foliage'/name).with_suffix('.py');raw=source.read_text()
  assignments=[n for n in ast.parse(raw).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='ROOT' for t in n.targets)]
  assert len(assignments)==1 and ast.unparse(assignments[0].value)=='project_root(__file__)'
  value=assignments[0].value;lines=raw.splitlines(keepends=True)
  line=lines[value.lineno-1];lines[value.lineno-1]=line[:value.col_offset]+'Path(__file__).resolve().parents[1]'+line[value.end_col_offset:]
  target=nested/source.name;target.write_text(''.join(lines))
  env={k:v for k,v in os.environ.items() if not k.startswith('GIT_')};env['PYTHONDONTWRITEBYTECODE']='1'
  result=subprocess.run([sys.executable,'-c',child,str(target),str(Q)],cwd=root,env=env,capture_output=True,text=True,timeout=30)
  assert result.returncode==0,result.stderr
  reported=Path(json.loads(result.stdout));assert reported==root/'tools/qa' and reported!=root
  rows.append({'module':name,'actual_child_exit':result.returncode,'old_expression_reports_tools_qa_not_project':True,
   'only_copy_changed':True,'source_SHA256':hashlib.sha256(source.read_bytes()).hexdigest()})
record=json.loads((R/'context-child-fixture-repair.json').read_text())
record['after_SHA256']=hashlib.sha256(test.read_bytes()).hexdigest()
record['docstring_correction']='load_reader no longer claims the whole test source has identical SHA'
(R/'context-child-fixture-repair.json').write_text(json.dumps(record,indent=2)+'\n')
(R/'context-root-counterfactual.json').write_text(json.dumps({'purpose':__doc__,'child_is_installed_test_child':True,'rows':rows,
 'not_a_parent_whole_suite_replay':True,'test_assertions_removed':0},indent=2)+'\n')
print(json.dumps({'counterfactual_ROOT_failures_reproduced':len(rows),'product_sources_changed':0}))
