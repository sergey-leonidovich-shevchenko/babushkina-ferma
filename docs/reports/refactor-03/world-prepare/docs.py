"""Publish only observed World preparation profile/regression facts before the source freeze."""
import json,shutil
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/world-prepare'
assert json.loads((R/'after-profile.json').read_text())['historical_stdout_byte_equal']==21
red=json.loads(Path('/private/tmp/refactor03-world-red375.json').read_text());green=json.loads(Path('/private/tmp/refactor03-world-green375.json').read_text())
assert red['test_SHA256']==green['test_SHA256']and green['exit']==0 and green['methods']==19
for name in ['tools/README.md','wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md']:
    p=Q/name;s=p.read_text();assert s.count('green фиксируется отдельным raw')==1
    p.write_text(s.replace('green фиксируется отдельным raw','после19/0 на том же source SHA;21 stdout побайтно равны'))
(R/'README.md').write_text('''# REFACTOR-03 — подготовка World, 0.0.375

Промежуточная база `6b13af8ebf9ec603705c6d4e04577ce8774095da` принята SOURCE PASS review5693093074/Team, её CI завершён8/8. Вся03 по-прежнему in_progress/PR21draft: корень245 при целевом бюджете30. Это подготовка перед физическими переносами World, не полное закрытие03.

Девять фиксированных parents[1] заменены поиском настоящих маркеров проекта по исходнику.42 прямых чтения Git в24 исходниках получают уже существующее очищенное окружение при прежнем явном cwd. Девять уже очищенных Git-вызовов остаются положительными контролями. Изменения не касаются системных процессов, таймаутов, алгоритмов, CLI/JSON форматов, численных порогов, source lists, архивных назначений или политики допуска. Все прежние функции и assertions сравниваются по AST с нормализацией только добавленного Git env.

Один финальный test source воспроизводит red12fail/19error с учётом subtests → green19/0. Проверяются9 настоящих вложенных import, два полных архивных этапа шести prop readers, render-order/object/pilot/static/dependency51/post-motion/transient/shadow readers и четыре настоящих writer/producer. Git не замокан: используются реальные commits, tree, index, config, blobs; SHA/copy/file I/O настоящие. Чужие cwd/GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE/config не меняют выбранный проект, окружение родителя и чужой index/config сохраняются.

Render contract пишется только в новую собственную временную папку. Shadow inventory пишет настоящие JSON/CSV с полными источниками; явно остановлен перед платформенными шрифтами и contact sheets. Два actual collector выполняют настоящий source envelope, но явно останавливаются до native context/Popen. Неполные пакеты отвергаются штатными readers, повторный output запрещён. Эти тесты не являются Game/native/GPU/FPS допуском и не создают игрового окна; обязательный Game/normal/F10 выполняется отдельно в полном TESTING.

Частные red-попытки сохраняются отдельно: чтение процессов было ограничено sandbox, ожидаемый отказ неполного shadow packet уточнён до ValueError/FileNotFoundError. При чтении producer уточнены разные prelaunch точки: context у object, первый jobs после source.json у shadow. Все эти уточнения сделаны до изменения продукта; shadow red останавливался ещё на прежнем Git-отказе и Popen не достигал. Окончательная19-case версия снова исполнена до исправления продукта с доступным ps; её SHA совпадает с green. Три red-версии и raw сохранены, без замены неудачной попытки успешной.

35 настоящих before/after CLI:15 исторических readers,6 asset verifiers,14 прежних отрицательных suites. До правки они работают из чужой cwd с чистым Git env; после — из чужой cwd с явными чужими Git overrides.21 stdout исторических/asset verifier совпадают побайтно;14 прежних suites проходят в обоих случаях. Старые reports/readers не переподписываются. Карта source_paths133, два отложенных shared source,85 авторских ignored UID/anchor, четыре публичных performance facade, sampler и исходный план сохранены.

`scope.json` и `source-freeze.json` связывают фактическую область и source SHA перед общими gates. `before-profile.json`, `after-profile.json`, `context-red.*`, `context-green.*` и raw позволяют воспроизвести результат. `checks.json` создаётся только после новых полных architecture/Game/Wiki и браузерных проверок. Параллельные документы07 не входят в этот пакет. Новый head требует независимого Tech Lead review и решения Team Lead; полного merge/Task-Complete здесь нет.
''')
shutil.copyfile(__file__,R/'docs.py');print('World profile/docs factual; ready for source audit/freeze')
