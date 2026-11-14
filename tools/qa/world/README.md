# Проверки игрового мира

[Первый перенос REFACTOR-08](../../../docs/reports/refactor-08/README.md) группирует сценарии изоляции нескольких viewport в `viewport/`. Здесь находятся нативный захват, проверка в Godot, валидатор и его тесты. Сценарии деревни, воды, сохранений и порядка слоёв пока запускаются из `qa.world`.

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
