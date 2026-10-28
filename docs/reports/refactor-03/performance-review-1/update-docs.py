"""Document P2 repair while preserving prior evidence, other cards and the autonomous queue."""
import hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-review-1'
p=ROOT/'tools/quality/check_architecture.sh';s=p.read_text();anchor='python3 tools/run.py qa.performance.test_performance_layout\n';assert s.count(anchor)==1
p.write_text(s.replace(anchor,anchor+'python3 tools/run.py qa.performance.test_surface_producers\n'))
paragraph=('Доработка P2 0.0.372 исправляет настоящие grass/ground producer после CHANGES REQUESTED review5691592934 headf134dd9b. '
 'Источник helper читается/хешируется/перепроверяется по canonical пути; копия архива и FROZEN/SOURCES сохраняют прежний ключ `tools/perf_contract_collect.py`. '
 'Ground и grass reader выбирают единственный old/new helper из того же Git commit с чистым Git-окружением; известная карта расширена ровно на один helper до91. '
 'Девять новых real-producer сценариев дают red2fail/9errors (включая subtests)→green9/0: реальные Git/SHA/copy/reader, новая папка, чужая cwd/Git, повреждение, missing canonical и ambiguous aliases. '
 'Fake-open проверяет только child argv/I/O; реальные native/GPU/FPS сессии не запускались. '
 '[Профиль исправления372](../../docs/reports/refactor-03/performance-review-1/profile.json) сопоставляет исходные collect-body из Git9a2 с текущими по7 input-resolution заменам, '
 'четыре реальные prelaunch-архива и6 foreign CLI. Старые подписанные пакеты/доказательства не переписаны. '
 '371 получил CI8/8 и отдельную положительную оценку четвёртого facade, однако весь head с P2 не принят. '
 '372 требует собственных полных gates/CI и повторного независимого ревью точного SHA. Root285,03in_progress/PR21draft, полного merge/Task-Complete нет.\n\n')
p=ROOT/'wiki/articles/project-refactoring.md';s=p.read_text();anchor='Пакет0.0.371 переносит33 performance source';assert anchor in s;p.write_text(s.replace(anchor,paragraph+anchor,1))
p=ROOT/'tools/README.md';s=p.read_text();anchor='# Инструменты проекта\n';assert anchor in s;p.write_text(s.replace(anchor,anchor+'\n'+paragraph.replace('../../docs/reports/','../docs/reports/'),1))
p=ROOT/'docs/epics/refactoring-2026-10/TASKS.md';s=p.read_text();a,b=s.index('## REFACTOR-03 '),s.index('## REFACTOR-04 ');p.write_text(s[:a]+s[a:b].rstrip()+' '+paragraph.replace('../../docs/reports/','../../reports/')+'\n'+s[b:])
p=ROOT/'TESTING.md';p.write_text('REFACTOR-03 P2 0.0.372: `python3 tools/run.py qa.performance.test_surface_producers` вызывает настоящие grass/ground collect и provenance на свежих внешних Git fixtures. '
 'Девять сценариев сохраняют реальные SHA/copy/history и старые logical keys, тестируют overwrite/corruption/missing/ambiguous/foreign Git. '
 'Явный fake-open child не создаёт native frames: полные visual verifier отклоняют такой архив; отдельные prelaunch-контроли останавливаются до native Popen. '
 'Прежние suites/assertions и подписанные evidence обязательны; source_paths содержит прежние90 + ровно1helper. '
 'Собственные полные gates/CI/exact-head review обязательны;371CI8/8 не снимает sourceP2. Root285/03in_progress.\n\n'+p.read_text())
for name in ['QA_CHECKLIST.md','docs/DEVELOPMENT.md']:
 p=ROOT/name;p.write_text(p.read_text()+'\nREFACTOR-03 P2 0.0.372: реальный producer проверяется вызовом collect на новой папке, с настоящими Git/SHA/copy и последующим provenance, '
 'а не только импортом. Запуск: `python3 tools/run.py qa.performance.test_surface_producers`. '
 'Архивные ключи прежние, input helper canonical, old/new Git alias однозначен. Fake-open/empty schedule/context-stop — только I/O/prelaunch, без нового native/FPS-допуска.\n')
