"""Retain the actual failed assumption; complete baseline from its seven original command logs."""
import gzip,hashlib,json,re,shutil
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT=ROOT/'docs/reports/refactor-03/compatibility-move'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not(REPORT/'before-profile.json').exists()
baseline=json.loads((REPORT/'baseline/inventory.json').read_text())
assert all(sha(ROOT/n)==row['sha256']for n,row in baseline['sources'].items())
records=json.loads((REPORT/'before-commands.json').read_text());assert len(records)==7
assert[r['exit']for r in records]==[0,0,0,0,0,0,1]
assert all(sha(REPORT/r['log'])==r['sha256']for r in records)
(REPORT/'before-profile-attempt01.py.gz').write_bytes(gzip.compress((REPORT/'profile.py').read_bytes(),mtime=0))
shutil.copyfile('/private/tmp/refactor03-profile369.py',REPORT/'profile.py')
outcomes={}
for n,index in [('tools/content_reference_audit.gd',1),('tools/qa_teleport_review.gd',2),('tools/held_weapon_review.gd',3),('tools/farm_review.gd',4)]:
 text=(REPORT/records[index]['log']).read_text()
 if index==1:
  data=json.loads(next(l.split('CONTENT REFERENCES: ',1)[1]for l in text.splitlines()if l.startswith('CONTENT REFERENCES: ')));data.pop('validation_usec');outcomes[n]=data
 else:outcomes[n]=list(map(int,re.search(r'(\d+) passed, (\d+) failed',text).groups()))
text=(REPORT/records[-1]['log']).read_text();assert 'assert len(herbs) == 24 and len(catalog["items"]) == 148'in text and'AssertionError'in text
projection=json.loads(gzip.decompress((REPORT/'before-catalog.json.gz').read_bytes()));cycles=json.loads(gzip.decompress((REPORT/'before-cycles.json.gz').read_bytes()))
result={'phase':'before','base':baseline['base'],'commands':records,'outcomes':outcomes,'alchemy_expected_legacy_rejection':True,
 'recipes':len(projection['recipes']),'research':len(projection['research']),'cycle_components':len(cycles['components']),
 'source_comparison':[],'actual_before_after_equal':False,'GPU_FPS_admission':False,'actual_window_opened':False,'foreign_index_created':False,
 'original_failed_assumption_retained':'before-profile-attempt01.py.gz','actual_logs_reused_without_native_rerun':True}
(REPORT/'before-profile.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
shutil.copyfile('/private/tmp/refactor03-move369.py',REPORT/'move.py')
shutil.copyfile('/private/tmp/refactor03-audit369.py',REPORT/'audit.py')
shutil.copyfile('/private/tmp/refactor03-prepare369.py',REPORT/'prepare.py')
shutil.copyfile(__file__,REPORT/'complete-before.py')
print(json.dumps({'outcomes':outcomes,'recipes':len(projection['recipes']),'research':len(projection['research']),'known_legacy_catalog_rejection_retained':True}))
