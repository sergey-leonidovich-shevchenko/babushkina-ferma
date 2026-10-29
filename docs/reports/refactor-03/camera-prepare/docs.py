"""Record verified camera profile and regression facts before source freeze."""
from pathlib import Path
import json,shutil
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/camera-prepare'
assert json.loads((R/'after-profile.json').read_text())['historical_stdout_byte_equal']==11
for name in ['tools/README.md','wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md']:
 p=Q/name;s=p.read_text();assert s.count('после ожидаются12/0')==1;p.write_text(s.replace('после ожидаются12/0','после12/0'))
p=R/'apply.py';s=p.read_text();assert s.count('после ожидаются12/0')==1;p.write_text(s.replace('после ожидаются12/0','после12/0'))
text='''# REFACTOR-03 — подготовка camera, 0.0.373

Принятая промежуточная база — `57612b6291a88253d5a2f5e46aca21457555f302`: независимый review5692067678, решение Team Lead и CI8/8. Это не итоговая приёмка всей03: корень285 при лимите30, PR21 остаётся draft/in_progress.

Шесть source-root перестают зависеть от глубины папки. Восемь прямых Git-read и одна ветка общего command helper получают свой проект и очищенные GIT overrides. Системные запросы сохраняют прежние cwd/env/timeout/вывод. Логические SOURCES/LEGACY_SOURCES/TOOLS, архивные назначения, метрики и алгоритмы остаются прежними. Исходники пока физически не перемещаются.

Один test SHA `fbdea3d6097091f31146df426fd0f3df34d1b1d40e7e851f226892046ff4a992` воспроизводит red16 failures с учётом subtests → green12/0. Шесть actual-модулей импортируются из вложенной копии, настоящие Git/helper/signature проверяются из чужого Git/cwd. Восемь actual producer создают свежие source-envelope: SHA/copy/reader используют настоящие байты, семь явно fake children возвращают17, timing останавливается до native context. Штатные verifier отвергают все неполные пакеты, повторная запись существующего output запрещена. Профили и файлы фикстур удаляются собственными TemporaryDirectory; пользовательские отчёты не меняются.

Эти контроли не измеряют native/Game/GPU/FPS. Самостоятельные нативные recordings и перерасчёт performance допуска не проводятся. Обязательный полный Game/normal/F10 проверяется отдельно в gates-01 и не подменяется fake children.

Двадцать настоящих команд до/после включают11 исторических readers/CLI и9 прежних отрицательных suites. Все выполняются из чужого Git/cwd с реальными index/config;11 stdout совпадают побайтно. Унаследованные assertions прежних тестов не переписаны. Исходники и результаты — `baseline/`, `context-red.*`, `context-green.*`, `before-profile.json`, `after-profile.json` и raw каждой команды. `scope.json` фиксирует границы, `source-freeze.json` — source SHA перед общим gate.

Полные TESTING.md, Wiki check и браузер текущего кандидата обязательны перед commit/push. Каждый новый exact head повторно рассматривают Tech Lead и Team Lead. Полного merge03/Task-Complete здесь нет; отдельный план07 и прежние frozen evidence сохраняются.
'''
(R/'README.md').write_text(text);shutil.copyfile(__file__,R/'docs.py')
print('camera profile/docs verified; ready for source audit')
