"""Freeze canonical accounting documents while proving the accepted implementation is unchanged."""
import hashlib
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/closeout'
BASE='dd506fdd2cb98f1364c0e367c9f73c670064a6d0'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args],env=git_environment())
def sections(raw):
    parts=raw.decode().split('\n## REFACTOR-')
    return {part[:2]:part for part in parts[1:]}
expected={'VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist','TESTING.md',
    'docs/epics/refactoring-2026-10/TASKS.md','docs/epics/refactoring-2026-10/README.md',
    'tools/README.md','wiki/articles/project-refactoring.md','wiki/articles/index.json'}
assert git(Q,'rev-parse','HEAD').decode().strip()==BASE
changed=set(filter(None,git(Q,'diff','--no-renames','--name-only','-z').decode().split('\0')))
untracked=set(filter(None,git(Q,'ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert changed==expected,(changed-expected,expected-changed)
assert all(n.startswith(str(R.relative_to(Q))+'/') for n in untracked)
card='docs/epics/refactoring-2026-10/TASKS.md'
old=sections(git(Q,'show',BASE+':'+card));new=sections((Q/card).read_bytes())
assert old.keys()==new.keys() and {k for k in old if old[k]!=new[k]}=={'03','06'}
assert '**Статус:** done' in new['03'] and '**Дата завершения:** 2026-10-30' in new['03']
assert '**Статус:** blocked' in old['06'] and '**Статус:** blocked' in new['06']
def criteria(section):return section.split('**Приёмка:**',1)[1].split('**Проверка:**',1)[0]
assert criteria(old['03'])==criteria(new['03']) and criteria(old['06'])==criteria(new['06'])
before06=old['06'].splitlines();after06=new['06'].splitlines()
assert len(before06)==len(after06)
changes=[a.split(':',1)[0] for a,b in zip(before06,after06) if a!=b]
assert changes==['**Условия запуска','**Подтверждения / результат'],changes
for name in ['VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist']:
    assert (Q/name).read_bytes()==git(Q,'show',BASE+':'+name).replace(b'0.0.381',b'0.0.382')
baseline=json.loads((R/'preservation-before.json').read_text())
assert git(P,'branch','--show-current').decode().strip()==baseline['primary_branch']
for name,row in baseline['primary_foreign'].items():
    assert sha((P/name).read_bytes())==row['working_SHA256'] and sha(git(P,'show',':'+name))==row['index_SHA256']
for name,row in baseline['primary_ignored_probe'].items():
    assert sha((P/name).read_bytes())==row['SHA256'] and stat.S_IMODE((P/name).stat().st_mode)==row['mode']
uids={str(p.relative_to(Q)):{'SHA256':sha(p.read_bytes()),'mode':stat.S_IMODE(p.stat().st_mode)}
    for p in (Q/'tools').rglob('*.uid') if p.is_file()}
assert uids==baseline['QA_UID'] and len(uids)==304
report_tree=git(Q,'ls-tree','-r','-z',BASE,'--','docs/reports')
assert not git(Q,'diff','--name-only',BASE,'--','docs/reports').strip()
record={'task':'REFACTOR-03','phase':'canonical closeout','version':'0.0.382','base':BASE,
    'source_SHA256':{n:sha((Q/n).read_bytes()) for n in sorted(expected)},
    'report_content_inputs':{'completion.json':sha((R/'completion.json').read_bytes())},
    'existing_report_entries':len([r for r in report_tree.split(b'\0') if r]),'existing_report_Git_ledger_SHA256':sha(report_tree),
    'changed_statuses':['REFACTOR-03: in_progress→done'],'06_changes':'conditions/result only; blocked preserved; stale owner stop revoked',
    'other_five_cards_unchanged':True,'criteria_unchanged':True,'tools_runtime_tests_art_existing_reports_unchanged':True,
    'QA_UID_preserved':304,'primary_parallel07_preserved':True,'primary_ignored_probe_preserved':True,
    'main_not_changed_by_closeout':True,'closeout_review_CI':'required separately','all_before_full_gates':True}
(R/'source-freeze.json').write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n')
shutil.copy2(__file__,R/'freeze-source.py')
print(json.dumps({'frozen_docs_meta':len(expected),'source_code_changes':0,'UID':304,'old_reports':record['existing_report_entries'],'card03':'done proposed','card06':'blocked'}))
