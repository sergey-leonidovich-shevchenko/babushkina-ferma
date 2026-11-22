# VCOMPAT-010 · обратимость визуальной версии

Отдельное семейство World QA. Production renderer не переписывается инструментальными overlays. Baseline — принятая `main` `820b73b2`; candidate — точный опубликованный head. Обе версии получают одни и те же QA-наблюдатели; baseline не получает новый `visual_version.gd`.

`python3 tools/run.py qa.world.rollback.collect --output <новый внешний каталог>` разрешён только удалённому Linux X11. Каждый импорт и нативный запуск имеет новый подтверждённый userdata. Матрица — шесть участков первой карты, вечер, старый JSON/обычный выход из дома, повторные переключения и два независимых viewport; оба размера окна. Полные PNG и исходники сохраняются и при отказе.

`python3 tools/run.py qa.world.rollback.verify --output <каталог> --expected-head <SHA>` проверяет 136 PNG, Git/QA closure, фактические framebuffer/callbacks, одинаковые игровые поля и точный возврат пикселей. Неизменённая база воспроизводит неработающий общий флаг. `--check-current-candidate` допускает после съёмки только объявленную разницу SemVer, остальные runtime/QA должны совпасть.

`qa.world.rollback.test_contract` и `qa.world.rollback.test_reader` входят в architecture gate. Синтетические изображения unit-фикстур проверяют reader и **не** используются как нативное доказательство игры. Профиль сохранений/редактора — `res://tools/qa/world/rollback/review.gd`, общий игровой набор подключает тот же suite.

Новые механики, карты, дождевой арт, снег, GPU-FPS и приёмка VMAP-003 сюда не входят.
## Исправление фабрики после первого CI

`set_script` сбрасывает script-state. Seed закрепляется повторно до `add_child/_ready`; native reader требует 20261015 у каждого начального, cold и twin владельца и одинаковые полные save/camera/player/location между baseline/candidate. Полное совпадение PNG не заменяет эту проверку.

`qa.world.rollback.test_archive` проверяет исходный неудачный CI и байтовое восстановление ZIP по частям. Для сохранённого большого архива передайте `--archive <parts.json>` в `qa.world.rollback.archive`: исходные части и SHA целого проверяются до временной распаковки, архив не перепаковывается. CLI по-прежнему принимает обычный ZIP.

`review.gd` требует фактический startup userdata с префиксом `Codex-VCOMPAT-010-` и ждёт входа корневого окна в дерево. Изменение custom_user_dir внутри `_initialize` не заменяет изоляцию до старта процесса.
