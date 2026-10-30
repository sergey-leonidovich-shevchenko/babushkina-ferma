"""Apply the complete remaining original move plan after the successful real before profile."""
import ast
import hashlib
import json
from pathlib import Path
import pprint
import shutil
import stat

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
inventory=json.loads((R/'baseline/inventory.json').read_text())
plan=json.loads(Path('/private/tmp/refactor03-plan380.json').read_text())
profile=json.loads((R/'before-profile.json').read_text())
assert len(profile['commands'])==22 and len(profile['GD'])==114
assert all(r['exit']==0 for r in profile['commands']+profile['GD'])
sha=lambda raw:hashlib.sha256(raw).hexdigest()
mapping=plan['mapping'];ignored=inventory['moves']['ignored_UID']
for name,row in plan['changes'].items():assert sha((Q/name).read_bytes())==row['before_SHA256'],name
for old,target in dict(mapping,**{n:r['target'] for n,r in ignored.items()}).items():
    assert(Q/old).is_file() and not(Q/target).exists(),old
for name,row in plan['changes'].items():(Q/name).write_text(row['after'])

# Only the111 original assigned rows enter the public source map; four ignored local UIDs stay local.
p=Q/'tools/assets/contracts/source_paths.py';text=p.read_text();tree=ast.parse(text)
node=next(n for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='MOVED_PATHS' for t in n.targets))
dictionary=node.value.args[0];old=ast.literal_eval(dictionary);assert len(old)==380 and not(set(old)&set(mapping))
full=dict(old,**mapping);assert len(full)==491
text=text.replace(ast.get_source_segment(text,dictionary),pprint.pformat(full,sort_dicts=True,width=120),1)
text=text.replace('# Принятые asset71/alpha-slicing19 и один перенесённый performance helper; metadata не выбирает таблицу.',
    '# Фиксированная карта принятых переносов; metadata не выбирает физический адрес.')
p.write_text(text)
p=Q/'tools/assets/contracts/test_source_paths.py';text=p.read_text()
marker='        self.assertEqual(dict(MOVED_PATHS), expected)\n';assert text.count(marker)==1
extra='''        foliage = {old: row['target'] for old, row in plan['assignments'].items() if row['family'] == 'foliage' and old != row['target']}
        self.assertEqual(len(foliage), 102)
        expected.update(foliage)
        expected.update({old: plan['assignments'][old]['target'] for old in world_deferred})
        expected.update({old: plan['assignments'][old]['target'] for old in ['tools/visual_camera_points.gd', 'tools/encode_coordinate_video.swift']})
'''
text=text.replace(marker,extra+marker).replace('self.assertEqual(len(MOVED_PATHS), 380)','self.assertEqual(len(MOVED_PATHS), 491)')
p.write_text(text)

for old,target in sorted(mapping.items()):
    destination=Q/target;destination.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(Q/old),destination)
for old,row in sorted(ignored.items()):
    destination=Q/row['target'];destination.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(Q/old),destination)
    assert sha(destination.read_bytes())==row['SHA256'] and stat.S_IMODE(destination.stat().st_mode)==row['mode']
folder=Q/'tools/grass_compare'
if folder.exists() and not any(folder.iterdir()):folder.rmdir()

p=Q/'.gitignore';text=p.read_text()
rules=['!tools/qa/foliage/','tools/qa/foliage/*','!tools/qa/foliage/*.py','!tools/qa/foliage/*.gd',
    '!tools/qa/foliage/*.gdshader','!tools/qa/foliage/grass_compare/','tools/qa/foliage/grass_compare/*',
    '!tools/qa/foliage/grass_compare/*.gd','!tools/qa/foliage/grass_compare/*.gdshader','!tools/qa/camera/*.swift']
rules+=['!'+target for old,target in sorted(mapping.items()) if old.endswith('.uid')]
p.write_text(text+'\n# REFACTOR-03: complete Foliage and shared QA owners.\n'+'\n'.join(rules)+'\n')
for source,target in [('/private/tmp/refactor03-test-foliage-context380.py','tools/qa/foliage/test_foliage_context.py'),
    ('/private/tmp/refactor03-test-relocation-provenance380.py','tools/qa/foliage/test_relocation_provenance.py')]:
    shutil.copy2(source,Q/target)
p=Q/'tools/quality/check_architecture.sh';text=p.read_text()
for old,target in mapping.items():
    if old.endswith('.py'):
        old_command='python3 '+old
        new_command='python3 tools/run.py '+target.removeprefix('tools/').removesuffix('.py').replace('/','.')
        text=text.replace(old_command,new_command)
marker='python3 tools/run.py qa.ground.test_compiled_sources\n';assert text.count(marker)==1
text=text.replace(marker,marker+'python3 tools/run.py qa.foliage.test_foliage_context\npython3 tools/run.py qa.foliage.test_relocation_provenance\n')
p.write_text(text)
shutil.copy2('/private/tmp/refactor03-plan380.json',R/'move-plan.json')
shutil.copy2(__file__,R/'apply.py')
print(json.dumps({'registered_moves':111,'local_UID_moves':4,'source_moves':77,'root':11,'map':491,
    'code_changes':len(plan['changes']),'new_test_modules':2,'version_not_yet_bumped':True}))
