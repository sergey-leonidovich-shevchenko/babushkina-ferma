"""Retain the sandbox-only failure, then freeze documentation before a permitted full rerun."""
import json
from pathlib import Path
import shutil

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/ground-move'
failed=json.loads((R/'gates-02/gate-exits.json').read_text())
assert len(failed)==1 and failed[0]['exit']==1
raw=(R/'gates-02/architecture.txt').read_text()
assert 'Ran 19 tests' in raw and 'FAILED (errors=1)' in raw and 'process inventory unavailable' in raw
shutil.copy2(R/'source-freeze.json',R/'before-gates03-source-freeze.json')
for n,suffix in [('source-bridge-world-sandbox.txt',''),('source-bridge-world-permitted.txt','-escalated')]:
    shutil.copy2('/private/tmp/refactor03-bridge-world-probe379'+suffix+'.txt',R/n)
assert '\nOK\n' in (R/'source-bridge-world-permitted.txt').read_text()
for name in ['TESTING.md','QA_CHECKLIST.md','tools/README.md','wiki/articles/project-refactoring.md']:
    p=Q/name;s=p.read_text()
    assert s.count('исправление проверяется новой полной серией gates-02')==1
    s=s.replace('исправление проверяется новой полной серией gates-02',
        'исправление проверяется новой полной серией gates-03. Gates-02 остановился на прежнем World context: sandbox блокировал ps; тот же тест с штатным доступом прошёл, source не менялся')
    p.write_text(s)
p=R/'README.md';s=p.read_text().replace('raw после исправления появятся в `gates-02`','raw после исправления появятся в `gates-03`')
s+='\nGates-02: architecture остановился после 19 World context tests с одной ошибкой process inventory unavailable. В sandbox ps недоступен ещё до проверки source envelope. [Точный отдельный повтор](source-bridge-world-sandbox.txt) воспроизвёл отказ; [тот же тест с обычным доступом к процессам](source-bridge-world-permitted.txt) прошёл1/0. Игровой код и тесты не менялись. Полная обязательная серия gates-03 запускается с этим доступом; gates-02 сохранён целиком.\n'
p.write_text(s)
p=Q/'docs/epics/refactoring-2026-10/TASKS.md';s=p.read_text();a=s.index('## REFACTOR-03 ');b=s.index('## REFACTOR-04 ')
section=s[a:b].replace('обязательна новая полная gates-02','обязательна новая полная gates-03 (gates-02: ps запрещён sandbox; точный permitted replay1/0)')
p.write_text(s[:a]+section+s[b:])
p=Path('/private/tmp/refactor03-ground-seal379.py');s=p.read_text().replace('gates-02/','gates-03/').replace("'authoritative_gates': 'gates-02'","'authoritative_gates': 'gates-03'")
anchor="failed = load('gates-01/gate-exits.json')"
s=s.replace(anchor,"sandbox_failure = load('gates-02/gate-exits.json')\nassert len(sandbox_failure) == 1 and sandbox_failure[0]['exit'] == 1\nassert 'process inventory unavailable' in (R / 'gates-02/architecture.txt').read_text()\nassert '\\nOK\\n' in (R / 'source-bridge-world-permitted.txt').read_text()\n"+anchor)
p.write_text(s)
shutil.copy2(__file__,R/'prepare-gates03.py')
print('gates02 failure preserved; same source test permitted PASS; docs target gates03')
