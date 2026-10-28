"""Run only the relevant fresh gates after a proven one-article text correction."""
from datetime import datetime,timezone
import json,subprocess
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT=ROOT/'docs/reports/refactor-03/compatibility-move'
delta=json.loads((REPORT/'docs-refresh.json').read_text());assert delta['changed_source_paths']==['wiki/articles/project-refactoring.md']
out=REPORT/'gates-04';assert not out.exists();out.mkdir();records=[]
for gate,command in [('documentation',['python3','tools/run.py','quality.check_documentation']),('wiki',['pnpm','--dir','wiki','check'])]:
 row={'gate':gate,'command':command,'version':'0.0.369','started_at':datetime.now(timezone.utc).isoformat()}
 with(out/(gate+'.txt')).open('x')as stream:p=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=900)
 row.update(exit=p.returncode,finished_at=datetime.now(timezone.utc).isoformat());records.append(row);(out/'gate-exits.json').write_text(json.dumps(records,indent=2)+'\n');print(json.dumps(row),flush=True)
 if p.returncode:raise SystemExit(p.returncode)
