"""Record a preexisting ignored primary probe and reseal report-only publication guards."""
import hashlib
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/launch-boundary-review'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
def sha(raw):return hashlib.sha256(raw).hexdigest()
def entry(name):return {'SHA256':sha((P/name).read_bytes()),'mode':stat.S_IMODE((P/name).stat().st_mode)}
checks=json.loads((R/'checks.json').read_text())
for row in checks['report_files']:assert sha((R/row['path']).read_bytes())==row['sha256'],row['path']
for name,digest in checks['source_SHA256'].items():assert sha((Q/name).read_bytes())==digest,name
assert not Path('/private/tmp/refactor03-publish381-receipt.json').exists()
names=['tools/foliage_coverage_probe.gd','tools/foliage_coverage_probe.gd.uid']
for name in names:
    assert not subprocess.check_output(['git','-C',str(P),'ls-files','--',name],env=git_environment()).strip()
    assert subprocess.run(['git','-C',str(P),'check-ignore','-q','--',name],env=git_environment()).returncode==0
record={'prepare_attempt01_exit':1,'primary_mutated_in_attempt01':False,
    'reason':'primary contains one preexisting ignored local probe and UID absent from isolated QA',
    'QA_UID_count':304,'primary_UID_count':305,
    'primary_extra_ignored_UID':{names[1]:entry(names[1])},
    'primary_extra_ignored_source':{names[0]:entry(names[0])},
    'policy':'preserve all305 primary UID plus local probe; stage neither foreign file',
    'product_source_changed':False,'full_gates_changed':False,'report_only_guard_change':True}
(R/'publication-preflight.json').write_text(json.dumps(record,indent=2)+'\n')
shutil.copy2('/private/tmp/refactor03-publish381-attempt01.py',R/'baseline/publish-attempt01.py')
shutil.copy2('/private/tmp/refactor03-publish381.py',R/'publish.py')
shutil.copy2(__file__,R/'record-publication-preflight.py')
with (R/'README.md').open('a') as stream:
    stream.write('\nPrepare-attempt01 остановился до любых изменений primary: там есть свой ignored tools/foliage_coverage_probe.gd и его UID, отсутствующие в изолированном QA. В QA304 канонических UID, в primary305. Оба локальных ignored файла явно учтены по SHA/mode; публикация сохраняет все305 UID и probe, не добавляя их в Git. Изменён только защитный скрипт публикации и метаданные отчёта; восемь проверенных source SHA, JSON Wiki и полные gates381 прежние.\n')
checks['primary_preexisting_extra_ignored_UID']=1
checks['primary_UID_before_count']=305
checks['report_files']=[{'path':str(p.relative_to(R)),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size}
    for p in sorted(R.rglob('*')) if p.is_file() and p.name!='checks.json']
(R/'checks.json').write_text(json.dumps(checks,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'source_SHA_unchanged':8,'report_files':len(checks['report_files'])+1,'QA_UID':304,'primary_UID':305,'foreign_probe_preserved_by_guard':True}))