subprocess.run(['python3','tools/run.py','planning.bump_version','--set','0.0.372'],cwd=ROOT,check=True)
for source,target in [('/private/tmp/refactor03-ci371-final-for372.json','baseline/ci371-final.json'),('/private/tmp/refactor03-reviews371-for372.json','baseline/reviews371.json')]:shutil.copyfile(source,R/target)
test=ROOT/'tools/qa/performance/test_surface_producers.py';shutil.copyfile(test,R/'baseline/surface-producer-test.py')
(R/'regression.json').write_text(json.dumps({'test_SHA256':hashlib.sha256(test.read_bytes()).hexdigest(),'methods':9,
 'red':{'raw':'producer-red.txt','exit':1,'failures':2,'errors_including_subtests':9},'green':{'raw':'producer-green-01.txt','exit':0},
 'same_test_source':test.read_bytes()==Path('/private/tmp/refactor03-test-surface-producers372.py').read_bytes(),
 'actual_hash_copy_Git_readers':True,'native_Game_GPU_FPS_admission':False},indent=2)+'\n')
(R/'README.md').write_text('''# REFACTOR-03 P2: real surface producer repair, 0.0.372

Exact parentf134dd9b7f2cf0741a0ace939d26fc247178cbad received CHANGES REQUESTED
review5691592934; Team Lead prioritised this same-PR repair. Parent CI8/8 and the
separate positive protocol-facade assessment do not accept the broken producer paths.
Full03 stays draft/in_progress/root285>30, no Task-Complete/merge. Queue stays03→07→06→overworldVMAP003.

grass_compare_collect.FROZEN and ground_layers.SOURCES retain the logical old helper.
Actual source reads/SHA/copy/recheck now use the known current path. Archive destinations
remain instrumentation/tools/perf_contract_collect.py and inputs/tools/perf_contract_collect.py.
The shared known map adds exactly this one non-facade helper,90→91; the original90
entries/controls remain. A small source_history helper selects a unique old/new name
inside the same full Git commit. Ground base_sources and both provenance readers use
that name, while metadata retains old logical keys. Git reads clear foreign overrides.
No original migration-plan, runtime, GD/UID, artwork, previous report or budget changes.

The same9-case regression source gives red2failures/9errors (including subtests)→9/0.
It calls real collect/provenance, hashes and copies actual source bytes in genuine
temporary Git repositories, verifies stale-old/missing-canonical and ambiguous aliases,
re-signed helper corruption, existing-output sentinels and original signed packets.
Grass empty-schedule and ground context-stop preserve the original prelaunch reproduction.
The complete source-envelope tests use real fake-open child processes, never native
Open/Godot: argv receipts are archived, then the unmodified visual verifiers reject
missing native frames. No source envelope is relabelled a GPU/FPS measurement.

profile.json executes actual collect AST from Git9a2 on its flat Git-byte layout and
the repaired functions on the canonical layout. All four prelaunch archives use their
real source/Git hashes; the original helper is SHA2560ad2b4f4… . Logical coverage and
archive names are unchanged, helper implementation bytes legitimately differ by layout.
The collect bodies otherwise match exactly after normalising the seven current-input
lookups. Six foreign-cwd/Git CLI validate published native readers, their old negative
tests,91known paths and the9new producer methods. Fixtures are deleted; no Game launch.

The final source freeze, scope, complete mandatory gates and Wiki/browser verification
are recorded separately. Every new head needs fresh CI and independent Tech Lead review,
then Team decision; the author does not close the inline finding or accept full03.
''')
shutil.copyfile(__file__,R/'update-docs.py');print('Version372 and current-P2 documentation updated; all other cards unchanged')
