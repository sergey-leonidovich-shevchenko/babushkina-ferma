# VLIGHT-010 · Упрощённый свет

Статус `in_progress`. [План и границы](../../../../../docs/reports/visual-overhaul/vlight-010/PLAN.md).
Нативные доказательства ещё не получены; полная приёмка не заявляется.

`review.gd` исполняет настоящую `lighting_quality_suite` и фабрику сцен в отдельном
headless-профиле `Codex-VLIGHT-010-*`. Startup userdata применяется до первого
обращения к движку и подтверждается фактическим OS user dir; обычные файлы
сравниваются до/после. Это модель и save-инварианты, не визуальная или FPS-приёмка.

```sh
python3 tools/run.py qa.world.lighting.quality.test_contract
python3 tools/run.py qa.world.lighting.quality.collect --output /absolute/fresh/output
python3 tools/run.py qa.world.lighting.quality.verify --output /absolute/original/evidence.zip --expected-head <SHA> --check-current-candidate
```

Collector требует удалённый Linux/X11, чистый checkout и точный
`VLIGHT_QUALITY_EXPECTED_HEAD`; обычный игровой GUI на ПК владельца не запускается.
Два настоящих Git-экспорта и46 замороженных входов дают304 артефакта/270PNG.
HUD снят отдельно. Контроли пропускают реальные проходы фасадов/интерьера,
врагов и ресурсов; вызовы фиксируются, игровое состояние сохраняется.

Reader читает исходный ZIP с корнем source.json или evidence/source.json;
неоднозначный корень отвергается. Все RGBA и размеры точны, без resize.
Порядок яркости мира ночью/в сумерках проверяется независимо от имени режима.
CPU draw и сырые frame-интервалы измеряются без PNG readback внутри samples.
Software X11 не принимает аппаратный FPS, GPU-бюджет или всю VMAP-003.
