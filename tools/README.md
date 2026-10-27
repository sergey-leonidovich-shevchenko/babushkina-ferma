# Инструменты проекта

REFACTOR-03 в работе на базе `d609ab4f`. Первый authoring-пакет перемещён в `tools/assets/authoring`:31 исходник и5 tracked UID;9 локальных UID сохраняют ignored-состояние. Корень tools уменьшен544→513, итоговый бюджет≤30 ещё не достигнут. Команда из любой cwd: `python3 /полный/путь/tools/run.py assets.authoring.build_forest_tree_atlas --help`. Связанные генераторы используют общий source-root и прежние аргументы. Генератор без `--help` может записывать ресурсы; проверка импорта не исполняет его main. Карта и проверки этапа находятся в `docs/reports/refactor-03/authoring-move/`.

Пилот REFACTOR-02 разделяет `common` (границы запуска), `quality` (проверки репозитория) и `planning` (планы/служебный учёт). Перенесены 14 назначений принятой ведомости. QA/asset/build-переносы остаются REFACTOR-03; движок `tools/Godot.app` сохраняет прежнее место.

Корень определяется по исходнику и маркерам `project.godot`, `VERSION`, `tools`, независимо от cwd, глубины или Git-окружения. `run.py` сохраняет аргументы, вывод, exit и настоящий `__main__` для unittest. Из любой cwd: `python3 /полный/путь/tools/run.py planning.project_backlog`. Из корня также работает `python3 -m tools.run quality.check_documentation`. Текущий каталог не меняется. Выбранный проект имеет приоритет над внешним пакетом tools, даже если корень уже стоял ниже в PYTHONPATH. Внутри процесса временно доступен legacy-корень tools для ещё не перенесённой зависимости pilot_rollout → migration_inventory → visual_pipeline; это снимается вместе с её переносом в REFACTOR-03. Глобальный PYTHONPATH не устанавливается.

Основные команды:

```sh
python3 tools/run.py quality.check_documentation
python3 tools/run.py quality.test_documentation
python3 tools/run.py planning.project_backlog
python3 tools/run.py planning.visual_backlog
python3 tools/run.py planning.pilot_rollout --next
python3 tools/run.py planning.test_task_batch
python3 tools/run.py common.test_infrastructure
```

Генераторы `planning.build_art_backlog` и `planning.build_optimization_matrix` сохраняют прежние входы и форматы; они записывают выходы по явной команде. Их регрессионная проверка создаёт только disposable проекты. Старые пути в замороженных отчётах воспроизводятся по закреплённому Git base/капсуле; живые инструкции используют новые команды.

`__init__.py` в корне tools закрепляет собственный пакет, чтобы внешний пакет с тем же именем не подменил команду. Это один дополнительный package marker к прогнозу девяти корневых исходников аудита: итоговый бюджет остаётся не более 30. Принятая историческая ведомость не переписывается.

Git-команды, адресованные отдельному репозиторию, получают копию окружения без `GIT_*`. Это предотвращает повреждение родительских config/index внутри hooks и disposable проверок. Законный alternate index текущего commit hook для `bump_version --stage` сохраняется; очистка не выполняется глобально в родительском процессе.

Публичные совместимые входы делегируют единственной реализации:

| Вход | Реализация | Причина сохранения |
| --- | --- | --- |
| `tools/check_architecture.sh` | `quality/check_architecture.sh` | Hooks и Actions; прежний exit и исполняемый mode |
| `tools/bump_version.py` | `planning/bump_version.py` | Pre-commit, CLI и import API; законный alternate index |
| `tools/task_batch.py` | `planning/task_batch.py` | Post-commit/status и import API; publish остаётся историческим и не обходит PR |

Эти входы удаляются только отдельным одобренным переходом всех публичных потребителей. Импорт возвращает тот же модуль и mutable globals, а не копию функций. Остальные принятые корневые входы `smoke_test.sh`, `performance_gate.sh`, `performance_gate.py` и защищённые `performance_sampler.gd`/`water_audit.gd` сохраняются для следующего этапа. Полный исторический публичный список находится в `docs/reports/refactor-01/integration-1/snapshot/migration-plan-copy.json`.

Проверка инфраструктуры выполняет 13 сценариев: настоящие disposable Git/worktree, argv/exit, пакетный `-m` и публичные API, подмена пакета, ссылки вне tools, нулевой unittest, чужое Git-окружение, alternate index и вложенный архитектурный лимит. Источники, попытки и границы приёмки хранятся в `docs/reports/refactor-02/`.
