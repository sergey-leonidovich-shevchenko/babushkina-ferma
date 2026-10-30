"""Remove only audited unused imports, preserving every non-import AST node and old test method."""
import ast
import hashlib
import json
from pathlib import Path

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
profile=json.loads((R/'after-profile.json').read_text())
assert len(profile['commands'])==22 and len(profile['GD'])==114 and all(r['exit']==0 for r in profile['commands']+profile['GD'])
unused=json.loads((R/'unused-import-audit.json').read_text())['unused_candidates']
assert len(unused)==13
names={row['path'] for row in unused}
rows={}
class WithoutImports(ast.NodeTransformer):
 def visit_Import(self,node):return None
 def visit_ImportFrom(self,node):return None
for name in sorted(names):
 path=Q/name;before=path.read_text();lines=before.splitlines(keepends=True);offsets=[0]
 for line in lines:offsets.append(offsets[-1]+len(line))
 edits=[]
 for node in ast.walk(ast.parse(before)):
  if not isinstance(node,(ast.Import,ast.ImportFrom)):continue
  removals={r['name'] for r in unused if r['path']==name and r['line']==node.lineno}
  if not removals:continue
  node.names=[alias for alias in node.names if (alias.asname or (alias.name.split('.')[0] if isinstance(node,ast.Import) else alias.name)) not in removals]
  a=offsets[node.lineno-1]+node.col_offset;b=offsets[node.end_lineno-1]+node.end_col_offset
  edits.append((a,b,ast.unparse(node) if node.names else ''))
 after=before
 for a,b,text in sorted(edits,reverse=True):after=after[:a]+text+after[b:]
 assert ast.dump(WithoutImports().visit(ast.parse(before)),include_attributes=False)==ast.dump(WithoutImports().visit(ast.parse(after)),include_attributes=False)
 rows[name]={'before':before,'after':after,'before_SHA256':hashlib.sha256(before.encode()).hexdigest(),
   'after_SHA256':hashlib.sha256(after.encode()).hexdigest(),'removed':[r['name'] for r in unused if r['path']==name],
   'all_non_import_AST_equal':True}
 path.write_text(after)
(R/'unused-import-cleanup.json').write_text(json.dumps({'imports_removed':13,'modules':rows,'special_unit_added':False,
 'profile_precedes_import_only_cleanup':True,'full_gates_follow_final_sources':True},indent=2)+'\n')
print(json.dumps({'modules':len(rows),'imports_removed':13,'test_assertions_changed':0}))
