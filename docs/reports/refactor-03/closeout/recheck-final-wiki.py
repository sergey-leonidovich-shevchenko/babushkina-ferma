"""Rebuild and verify the final editorial Wiki metadata separately from the full-gates epoch."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import urlsplit

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/closeout'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name):return json.loads((R/name).read_text())
assert [g['exit'] for g in load('gates-01/gate-exits.json')]==[0,0,0]
freeze=load('source-freeze.json');assert len(freeze['source_SHA256'])==9
for n,h in freeze['source_SHA256'].items():assert sha((Q/n).read_bytes())==h,n
extra=load('editorial-summary-change.json');assert sha((Q/extra['file']).read_bytes())==extra['after_SHA256']
assert sha((R/'completion.json').read_bytes())==freeze['report_content_inputs']['completion.json']
target=R/'wiki-recheck';target.mkdir()
record={'version':'0.0.382','command':['pnpm','--dir','wiki','check'],
    'started_at':datetime.now(timezone.utc).isoformat(),'metadata_SHA256':extra['after_SHA256'],
    'scope':'Final epic-goal editorial metadata; all code and initial nine frozen documents unchanged'}
with (target/'wiki.txt').open('x') as stream:
    result=subprocess.run(record['command'],cwd=Q,stdout=stream,stderr=subprocess.STDOUT,check=False,timeout=900)
record.update(exit=result.returncode,finished_at=datetime.now(timezone.utc).isoformat())
(R/'wiki-recheck.json').write_text(json.dumps(record,indent=2)+'\n')
assert result.returncode==0
raw=(target/'wiki.txt').read_text();assert 'ℹ pass 145' in raw and 'ℹ fail 0' in raw
catalog=json.loads((Q/'wiki/public/generated/catalog.json').read_text())
planning=json.loads((Q/'wiki/public/generated/planning.json').read_text())['catalog']
article=next(e for e in catalog['entries'] if e['id']=='project-refactoring')
task=next(t for t in planning['tasks'] if t['key']=='refactoring--REFACTOR-03')
next_task=next(t for t in planning['tasks'] if t['key']=='refactoring--REFACTOR-06')
epic=next(e for e in planning['epics'] if e['key']=='refactoring--REFACTOR')
assert catalog['meta']['version']=='0.0.382' and 'REFACTOR-03 принята через PR21' in article['summary']
assert task['status']=='done' and task['completion']['date']=='2026-10-30'
assert next_task['status']=='blocked' and epic['goal']==extra['after']
assert len([t for t in planning['tasks'] if t['plan']=='refactoring'])==7
assert not any(t['id']=='REFACTOR-07' and t['plan']=='refactoring' for t in planning['tasks'])
assert '5708056404' in task['result'] and 'dd506fdd2cb98f1364c0e367c9f73c670064a6d0' in task['result']
href=load('browser.json')['desktop']['link'][0]['href'];relative=urlsplit(href).path.lstrip('/')
assert relative.startswith('generated/attachments/') and '..' not in relative
for area in ['public','dist']:assert (Q/'wiki'/area/relative).read_bytes()==(R/'completion.json').read_bytes()
final_sources={**freeze['source_SHA256'],extra['file']:extra['after_SHA256']}
assert all(sha((Q/n).read_bytes())==h for n,h in final_sources.items())
(R/'final-source-freeze.json').write_text(json.dumps({'source_SHA256':final_sources,
    'full_gates_epoch':'source-freeze.json nine unchanged docs/meta and identical code; one registry goal edited during architecture after initial Wiki passed, independently rechecked here; not a frozen ten-file full run',
    'later_editorial_file':extra['file'],'final_check':'wiki-recheck.json',
    'implementation_code_unchanged_throughout':True,'all_before_publication':True},indent=2,ensure_ascii=False)+'\n')
(R/'catalog-final.json').write_text(json.dumps({'version':'0.0.382','03_status':task['status'],
    '03_date':task['completion']['date'],'06_status':next_task['status'],'registry_cards':7,
    '07_card_added':False,'epic_goal_current':True,'article_summary_current':True,
    'source_public_dist_completion_equal':True,'accepted_source_head':'7976630ce372d3e7ac0c15b154ca7377d398450c'},indent=2)+'\n')
shutil.copy2(__file__,R/'recheck-final-wiki.py')
print(json.dumps({'Wiki':145,'final_docs_meta':len(final_sources),'03':'done','date':'2026-10-30','06':'blocked','epic_goal':'current','JSON_bytes':'equal'}))
