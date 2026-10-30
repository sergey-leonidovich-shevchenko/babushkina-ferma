"""Read-only generation of the planned helper; never write the repository before red/baseline."""
import hashlib,json
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
plan=json.loads((Q/'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())
world={name:row['target']for name,row in plan['assignments'].items()if row['family']=='world'and row['action']in{'move','move_uid_with_source'}}
assert len(world)==141
template=Path('/private/tmp/refactor03-source-inputs376-template.py').read_text()
assert template.count('__WORLD_TARGETS__')==1
source=template.replace('__WORLD_TARGETS__',json.dumps(world,ensure_ascii=False,indent=1))
compile(source,'tools/qa/world/source_inputs.py','exec')
output=Path('/private/tmp/refactor03-source-inputs376.py');assert not output.exists();output.write_text(source)
print(json.dumps({'planned_history_aliases':141,'new_helper_bytes':len(source.encode()),'sha256':hashlib.sha256(source.encode()).hexdigest(),'repository_changed':False}))
