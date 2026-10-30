# REFACTOR-07 — проверки кода и реальных сценариев

Работа начата30.10.2026 на принятой main464328853c2fbbed1410ac0312de75c3fee7cfa2 после полного закрытия REFACTOR-03/PR21/PR26. Ветка `codex/refactor-07-quality-gates`, версия0.0.383. Статус in_progress до независимого exact-head review, CI и решения Team Lead. Следующая задача после приёмки07 — REFACTOR-06; прежняя остановка отменена пользователем.

## Объём и принципы

- Общие lint/format/type правила для целых новых/изменённых файлов, одинаковые версии локально/CI. Ruff0.17.3, mypy2.4.1, gdtoolkit4.5.0, Godot4.7.1; зависимости закреплены полностью. Отдельная явная fix-команда, CI исправлений не делает.
- [1220 legacy-source SHA](baseline/legacy-sources.json) — прозрачный baseline принятой базы. Изменённый байт снимает исключение с всего файла; новые вложенные файлы обнаруживаются и при старых Git-ignore правилах. Frozen reports исключены из autofix; их прежняя приёмка/provenance продолжают действовать.
- Godot анализирует свою временную копию после свежего импорта; шесть новых предупреждений загружены как ошибки при старте. Только в копиях неизменённых legacy-зависимостей эти новые предупреждения получают явный ignore; семантические ошибки остаются активными. Игровой код/арт/UID не редактируются.
- Самопроверка вызывает настоящие public alpha CLI и migration create API на текущих working sources, отдельно проверяет live/history ввод, реальный linked worktree и headless collector. Файлы fixture не собираются вместо producer. Линтер не заменяет самопроверку или независимое ревью.

[Инструкция и команды](../../../tools/quality/README.md), [порядок ревью](../../CODE_REVIEW.md), [каноническая карточка](../../epics/refactoring-2026-10/TASKS.md).

## Малая проба и сохранённые отказы

[Совместимость](baseline/compatibility-probe.json): существующий Python `common/paths.py` прошёл mypy strict, Ruff нашёл старый формат; существующий held-weapon GDScript разобран gdtoolkit и настоящим Godot. Форматирование выполнено только на временных копиях. Godot4.7.1 подтверждён фактически.

Первая проба `GDScript.reload` [сохранена](baseline/godot-analyzer-probe.json), [её исходник](baseline/rejected-reload-prototype.gd.txt) не подключён к gate: runtime ProjectSettings не включили ожидаемые строгие предупреждения, статическая инициализация выполнилась. [Штатный check-only](baseline/godot-check-only-probe.json) поймал семантическую/typed/unsafe ошибку в stderr при exit0 и тоже выполнил `_static_init`. Поэтому gate проверяет журнал и работает в отдельной копии. [Попытка directory_rules для одного файла](baseline/godot-warning-scope.json) не дала требуемого строгого отказа и не используется. [Узкий baseline в копии](baseline/godot-baseline-warning-probe.json) сохраняет отказы изменяемого файла и семантические отказы зависимости.

[Первый прогон контролей](controls-01/quality-tests-first-failure.txt) сохранил отказ тестовой фикстуры: directory symlink указывал на несуществующий каталог и считался файлом. Исправлена только подготовка этого реального сценария; исключение не ослаблено. Следующий прогон десяти тестов прошёл. Дальнейшие сырые проверки и общий freeze хранятся отдельными сериями; промежуточные пробы не заменяют итоговые gates.

## Границы приёмки

Профиль headless не создаёт GPU кадров и не допускает FPS. Синтаксическая проверка не означает прохождения Game или сохранения всех игровых сценариев. Существующие полные architecture, Game/normal/F10, performance, Wiki check и браузер выполняются по TESTING; старые тесты/пороги не удаляются. После нескольких сопоставимых PR можно сравнивать частоту повторных возвратов и стоимость проверок; нулевое число замечаний не обещается.

Параллельные три файла постановки07 и два ignored probe в primary сохранены: [исходный контроль](baseline/foreign-preservation.json). Перенесена только карточка07;03done/дата, текущая цель эпика и условия06 не откатывались. Реестр8 карточек,07in_progress и06blocked. Счётчик root tools остаётся11; адресный guard/закрытие первого выпуска относятся к06.

