# REFACTOR-07: P2 staged/index

Независимое ревью PR28/head060787d9 (review5714786476, discussion4425490791) обнаружило обход: исправленный working-файл скрывал ошибочный staged blob. На metadata-head5276b87f quality-код был тем же. Восстановленный working legacy мог вообще исчезнуть из `selected()` благодаря настоящему baseline. Авторское исправление0.0.385 остаётся в том же PR; одобрение нового head и решение Team Lead ещё требуются.

## Изменение

Hook вызывает `quality.check --staged` до штатного bump. Guard сверяет сырые байты всех обнаруженных/index/HEAD Python/GDScript и quality rules **до** baseline; при разнице явно отказывает. Нет stash, autofix или Git add. Обычный working check и CI сохраняются. Законный alternate index, включая относительный путь, читается; прочие Git overrides изолируются. Его дополнительные source paths поступают в lint selection. `fix --staged` запрещён. CRLF/clean-filter различия тоже дают явный отказ, что описано в руководстве.

## Реальные проверки

- Новый `quality.test_index`:11 случаев на настоящем Git. Новые/старые staged ошибки, legacy baseline, удаление/rename, разные quality rules, ignored alternate-only path, относительный alternate/чужие overrides, запрет staged fix, исправленный staged positive и отдельный git commit.
- Отрицательные прямые вызовы настоящего hook сохраняют raw index/config/version/working. Положительные вызывают реальные Ruff/mypy и настоящий bump, затем останавливаются на своей явной shell-границе перед architecture/Game. Это проверка границы, не успешный полный commit и не игровой допуск.
- Сам `git commit` может обновить служебные cache extensions index до входа в hook. Его отдельный контроль сравнивает staged mode/OID/path и все остальные рабочие/metadata bytes; source и HEAD не меняются. Это отличие раскрыто, а не замаскировано нормализацией index.
- [Одинаковые регрессии](same-regression.json): старые реальные hook/check/selection из5276 —2 failures/0 errors; исправленные —2 pass. Старый gate реально пишет `QUALITY: 0 failed steps`, выполняет bump и доходит до границы. Исправленный останавливается с `QUALITY INDEX` раньше. Ни import/setup failure, ни любой произвольный exit1 за red не принимаются. [Старые запуски](old-actual-hooks.json), [новые](new-actual-hooks.json).
- [Публичный launcher из чужой cwd/Git](actual-public-staged-rejection.json): текущий рабочий checkout с разными staged/working bytes отвергнут кодом2; сохранены5104 записи source/index/config, версия и окружение. Game не запускался этим контролем.
- [Браузер](browser/checks.json): обновлённый раздел прочитан на1280 и390CSSpx, документ без горизонтального переполнения, внутренний переход к порядку приёмки и обратно. Собственные вкладка31/сервер4197 закрыты; пользовательский4175 не менялся. Wiki145/0.

Для нового воспроизведения используйте Python3.11 с quality requirements:

```sh
python3 docs/reports/refactor-07/review-p2-index/replay.py /абсолютный/корень/игры /tmp/новый-внешний-отчёт
```

`replay.py` требует новый внешний каталог. Файлы `*-executed.py.txt` сохраняют точные первоначальные runners с их тогда новыми output paths; повторно на исторические пути их не запускают. Fixture содержит одинаковое окружение и новые helper для обоих контролей; из5276 подменяются только проверяемые hook/check/selection с зафиксированными SHA. Старый check новый helper не вызывает. Temporary parent удаляется.

## Полная серия

[Команды и коды](checks.json) фиксируются последовательно на одном source freeze. Финальная серия завершена: все8 gates вернули0; architecture109/1436, Game53502/0, normal/F10, smoke, performance и Wiki145/0. Внешний процесс работал без родительского PYTHONDONTWRITEBYTECODE. Все1230 source SHA,22411 прежних reports,800 tracked UID, чужие5 working/3 staged и собственный raw index сохранены. [Итог](final-validation.json). Прежние108/1424 относятся к ранним10 quality cases; последующий11-case профиль предыдущего head выполнялся отдельно. Новые счётчики нельзя выводить из старых без фактического прогона.

Исследовательские попытки подготовки fixture не считаются результатом: первоначально обнаружились отсутствие package markers/модуля Godot в малой fixture, Git cache extension при самом commit и ошибочно поставленный assert переменной. После исправления fixture все11 реальных случаев прошли. Рабочие/исторические исходники проекта этими попытками не менялись.

Контроль чистого CI-окружения выявил отдельную ошибку самой fixture: без родительского PYTHONDONTWRITEBYTECODE Python создавал __pycache__, который полный data snapshot считал изменением. Реальный отказ1/1 сохранён в no-bytecode-env-control.txt; fixture теперь сама задаёт флаг только своим subprocess, и обычный запуск без родительского флага прошёл11/0 (no-bytecode-env-fixed.txt). Первая полная серия намеренно остановлена автором SIGINT после96 suites/1259 cases; это частичный прогон, не полная приёмка. Все её raw и4 завершённых gate сохранены в partial-01. Финальная серия запущена заново без родительского флага на новом неизменном source freeze. Первые пары9eef сохранены в controls-initial; текущая корневая пара содержит финальный SHA теста.

Большие сырые snapshots без изменения байтов упакованы в preservation-snapshots.zip. [Manifest](preservation-archive.json) сохраняет исходные имена, SHA256, размеры и ZIP entry; одинаковые полные before/after payload хранятся один раз. Все entries побайтно сверены с оригиналами после чтения ZIP. Для изучения извлеките нужный payload в новую внешнюю папку, сохраняя manifest; исторические файлы проекта не заменяйте.

Штатный performance gate прошёл6/6 повторов normal/F10; все source/context/result/stdout сохранены без изменения байтов в performance-raw. Это существующий performance-контракт, отдельная новая графическая/VMAP-приёмка не объявляется. Повтор Wiki после записи фактов сначала отказал в sandbox на macOS get_system_ca_certificates; исходный отказ сохранён в wiki-facts.txt, повтор выполняется с теми же штатными правами, что полная успешная серия.

После записи результата выполнены documentation-final и Wiki-final-link (145/0); runtime Python/GDScript прежние. Браузер проверил поиск07, in_progress, блокер03done, фактические109/1436/53502 и текст ожидания ревью на1280/390. Итоговый JSON доступен download-ссылкой из code-quality; exported attachment побайтно равен исходному SHA f3a835823cf6ee4ee0427f9f001a196658d8801a1a13d5979f4473d7bde3f0ca. Свои вкладка32/сервер4197 закрыты.

На полностью подготовленном index текущего checkout публичный quality.check --staged из /private/tmp также прошёл без родительского bytecode-флага: static10, код0 и5104 source/index/config состояния прежние (actual-staged-positive.json/txt). Все команды pre-commit выполнены отдельно на том же source freeze; для публикационного commit повтор часового набора в hook не дублируется. Настройка hooks репозитория не изменяется; независимое ревью/CI/Team не обходятся.
