"""Document one intermediate preparation without completing03 or editing parallel cards."""
from pathlib import Path
Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-context-prepare'
(R / 'README.md').write_text('''# REFACTOR-03: Git-контекст поверхностей, 0.0.378

База — `c47b78add8813392769be8b9d5dfba9b8d5fa1d5`: предыдущий World-core принят Team Lead после независимого SOURCE PASS и CI8/8, review5697669336. Этот пакет подготавливает перенос Ground, физически файлы ещё не перемещает. В корне tools остаётся153 исходника, текущая карта содержит267 назначений. Полная REFACTOR-03 остаётся in_progress, PR21 — draft; main не меняется.

Девять настоящих архивных reader падают, когда родитель передаёт чужие GIT_DIR/GIT_WORK_TREE/index/config. Десятый, ground_layers, уже изолировал Git и служит положительным контролем. Один и тот же файл десяти тестов сохранён до и после исправления: [исходник](baseline/test_ground_context.py), [parent:9 ошибок](baseline/context-red.txt), [после исправления](context-green.txt). Это чтение реальных Git blobs, архивных исходников, артефактов и index; Git не заменяется. Чужие index/config и окружение вызывающего процесса сохраняются. Новое окно Godot не открывается, старые нативные кадры не переснимаются и FPS не принимается.

Добавлен git_environment в28 прямых subprocess Git-вызовах18 модулей:9 collectors и9 verifiers. Два уже изолированных вызова ground_layers остаются прежними. AST-сравнение исключает все другие изменения функций: [аудит](semantic-audit.json). Логические SOURCES/OVERLAY остаются точными: [37 полей21 модуля](source-contract-audit.json). Самостоятельный физический перенос71 исходника/42 UID остаётся следующим этапом той же03.

Закрываются два замечания к принятому родителю: удалён неиспользуемый subprocess из plant_depth_verify; аудит19 изменённых Python-модулей не находит оставшихся неиспользуемых импортов. Отдельный тест удаления импорта не добавляется. TESTING, QA_CHECKLIST и DEVELOPMENT используют живые World/Water пути; [32 назначения](live-command-audit.json) проверены на существование. Старые команды внутри frozen reports и исторической карты переносов обозначают историю, а не инструкции запуска; их записанные байты не переписываются.

[Заранее сохранённый план](PLAN.json), [точные изменения](source-edits.json), [проверка импортов](unused-import-audit.json), [полные gates](gates-01/gate-exits.json), [итоговый пакет](checks.json). Architecture, полный Game, normal/F10 и Wiki обязательны; локальный PASS не заменяет CI точного опубликованного SHA и независимого решения. Частичный подготовительный отказ до тестов также сохранён в [attempt01](baseline/prepare-attempt01.json): прототип захватил wrapper-вызовы, финальные правки заново получены от принятой базы и ограничены прямыми subprocess Git.
''')
p = Q / 'TESTING.md'
p.write_text('REFACTOR-03 Ground context 0.0.378: `python3 tools/run.py qa.ground.test_ground_context` выполняет10 реальных архивных сценариев с чужими cwd/GIT_DIR/worktree/index/config: parent9 ошибок, текущий reader10/0; файл теста одинаков. Git и frozen evidence не подменяются, native/FPS не принимаются. Изолированы28 прямых Git-вызовов18 модулей;37 логических полей21 модуля прежние. Физического переноса в этом пакете нет. [План и сырые результаты](docs/reports/refactor-03/ground-context-prepare/README.md). Рабочие World/Water команды ниже используют канонические пути; прежние адреса в frozen reports — исторические записи запусков. Полные architecture/Game/normal/F10/Wiki и независимые review/CI текущего SHA обязательны.\n\n' + p.read_text())
p = Q / 'wiki/articles/project-refactoring.md'
text = p.read_text()
first = text.index('\n') + 1
text = text[:first] + '\nПодготовка Ground 0.0.378 устраняет зависимость28 Git-вызовов18 модулей от чужого репозитория. Десять реальных архивных сценариев: parent9 ошибок → текущие10/0;37 логических полей21 модуля сохранены. Заодно исправлены два замечания к World-core: неиспользуемый импорт и живые команды World/Water. Это промежуточная подготовка той же REFACTOR-03, без физических переносов и без новой приёмки FPS. [План, отказы и проверки](../../docs/reports/refactor-03/ground-context-prepare/README.md). В корне по-прежнему153 исходника; полная03 остаётся in_progress и ждёт полного переноса, независимого ревью/CI и решения Team Lead.\n' + text[first:]
p.write_text(text)
p = Q / 'docs/epics/refactoring-2026-10/TASKS.md'
text = p.read_text()
a, b = text.index('## REFACTOR-03 '), text.index('## REFACTOR-04 ')
section = text[a:b]
section += '**Промежуточная подготовка Ground 0.0.378:** принятый родитель c47b78…/review5697669336/CI8/8 сохранён.28 прямых Git-вызовов18 модулей изолированы от чужих cwd/index/config;10 настоящих архивных сценариев дали parent9 ошибок → текущие10/0.37 полей21 модуля и frozen reports прежние. Неиспользуемый импорт plant_depth и живые World/Water команды исправлены. [План и проверки](../../reports/refactor-03/ground-context-prepare/README.md). Физических переносов0, корень153, текущая карта267. Полная03 не завершена; PR21 остаётся draft/in_progress, новый head требует независимого ревью и CI.\n\n'
p.write_text(text[:a] + section + text[b:])
print('378 documentation and only03 card updated; all other cards preserved')