Основные источники: [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit), [предупреждения Godot](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html), [project overrides](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html), [Ruff](https://docs.astral.sh/ruff/installation/), [mypy](https://mypy.readthedocs.io/en/stable/getting_started.html). Точные установленные версии и реальные отказы важнее предположения о возможностях линтера.

## Дополнительная проверка legacy и hook

[Полный read-only аудит1220 старых исходников](legacy-audit/summary.json) нашёл6217 Ruff lint diagnostics,286 Python-файлов для форматирования и16364 gdlint problems; gdformat предлагает867 файлов. Три старых Python-файла проходят AST Python3.11, но Ruff format отклоняет компактное присваивание переменной match после semicolon: это ограничение formatter, а не объявленный дефект их Python-семантики. Gdlint и gdformat отклоняют21 старую компактную конструкцию с compound statement после semicolon; количества would-reformat приведены как фактический stdout инструмента, без объявления этих форм поддержанными. Новые/изменённые файлы исключения не наследуют — такие строки нужно привести к каноническим переносам. Все1220 исходных SHA после аудита прежние. Тайминги сняты параллельно architecture и не выдаются за последовательный benchmark.

[Настоящий pre-commit control](hook-control/result.json) вызвал Git commit в собственном clone с новым вложенным Python-файлом и реальной ошибкой типов. Коммит отклонён mypy, HEAD и staged blob/mode прежние, bump_version не выполнился; temp удалён. [Воспроизводимый профиль](hook-control/probe.py) использует --root и новый внешний --output; source repo не коммитится.

При подготовке Wiki обнаружено, что ссылка на незарегистрированный tools/quality/README.md превращалась бы в общий поиск README. Добавлена отдельная статья code-quality и рабочая ссылка на неё. Это три документационных пути, изменённые во время architecture до Game/Wiki: [отдельный Wiki freeze](gates-01/wiki-scope-freeze.json). Исходный25-file freeze сохранён; не утверждается, что новые статьи были заморожены до старта всей серии.

## Самопроверка API временного mirror

В локальном code review добавлены явные запреты запуска settings/mirror по рабочему checkout и непустой цели: безопасный public CLI уже создавал temp, теперь и helper API не оставляет ловушку для прямого вызова. Тест использует только собственные disposable проекты. [Прежний helper](guard-review/pre-guard.godot.py.txt) восстановлен точным обратным удалением добавленных guards и проверен по SHA исходного freeze; это промежуточный working-кандидат07, а не опубликованный parent. Первый old-контроль НЕ является red: loader отказался загрузить суффикс .py.txt до запуска теста; [явный отказ доказательства](guard-review/old-control-invalid.json) сохраняет исходный лог. Положительные current-проверки этой серии прошли: все11 quality tests, полный static8 и actual-game Godot mirror; [команды](guard-review/checks.json), [результат и SHA](guard-review/result.json). Реальный producer повторён на окончательных исходниках: [14 команд и source/index/config preservation](guard-review/producer-report/result.json).

[Окончательный снимок28 source/docs/meta](final-source-freeze-nul.json) читает Git пути через NUL. Ранние25/27 snapshots не включили кириллический app Info.plist из-за quoted-path вывода; это явно указано, версия383 дополнительно проверена штатным bump_version --check. Два quality helper/test изменены во время architecture, после его раннего прогона десяти quality cases: final11/static/real-mirror и producer проверены отдельно. Полные старые gates сохраняются, точный опубликованный head обязан пройти полный CI; не утверждается, что все28 файлов были предзаморожены перед стартом локальной серии.

## Повторное подтверждение и язык комментариев

Комментарии восьми Python-модулей приведены к русскому стандарту проекта; у11 тестов добавлены строки Сценарий/Исходное состояние/Ожидаемый результат. [AST-сравнение](comment-standard/ast-comparison.json) подтверждает неизменность исполняемых тел без docstrings; описания help теперь русские. Комментарии requirements и gdlint config не меняют версии/правила. Это отдельная поздняя редакционная проверка, не скрытая под ранним freeze.

[Повторный old/new контроль](guard-recheck/result.json) использует явный SourceFileLoader и принимает отрицательный результат только при tests_run=1, ошибке настоящего mirror в собственной fixture и точном прежнем SHA. Ошибка импорта больше не может считаться red. Та же текущая test source проверяется на старом и новом helper; затем повторяются все11 quality cases, static8, actual-game mirror,14 public producer команд, версия и документация на новом28-file freeze. Точный опубликованный head дополнительно требует полного CI и независимого review.

[Сводный локальный результат и границы приёмки](local-validation.json), [окончательный снимок перед commit](staging-source-freeze.json). Новый pyproject.toml лишился только последней пустой строки для git diff --check; tomllib подтвердил те же значения. Старые сырые логи не исправлялись.
