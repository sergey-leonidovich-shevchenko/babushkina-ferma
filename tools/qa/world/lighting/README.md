# Проверки освещения

[VLIGHT-001: карта действующего света](../../../../docs/reports/visual-overhaul/vlight-001/README.md) отделяет затемнение, локальные halo, декор и рисунок внутри текстуры. Production-код и графика этой карточкой не заменяются.

Без запуска игры:

```sh
python3 tools/run.py qa.world.lighting.inventory
python3 tools/run.py qa.world.lighting.verify
python3 tools/run.py qa.world.lighting.verify --check-current-candidate
python3 tools/run.py qa.world.lighting.test_contract
python3 tools/run.py qa.world.lighting.test_reader
```

Обычный reader сверяет архив с его закреплённым Git-коммитом и замороженными QA-входами. `--check-current-candidate` дополнительно требует неизменных runtime/asset trees и текущих QA-байтов. Единственное разрешённое отличие конфигурации — точный `config/version` вместе с `VERSION`; оно явно отражается в результате как метаданные. Изменение любого другого render-настройки требует нового захвата.

Новая съёмка требует macOS, официального установленного Godot, согласованного свободного QA-слота и нового внешнего каталога:

```sh
python3 tools/run.py qa.world.lighting.collect --output /private/tmp/new-light-inventory
```

Collector экспортирует настоящий Git tree в disposable production/control проекты и создаёт отдельные UUID-профили. Только в control меняются пять заранее объявленных draw-вызовов. Сначала выполняются импорт и фактический `--check-only` обеих цепочек preload, затем шесть последовательных нативных запусков. Ошибки журнала отклоняются независимо от exit code. Чужие окна и профили не останавливаются.

Флаги `--width 1152|1280` и `--variant production|on|off` предназначены для диагностики. Частичная матрица читается только с `verify --input <folder> --diagnostic` и не даёт приёмку. Неудачные серии не перезаписываются и не дополняются кадрами от других исходников.

Полная матрица содержит две ширины, три времени, два участка улицы и дом, production/on/off, отдельный прозрачный HUD и два независимых viewport с обоими направлениями выключателя. CPU draw submission сравнивается по трём повторениям с тем же прибором в обоих режимах. Это остановленная симуляция, **не аппаратный FPS или GPU budget**; будущие реализации света и VMAP-003 не принимаются.

Из другой cwd укажите абсолютный путь к `tools/run.py`. Архивные PNG могут храниться raw либо в точных ZIP по ширине; reader не извлекает пути и сохраняет исходные SHA содержимого.
