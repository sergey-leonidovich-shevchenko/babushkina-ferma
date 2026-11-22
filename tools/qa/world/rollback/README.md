# VCOMPAT-010 · обратимость визуальной версии

Отдельное семейство World QA. Production renderer не переписывается инструментальными overlays. Baseline — принятая `main` `820b73b2`; candidate — точный опубликованный head. Обе версии получают одни и те же QA-наблюдатели; baseline не получает новый `visual_version.gd`.

`python3 tools/run.py qa.world.rollback.collect --output <новый внешний каталог>` разрешён только удалённому Linux X11. Каждый импорт и нативный запуск имеет новый подтверждённый userdata. Матрица — шесть участков первой карты, вечер, старый JSON/обычный выход из дома, повторные переключения и два независимых viewport; оба размера окна. Полные PNG и исходники сохраняются и при отказе.

`python3 tools/run.py qa.world.rollback.verify --output <каталог> --expected-head <SHA>` проверяет 136 PNG, Git/QA closure, фактические framebuffer/callbacks, одинаковые игровые поля и точный возврат пикселей. Неизменённая база воспроизводит неработающий общий флаг. `--check-current-candidate` допускает после съёмки только объявленную разницу SemVer, остальные runtime/QA должны совпасть.

`qa.world.rollback.test_contract` и `qa.world.rollback.test_reader` входят в architecture gate. Синтетические изображения unit-фикстур проверяют reader и **не** используются как нативное доказательство игры. Профиль сохранений/редактора — `res://tools/qa/world/rollback/review.gd`, общий игровой набор подключает тот же suite.

Новые механики, карты, дождевой арт, снег, GPU-FPS и приёмка VMAP-003 сюда не входят.
