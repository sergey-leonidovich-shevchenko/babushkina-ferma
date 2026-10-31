# REFACTOR-06 — навигация и правило размещения tools

Работа начата и принята 31 октября 2026 года на базе `main` `b560e1f4485d02dd7d3c8ede808847996e8111e8` после полного закрытия REFACTOR-03 и REFACTOR-07. [PR31](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/31) принят на exact head `81142f385603668792377964a1d4f2bd50afb8a6`: независимое review5724142227 дало APPROVED, два workflow run завершили 8/8 jobs success, Team Lead подтвердил merge. Merge `bcf9b1031ba80a0d0840d10e615f5c7d00d31cf0` имеет то же дерево `33fed2983acd12c30e2850969f7a5d07cf44a35e`, что reviewed head.

[Каноническая карточка](../../epics/refactoring-2026-10/TASKS.md#refactor-06--закрепить-навигацию-и-правило-добавления-новых-инструментов) · [запись приёмки](closeout/completion.json) · [правила и команды](../../../tools/README.md) · [полная текущая карта путей](inventory.json).

## Числа до и после

| Срез | Исходники непосредственно в `tools` | Все исходники `tools` | UID | Пояснение |
| --- | ---: | ---: | ---: | --- |
| Исходная постановка, main `2fa58d3` | 540 | 540 непосредственно в корне | 206 tracked непосредственно в корне | Историческое измерение REFACTOR-01, не пересчитано новым кодом |
| Принятая база задачи, `b560e1f4` | 11 | 633 | 218 tracked / 304 после Godot import | Структура после REFACTOR-03 и quality gate REFACTOR-07 |
| Текущий кандидат REFACTOR-06 | 11 | 635 | 218 tracked / 304 после Godot import | Добавлены только guard и его тест в `tools/quality`; root не вырос |

Лимит корня остаётся 30, но свободные 19 мест не разрешают класть туда внутренний helper. Разрешены ровно 11 документированных source-входов. Единственный tracked root UID — `performance_sampler.gd.uid`; `water_audit.gd.uid` создаётся Godot локально и поэтому разрешён после импорта, но не требуется в чистом checkout. Все существующие UID проверяются отдельно от source budget и обязаны иметь настоящий соседний исходник.

Полная машинная ведомость содержит каждый из 635 source и 304 видимых UID, владельца домена, 11 причин root-исключений и нулевой список ошибок. Она получена публичной командой `python3 tools/run.py quality.tool_layout --json`; список вложенных файлов не зашит в guard и служит отчётом конкретного кандидата.

## Владельцы и навигация

| Домен | Source | UID после импорта | Владелец |
| --- | ---: | ---: | --- |
| `assets` | 122 | 45 | Asset Pipeline |
| `build` | 7 | 1 | Release Tooling |
| `common` | 7 | 0 | Developer Platform |
| `dev` | 6 | 1 | Developer Experience |
| `planning` | 12 | 0 | Team Lead / Planning |
| `qa` | 454 | 255 | QA |
| `quality` | 16 | 0 | Tech Lead / Quality |
| root | 11 | 2 | Только поимённые публичные входы/anchors |

`tools/README.md` теперь ведёт к общему architecture gate, foliage QA и обработке атласа. Три безопасных Python-маршрута проверяются из корня проекта и из внешней cwd. Генератор атласа запускается только с `--help`, поэтому проверка навигации не перезаписывает игровые PNG.

## Guard и отрицательные сценарии

`quality.tool_layout` обходит реальные файлы, включая незакоммиченный root helper, но исключает установленный `tools/Godot.app` и cache. Он отклоняет неизвестный root source/UID, неизвестный верхний домен, превышение честного source-порога, orphan UID и source/directory symlink. Новый nested source в существующем владельческом домене принимается без обновления frozen snapshot.

Девять disposable-сценариев проверяют текущий checkout, чистый checkout без generated root UID, разрешённый nested source, новый внутренний root helper, неизвестный домен и превышение лимита, missing/orphan UID, два вида symlink, недоступный каталог и три документированные команды в двух cwd. Первый настоящий Git-only архив выявил слишком строгое ожидание теста: тест требовал локальный `water_audit.gd.uid`, хотя production guard правильно считал его необязательным. После адресной правки тот же архив принял nested source и отклонил новый root helper.

Независимый review5724024281 затем нашёл второй реальный red: `os.walk` без `onerror` молча терял содержимое chmod000-каталога и возвращал неполную inventory с exit0. Новый fail-closed callback сохраняет путь и системную причину в `errors`; тест с гарантированным восстановлением прав даёт parent `f04da49d` 1 failure и текущий код 1/1 pass. Оба red→green сохранены в validation. Настоящие production, ассеты, raw и прежние отчёты при этом не изменяются.

## Границы и будущие задачи

REFACTOR-04 остаётся `blocked`: suites/helpers не переносились и не объявляются сгруппированными. REFACTOR-05 остаётся `blocked`: `scripts/systems` и `scripts/presentation` не переносились. Их прежние аудит-карты сохранены. REFACTOR-06 закрывает только первый выпуск структуры `tools`; не принимает Game, FPS, VMAP-003 или новую игровую механику.

Локальный Game не запускался по действующему указанию. Полные Game/normal/F10, platforms, Wiki и architecture выполнены удалённым CI точного опубликованного head; оба workflow run дали суммарно 8/8 jobs success, architecture — 110 suites / 1445 cases. [Validation](validation.json) сохраняет локального кандидата и реальные red→green; [completion](closeout/completion.json) отдельно фиксирует принятую реализацию. Следующая очередь — первая overworld до VMAP-003. REFACTOR-04/05 остаются `blocked`, весь эпик этой приёмкой не закрывается.
