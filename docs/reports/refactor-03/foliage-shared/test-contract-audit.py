"""Bounded AST proofs for the current map, existing contract test, and new context fixture repair."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment

def old(name):
 return subprocess.check_output(['git','show','108ad126d00eb141658928aa3d68588c5af34db7:'+name],cwd=Q,env=git_environment()).decode()
def dump(tree):return ast.dump(tree,include_attributes=False)
def sha(text):return hashlib.sha256(text.encode()).hexdigest()

name='tools/assets/contracts/source_paths.py';before=ast.parse(old(name));after=ast.parse((Q/name).read_text())
a=next(n for n in before.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='MOVED_PATHS' for t in n.targets))
b=next(n for n in after.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='MOVED_PATHS' for t in n.targets))
before_map=ast.literal_eval(a.value.args[0]);after_map=ast.literal_eval(b.value.args[0])
mapping=json.loads((R/'move-plan.json').read_text())['mapping']
assert len(before_map)==380 and len(after_map)==491 and after_map==dict(before_map,**mapping)
b.value=a.value;assert dump(before)==dump(after)

name='tools/assets/contracts/test_source_paths.py';before_text=old(name);after_text=(Q/name).read_text()
addition="""        foliage = {old: row['target'] for old, row in plan['assignments'].items() if row['family'] == 'foliage' and old != row['target']}
        self.assertEqual(len(foliage), 102)
        expected.update(foliage)
        expected.update({old: plan['assignments'][old]['target'] for old in world_deferred})
        expected.update({old: plan['assignments'][old]['target'] for old in ['tools/visual_camera_points.gd', 'tools/encode_coordinate_video.swift']})
"""
assert after_text.count(addition)==1
normalized=after_text.replace(addition,'').replace('self.assertEqual(len(MOVED_PATHS), 491)','self.assertEqual(len(MOVED_PATHS), 380)')
assert normalized==before_text

test_before=(R/'baseline/test_foliage_context.py').read_text();test_after=(Q/'tools/qa/foliage/test_foliage_context.py').read_text()
normalized=test_after.replace('import importlib.util,json,sys;sys.path[:0]=[sys.argv[2],sys.argv[2]+"/tools"];',
    'import importlib.util,json,sys;').replace("str(target),str(ROOT)],cwd=root,","str(target)],cwd=root,")
normalized=normalized.replace('Resolve the actual implementation through the known relocation map.',
    'Locate the actual implementation; the test source is identical before and after relocation.')
assert dump(ast.parse(normalized))==dump(ast.parse(test_before))
rows={'source_map_old':380,'source_map_current':491,'map_additions_exact_original':111,
 'map_functions_unchanged':True,'existing_contract_test_only_expands_plan_and_count':True,
 'context_test_methods_removed':0,'context_before_SHA256':sha(test_before),'context_after_SHA256':sha(test_after),
 'context_normalization':['explicit child sys.path from code checkout','explicit source root argument','honest load_reader docstring'],
 'four_old_ROOT_counterfactual':'context-root-counterfactual.json'}
(R/'test-contract-audit.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps(rows))
