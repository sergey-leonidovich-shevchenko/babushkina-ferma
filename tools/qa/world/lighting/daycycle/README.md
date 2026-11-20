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
