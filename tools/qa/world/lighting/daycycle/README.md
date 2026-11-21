# VLIGHT-003 — календарная палитра

`scenarios.gd` создаёт действительную main-сцену через принятые camera fixtures;
`game.gd` наблюдает её обычный draw. HUD не вынесен в искусственно защищённый слой:
сначала снимается обычный root, затем тот же экземпляр рисует прозрачный HUD.
`capture.gd` и `viewports.gd` сохраняют исходные framebuffer/state/samples.

`collect.py` работает только в удалённом Linux/X11, экспортирует закреплённую
старую main и точный текущий Git head. Runtime/ресурсы не получают оверлеев.
`contract.py` перечисляет QA inputs и всю матрицу. `evidence.py` читает raw/ZIP
без извлечения, `pixels.py` проверяет HUD и сигнал героя/угрозы. `provenance.py`
сверяет Git/источники/профили; `readings.py` — реальные состояния, два viewport
и исходные временные данные; `verify.py` сравнивает старый и новый кадры.
`profile.gd` подтверждает эффективный userdata до импорта и каждого native run.

`legacy` выключает только новую календарную кривую, сохраняя старое освещение.
`reference` — прежний диагностический режим без целого набора эффектов первой
карты; его стоимость не называется стоимостью одного tint. Помещения/соседняя
карта служат отрицательным контролем области и сохраняют свой прежний путь.

После замены script наблюдатель снова получает исходный seed до bootstrap.
Герой и угроза имеют раздельные кадры без одного объекта; логические области
переводятся настоящим viewport stretch в framebuffer. Reader независимо
сверяет seed, камеру и границы (допуск округления1px), а не только наличие сигнала.

```sh
python3 tools/run.py qa.world.lighting.daycycle.test_contract
# Только удалённый стенд; DISPLAY и FARM_GODOT_BIN уже настроены workflow:
python3 tools/run.py qa.world.lighting.daycycle.collect --output /новый/внешний/output
python3 tools/run.py qa.world.lighting.daycycle.verify --output /тот/же/output --expected-head SHA
```

`review.gd` запускает модельную suite в заранее выбранном собственном профиле
`Codex-VLIGHT-003-*`. Полный Game включает ту же suite через ArchitectureSuite.
Дополнительно review исполняет оба настоящих варианта capture dispatch и проверяет
тип Array[String]: compile-only пропускает ошибку типов в условном выражении,
найденную вторым CI до первого PNG. Всего у профиля 18 условий: 16 модели и 2 dispatch.
Нативная съёмка не запускается architecture-тестом и не открывает игру на ПК.
Неполная серия не проходит reader. До получения настоящего пакета default verify
ожидаемо откажет; отсутствие доказательств не означает завершённую задачу.
Методика, заранее выбранные ограничения и границы: [PLAN](../../../../../docs/reports/visual-overhaul/vlight-003/PLAN.md).

Настоящий CI3-пакет теперь сохранён в [отчёте](../../../../../docs/reports/visual-overhaul/vlight-003/README.md).
`test_reader` проверяет переподписанные копии ZIP/JSON/PNG целиком, а не отдельные
parser blocks. Исторические negatives не требуют совпадения будущего live-runtime;
strict-current отдельно проверяется в настоящем временном Git checkout съёмки
с SemVer-only и контролируемым runtime drift, без изменения parent index/config.

`review_regressions` запускает полные old-timing/current CLI с настоящими OS exit.
Old — неизменённая capture-функция d5 внутри общего verifier с исправленной P1
closure; весь старый head не объявляется совместимым с новым manifest. Обычный
отчёт требует strict-current; `--historical` применяется только в регрессиях архива.
`gallery` проверяет все 12 native crop без resize; `metrics` сохраняет2160 исходных
samples и статистику целого draw. Статические X11-сцены не принимают аппаратный FPS.

```sh
python3 tools/run.py qa.world.lighting.daycycle.test_reader
python3 tools/run.py qa.world.lighting.daycycle.review_regressions --output /новая/внешняя/папка
python3 tools/run.py qa.world.lighting.daycycle.gallery --output docs/reports/visual-overhaul/vlight-003 --check
python3 tools/run.py qa.world.lighting.daycycle.metrics --output docs/reports/visual-overhaul/vlight-003 --check
```
