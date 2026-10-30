"""Record the additional compatibility facade, with no changes to the historical migration map."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
for name in ['wiki/articles/project-refactoring.md','tools/README.md','docs/epics/refactoring-2026-10/TASKS.md']:
 p=ROOT/name;text=p.read_text();start=text.index('Пакет0.0.371 переносит33 performance source');end=text.index('\n\n',start)
 section=text[start:end].replace('три публичных фасада','четыре публичных фасада').replace('root314→284','root314→285').replace('Семь новых layout-контролей','Восемь новых layout-контролей')
 section+=' Общий gates-01 выявил frozen import `performance_protocol` до импорта gate; дополнительный четвёртый фасад сохраняет эти исполняемые отчёты. Исходная карта/архивы не переписаны, исключение ожидает независимого ревью. Один source8-case теста воспроизвёл1fail/1error→8/0.'
 text=text[:start]+section+text[end:]
 text=text.replace('В текущем кандидате корень tools составляет284 исходника при конечном лимите30; прогноз полного выпуска10 ещё не достигнут.',
 'В текущем кандидате корень tools составляет285 исходников при конечном лимите30; исторический прогноз10 с обязательным protocol facade увеличен до11, полного переноса ещё нет.')
 p.write_text(text)
p=ROOT/'TESTING.md';text=p.read_text();a=text.index('REFACTOR-03 performance0.0.371:');b=text.index('\n\n',a)
section=text[a:b].replace('добавляет7','добавляет8').replace('и `tools/smoke_test.sh` остаются фасадами','`tools/performance_protocol.py` и `tools/smoke_test.sh` остаются фасадами').replace('root284','root285')
section+=' Четыре настоящих frozen import graph, включая protocol-first, защищены новым regression source:1fail/1error→8/0. Первый общий gates-01 с импортным отказом сохранён; окончательная серия — gates-02.'
p.write_text(text[:a]+section+text[b:])
# Keep the initial raw/source freeze and regenerate a final scope/freeze only before restarting all gates.
old=R/'source-freeze.json';assert old.read_bytes()==(R/'source-freeze-before-legacy-facade.json').read_bytes();old.unlink()
script=Path('/private/tmp/refactor03-performance-audit371.py').read_text()
script=script.replace("public={n for n,r in base['assignments'].items()if r['action']=='move_implementation_keep_public_facade'}", "public={n for n,r in base['assignments'].items()if r['action']=='move_implementation_keep_public_facade'}|{'tools/performance_protocol.py'}")
script=script.replace('root_count==284','root_count==285').replace("'root_sources':284","'root_sources':285").replace("'root_sources_after_moves':284","'root_sources_after_moves':285").replace("'public_facades':3","'public_facades':4").replace("'new_layout_tests':7","'new_layout_tests':8")
Path('/private/tmp/refactor03-performance-audit-final371.py').write_text(script)
shutil.copyfile(__file__,R/'finalize-source.py')
print(json.dumps({'root':285,'facades':4,'tests':8,'requires_full_gates02':True}))
