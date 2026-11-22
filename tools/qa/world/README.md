# Проверки игрового мира

[Откат визуальной версии](rollback/README.md) — отдельное семейство `rollback/`: настоящий общий флаг, old JSON/уровни, baseline/candidate и независимые viewport. Нативные кадры — только удалённый Linux X11.

[Часы осадков](weather/README.md) сгруппированы в `weather/`: профильная проверка паузы, producer двух настоящих Git-версий и reader нативных кадров. Локальный игровой захват запрещён; producer требует удалённый Linux X11. Новый рисунок осадков этот пакет не принимает.

Карта действующего [освещения](lighting/README.md), нативное сравнение production/on/off, отдельный HUD и изоляция двух viewport находятся в `lighting/`. VLIGHT-001 описывает текущие эффекты; новая световая система реализуется отдельными карточками.

Сценарии [читаемости контактных теней](shadows/README.md) находятся в `shadows/`: нативные парные кадры, проверка слоёв лута и отрицательные сценарии VSHADOW-010. Архив читается без Godot; новая съёмка требует отдельного профиля и свободного QA-дисплея.

[REFACTOR-09](../../../docs/reports/refactor-09/README.md) собрал проверки деревенских лавок в `benches/`. Общие наблюдатели отрисовки и проверки оград, улицы, воды и сохранений находятся в `qa.world`.

## Деревенские лавки

```sh
python3 tools/run.py qa.world.benches.village_bench_assets
python3 tools/run.py qa.world.benches.village_bench_verify
python3 tools/run.py qa.world.benches.test_village_bench
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/qa/world/benches/village_bench_review.gd
```

Первый вызов сверяет три производных PNG с мастерами, второй проверяет [принятый нативный архив VPROP-002](../../../docs/reports/visual-overhaul/vprop-002/README.md). При запуске извне передайте абсолютный путь к `tools/run.py`, а для Godot — к движку и проекту. Прежние команды `qa.world.village_bench_assets`, `qa.world.village_bench_collect`, `qa.world.village_bench_verify` и `qa.world.test_village_bench` сохраняют аргументы и формат вывода. Четыре прежних Godot URI делегируют одноимённым скриптам в `benches/`.

Сборщик `qa.world.benches.village_bench_collect` принимает `--phase before|after`, требует свежую папку фазы и запускает окна 1152×648 и 1280×720 через macOS. Для прямого запуска `village_bench_capture.gd` передайте после `--` параметры `--output=<новая папка>`, `--profile=Codex-VPROP-002-<уникальное имя>` и `--phase=before|after`. Скрипт `village_bench_leg_capture.gd` принимает `--output=<новая папка>` и необязательный `--wide`. Обе команды съёмки требуют видимого окна на QA-стенде. Параметр `--build` у инструмента ассетов пишет производные PNG и каталог, а `--write` у валидатора обновляет сводку.

## Деревенская улица

```sh
python3 tools/run.py qa.world.street.village_street_assets
python3 tools/run.py qa.world.street.village_street_verify
python3 tools/run.py qa.world.street.test_village_street
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/qa/world/street/village_street_review.gd
```

Первый вызов сверяет шесть производных PNG и опоры колодца и телеги. Второй читает [принятый архив VPROP-003](../../../docs/reports/visual-overhaul/vprop-003/README.md). Для сборки производных в копии проекта используется `--build`, для записи сводки архива используется `--write`.

`qa.world.street.village_street_collect --phase before|after` требует свежего каталога фазы. Нативный захват использует `res://tools/qa/world/street/village_street_capture.gd`. После `--` он принимает `--output=<новый каталог>`, `--profile=Codex-VPROP-003-<имя>`, `--phase=before|after` и необязательный `--wide`. Для захвата нужен видимый дисплей на QA-стенде.

Из внешнего каталога используйте абсолютные пути к launcher, Godot и проекту. Прежние команды и Python-импорты в `qa.world`, а также три прежних Godot URI делегируют тем же реализациям. [Ведомость REFACTOR-10](../../../docs/reports/refactor-10/README.md).

## Изоляция viewport

[REFACTOR-08](../../../docs/reports/refactor-08/README.md) группирует сценарии изоляции нескольких viewport в `viewport/`. Здесь находятся нативный захват, проверка в Godot, валидатор и его тесты.

Из корня проекта:

```sh
python3 tools/run.py qa.world.viewport.viewport_isolation_verify
python3 tools/run.py qa.world.viewport.test_viewport_isolation
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/qa/world/viewport/viewport_isolation_review.gd
```

Из другой рабочей папки укажите абсолютные пути к launcher, движку и проекту. Кавычки сохраняют путь с пробелами:

```sh
python3 "/путь/к/my farm/tools/run.py" qa.world.viewport.viewport_isolation_verify
"/путь/к/my farm/tools/Godot.app/Contents/MacOS/Godot" --headless --path "/путь/к/my farm" --script res://tools/qa/world/viewport/viewport_isolation_review.gd
```

Для свежей нативной съёмки используйте `res://tools/qa/world/viewport/viewport_isolation_capture.gd`. Передайте после `--` параметры `--output=<новая внешняя папка>`, `--profile=Codex-VRENDER-009-<уникальное имя>` и `--base-commit=<полный SHA предка>`. Требуется видимое окно 1152×648. Сценарий создаёт отдельный профиль и отклоняет существующую папку вывода с кодом 2. Штатная проверка читает [архив R11F](../../../docs/reports/visual-overhaul/vrender-009/README.md).

Прежние команды `qa.world.viewport_isolation_verify` и `qa.world.test_viewport_isolation` перенаправляет `tools/run.py`. Прежние Godot URI `res://tools/qa/world/viewport_isolation_capture.gd` и `res://tools/qa/world/viewport_isolation_review.gd` запускают те же сценарии через наследование. В архитектурном наборе тесты вызываются один раз по новому адресу.
