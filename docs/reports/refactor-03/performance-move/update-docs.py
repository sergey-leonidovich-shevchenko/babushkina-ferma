"""Document the physical performance migration; preserve other task cards and the approved route."""
import shutil,subprocess
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
paragraph=('Пакет0.0.371 переносит33 performance source,14 tracked UID и4 ignored UID в `tools/qa/performance`; '
 'три публичных фасада и защищённый sampler остаются: root314→284. Обновлены54 живых Python-потребителя, '
 'включая запуск прежних root CLI из чужой cwd/Git. Старые FROZEN-ключи/архивы сохраняются; новый collector '
 'читает canonical входы, записывает прежний namespace и явный closed layout `qa-performance-v1`. '
 'Семь новых layout-контролей защищают реальный producer/archive/child argv и mutable SAMPLER; '
 'fake-open свидетель не является нативной/FPS-приёмкой. [Профиль переноса371](../../docs/reports/refactor-03/performance-move/after-profile.json) '
 'сопоставляет настоящие CLI,14 SIGKILL save workers и headless smoke180;18 GD проходят свежий parse. '
 '370 head9a2ad81f принят промежуточным review5690964419/Team; его итоговый CI учитывается отдельно. '
 'Для371 обязательны собственные полные gates/CI и независимое ревью точного head.03 остаётся in_progress, финального merge нет.\n\n')
p=ROOT/'wiki/articles/project-refactoring.md';text=p.read_text();anchor='Подготовка0.0.370 performance';assert anchor in text
text=text.replace(anchor,paragraph+anchor,1).replace('В текущем кандидате корень tools составляет314 исходников','В текущем кандидате корень tools составляет284 исходника');p.write_text(text)
p=ROOT/'docs/epics/refactoring-2026-10/TASKS.md';text=p.read_text();a,b=text.index('## REFACTOR-03 '),text.index('## REFACTOR-04 ')
text=text[:a]+text[a:b].rstrip()+' '+paragraph.replace('../../docs/reports/','../../reports/')+'\n'+text[b:];p.write_text(text)
p=ROOT/'tools/README.md';text=p.read_text();anchor='# Инструменты проекта\n';assert anchor in text
p.write_text(text.replace(anchor,anchor+'\n'+paragraph.replace('../../docs/reports/','../docs/reports/'),1))
p=ROOT/'TESTING.md';p.write_text('REFACTOR-03 performance0.0.371: canonical Python — `python3 tools/run.py qa.performance.<command>`; '
 'Godot — `res://tools/qa/performance/<profile>.gd`. `qa.performance.test_performance_layout` добавляет7 реальных Git/archive/child контекстов '
 'без FPS-допуска; прежние113 tests сохраняются (108 old +5 context). Публичные `tools/performance_gate.py`, '
 '`tools/performance_gate.sh` и `tools/smoke_test.sh` остаются фасадами, sampler/его UID прежние. '
 'Архивный launch URI остаётся обязательным для legacy; новый closed layout требует canonical URI, '
 'unknown layout и повреждение архивов отклоняются. Профиль хранит прежние raw отказы вложенного import/mock-target '
 'и последующие прогоны. Полные gates/CI/exact-head review обязательны; root284,03in_progress.\n\n'+p.read_text())
subprocess.run(['python3','tools/run.py','planning.bump_version','--set','0.0.371'],cwd=ROOT,check=True)
shutil.copyfile(__file__,R/'update-docs.py')
(R/'README.md').write_text('''# REFACTOR-03: physical performance move, 0.0.371

This is an intermediate increment of draft PR21, based on exact370
`9a2ad81fb77282c4f52261e694653b28b21f01b8`, source-reviewed independently in
review5690964419 and accepted by Team Lead. It does not complete REFACTOR-03.
The final parent CI receipt is retained separately in baseline; it is not CI for371.

The approved map moves33 source files and14 tracked UID into `tools/qa/performance`.
Four ignored local UID follow their sources. Three public facades remain, including
module identity and mutable SAMPLER for the frozen redraw consumer. The protected
sampler and UID stay byte-exact. Root source count changes314→284, still above≤30.
54 live Python consumers import the single canonical implementation; old standalone
commands retain source-bound bootstrap access. Runtime, artwork, budgets and prior
evidence are unchanged. Other six task cards and the separate plan07 are excluded.

FROZEN logical keys and archive destinations stay unchanged. Fresh collection reads
only the two known canonical inputs, marks `qa-performance-v1`, and launches the
canonical capture. Readers bind this closed layout to its URI; missing metadata means
the original URI, unknown metadata is denied. No arbitrary metadata source path or
re-signing of old evidence is introduced. Seven new tests include actual Git/file I/O,
archive corruption/overwrite denials, a real fake-open child argv witness, legacy/current
launch mismatch, headless denial and module identity. Fake child evidence is not GPU/FPS.

`before-profile.json` records12 real commands at370 before moving; `after-profile.json`
will record the final comparable run with all old113 and new7 tests. Both use temporary
HOME/XDG and external copies for generated summaries,14 actual SIGKILL workers and
headless main smoke180. Their semantic outputs and immutable input JSON hashes must
match. `extra-profile.json` records a fresh headless editor import, all18 canonical GD
parses and54 real direct-consumer imports from foreign cwd/Git. No game window/new FPS
admission is claimed. General Game/normal/F10 evidence is recorded only by actual gates.

The first profile stopped at after-16.txt on a nested `performance_protocol` import.
Its path was corrected without changing assertions. The second old34-case run then
found its old string mock-target; nested-target-attempt02.txt and after-attempt02-16.txt
retain that failure. The target was moved to the same canonical PLAN module, preserving
all mutations and assertions. Source capsules/plan attempts are retained. Subsequent
green runs, complete gates and source freeze determine acceptance, never these failed
attempts. The first two full after attempts each preserve their14 real workers/smoke.

Every task still requires its own independent exact-head review, Team Lead decision,
successful CI and final approved merge. Full03 remains draft/in_progress with no
Task-Complete. The autonomous queue stays03→07→06→first overworld throughVMAP003.
''')
