# VLIGHT-010 · Упрощённый свет

Статус `in_progress`. [План и границы](../../../../../docs/reports/visual-overhaul/vlight-010/PLAN.md).
Настоящая CI1 и чистый strict-current reader прошли на 93df8ef6. Исходный ZIP
сохранён точными частями в `native-ci-01`; окончательная приёмка ещё не заявляется.

`review.gd` исполняет настоящую `lighting_quality_suite` и фабрику сцен в отдельном
headless-профиле `Codex-VLIGHT-010-*`. Startup userdata применяется до первого
обращения к движку и подтверждается фактическим OS user dir; обычные файлы
сравниваются до/после. Это модель и save-инварианты, не визуальная или FPS-приёмка.

```sh
python3 tools/run.py qa.world.lighting.quality.test_contract
python3 tools/run.py qa.world.lighting.quality.test_reader
python3 tools/run.py qa.world.lighting.quality.collect --output /absolute/fresh/output
python3 tools/run.py qa.world.lighting.quality.verify --output /absolute/original/evidence.zip --expected-head <SHA> --check-current-candidate
```

Collector требует удалённый Linux/X11, чистый checkout и точный
`VLIGHT_QUALITY_EXPECTED_HEAD`; обычный игровой GUI на ПК владельца не запускается.
Два настоящих Git-экспорта и 46 замороженных входов дают 304 артефакта/270 PNG.
HUD снят отдельно. Контроли пропускают реальные проходы фасадов/интерьера,
врагов и ресурсов; вызовы фиксируются, игровое состояние сохраняется.

Reader читает исходный ZIP с корнем source.json или evidence/source.json;
неоднозначный корень отвергается. Все RGBA и размеры точны, без resize.
Порядок яркости мира ночью/в сумерках проверяется независимо от имени режима.
CPU draw и сырые frame-интервалы измеряются без PNG readback внутри samples.
Software X11 не принимает аппаратный FPS, GPU-бюджет или всю VMAP-003.

`retained.py` временно соединяет исходные двоичные части без перепаковки и
вызывает тот же reader. `gallery.py` проверяет каждый native crop без resize;
`metrics.py` сохраняет все 1440 actual samples и проверяет CSV/медианы по capture.
`regressions.py` воспроизводит 19 повреждений копий реального пакета и парный
опыт функций прежнего reader. `output_guard.py` вызывает настоящий captured CLI
в собственном минимальном Git на Linux: существующий output должен вызвать
отказ до engine. DISPLAY там лишь непустое входное условие, sentinel предотвращает
запуск движка; этот negative не является имитацией положительного X11. На macOS
он пропускается, Linux CI должен исполнить его фактически.

`test_reader` входит в architecture gate. Исходный ZIP остаётся неизменным;
SHA частей и целого проверяется до чтения. Дополнительные модули описывают
хранение/публикацию результатов и не меняют 46 замороженных producer/reader inputs.
