# Один фонарь: сравнение способов

[VLIGHT-002](../../../../../docs/reports/visual-overhaul/vlight-002/README.md) — самостоятельный QA-пакет внутри lighting. Production остаётся прежним. Исходный аудит 001 и его frozen-входы не изменяются.

```sh
python3 tools/run.py qa.world.lighting.comparison.verify
python3 tools/run.py qa.world.lighting.comparison.verify --check-current-candidate
python3 tools/run.py qa.world.lighting.comparison.test_contract
python3 tools/run.py qa.world.lighting.comparison.test_reader
```

Reader офлайн проверяет два native ZIP: official engine/build, реальные argv/Compatibility/окна, день/сумерки/ночь, улицу/существующий дом, четыре режима, saves/камеру, HUD, два viewport и raw CPU/frame samples. Реальная опора фонаря включает производственный GROUND_OFFSET, поэтому одинаковое смещение обеих реализаций не скрывает ошибку. `--check-current-candidate` допускает только SemVer-метаданные, остальные runtime/assets/QA должны совпасть.

Geometry guard выводит фактический радиус PointLight из обеих сторон256×256 и настоящего `texture_scale`; ожидание берётся из max radii принятого profile и zoom независимо от поля `radius`. Это применяется к PNG-случаям, временным строкам и каждому viewport. Настоящие enabled/energy/shadow/PCF5 проверяются по режиму и трём закреплённым часам; timed light и оба scene context должны совпадать с валидированным случаем1320. Full save остаётся строгим внутри timed-пар: ранее снятый PNG предшествует законному посещению дома.

Два точных повреждённых пакета независимого ревью, старый reader249c и отказы исправленного reader сохранены в[регрессиях PR80](../../../../../docs/reports/visual-overhaul/vlight-002/failures/review-regressions.json). Это заведомо испорченные метаданные для контроля reader; они не являются новой native-серией. Исходные C ZIP/PNG/samples и все30 producer inputs сохранены.

Исторический producer закреплён за source-base `be306229` и конфигурацией0.0.467: для точного повторения используются эта база и frozen-файлы `native/inputs`. Он не подменяет свою основу текущей main; новая production-ревизия требует отдельной постановки/серии.

Новая съёмка требует отдельного свободного согласованного Godot-слота и свежего внешнего каталога. Чужие процессы/окна не останавливаются. Изолированные профили обязательны; обычные сохранения не используются.

```sh
python3 tools/run.py qa.world.lighting.comparison.collect --output /private/tmp/new-lantern-comparison
```

Одиночная `--width 1152|1280` — диагностика; она не даёт полной приёмки. Существующий вывод и symlink-цепочка отклоняются до запуска движка. Два overlay существуют только в disposable-копии: прежний уличный halo заменяется одним QA-источником, живой HUD получает CanvasLayer 2. Материалы/текстуры сохраняются, shadow-окклюдер явно обозначен как QA-аппроксимация стойки.

`fixture.gd` владеет одним mesh/PointLight/texture; `scenarios.gd` — конфигурацией и тремя повторами; `capture.gd` — native framebuffer; `viewports.gd` — двумя независимыми targets. Python-модули отдельно отвечают за export/привязку к Git, транспорт, пиксели, время и публикацию. Нативная серия не запускается обычными verify/tests.

Публикация явная и не удаляет raw. Она требует свежего назначения и сверяет все payload SHA, затем равенство raw/ZIP verifier. Диагностические листы собираются из реальных PNG, проверяют каждый crop и не меняют игровую графику.

```sh
python3 tools/run.py qa.world.lighting.comparison.publish --input /private/tmp/new-lantern-comparison --output /private/tmp/new-lantern-publication
python3 tools/run.py qa.world.lighting.comparison.gallery --font /path/to/readable-font.ttf
python3 tools/run.py qa.world.lighting.comparison.summarize --write
```

В обычном CI запускаются readers/отрицательные контроли, не окно Godot. CPU draw submission и native QA frame intervals не объявляются GPU-временем, hardware FPS или готовностью VMAP-003. Аргументы из другой cwd передаются через абсолютный путь к `tools/run.py`.
