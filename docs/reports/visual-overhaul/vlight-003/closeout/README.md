# Приёмка палитры VLIGHT-003

21 ноября 2026 принят [PR №82](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/82): независимый [APPROVED6005842576](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/82#pullrequestreview-6005842576) и решение Team Lead относятся к точному head `abb32457fa307c70a0fe9724200c3d70d3a5ab62`, tree `7d77df07236b937b592529e4ec4f84e20b45dd07`, версии `0.0.475`. Все три предварительных замечания закрыты у исходных строк; новых actionable-замечаний нет.

Обычный merge — `59117c81d1a24d021868829e6a1e9abd4fa6431b`. Его родители — прежняя main `c1f2eda0d1d36e1491dab32fef090bb5a3d22e12` и одобренный head; дерево merge равно одобренному. Git `%cI` merge — `2026-11-21T19:16:08+05:00`, откуда взята календарная дата приёмки. Локальная main обновлена только ff-only.

[Запись приёмки](result.json), [действительный независимый вердикт](implementation-review.json) с проверенным `commit_id` и [10 успешных check-runs этого SHA](implementation-checks.json) различают проверки реализации и последующего учёта. Обе основные CI jobs, обе Wiki, fixed-input Linux/macOS и две native jobs успешны. Локальный полный hook реализации дал Game53709/0, normal/F10 по90/0; CI — Game53727/0. Эти отдельные счётчики не смешиваются.

Принята плавная палитра рассвета/сумерек первой `overworld`: существующие дробные минуты, один слой перед HUD, прежние endpoints, фонари, события и остальные сцены, неизменные save/геометрия, временный откат одного canvas. Это не GPU, аппаратный FPS, Retina, долгая сессия или приёмка всей VMAP-003.

Серия captured1abc82b2 сохранена без пересъёмки: 222PNG, 256артефактов, 34QA-входа, 2160samples и12 native crop. Финальный abb прошёл strict-current с разрешённой разницей только SemVer и новую X11-съёмку в CI. P2 old/new имеет9 реальных CLI, три переподписанных дефекта old0/new1 и исходный пакет current0. Исходные CI1/2 отказы остаются диагностикой. Полный [исходный отчёт](../README.md) и его предкоммитный acceptance.json сохраняются как исторические документы; актуальная приёмка находится здесь.

[Ведомость сохранности](preservation.json) фиксирует все189 уже принятых файлов VLIGHT-001/002/003, в том числе57 файлов новой серии. Их SHA256, остальные1036 visual-карточек, top metadata и planning state revision245/sources не меняются. Runtime/tools/tests не изменяются; новая версия относится к публикационным метаданным.

[Реальный dependency graph](route.json) вызван через существующие `readPlanningCatalog`, `locationPortions` и `firstLocationOverview`. До и после VLIGHT-003→done первая порция содержит93 карточки, из них83 done; missing0, VMAP-003 не принята. VLIGHT-003 не входит в эту dependency-порцию, поэтому её завершение не увеличивает83 вручную. Карточка появляется в общей истории света с фактической датой из единственного Task-Complete.

Отдельный учёт проходит свой штатный полный hook, strict-current/gallery/metrics, post-bump Wiki и реальный браузер desktop/390: done-карточка, PR82, дата21 ноября, история, поиск, статья/три native изображения и новое JSON-вложение. После публикации обязательны собственные CI, независимое APPROVED точного учётного head и решение Team Lead. Только затем — обычный merge/ff-only main, проверка Wiki принятой main и очистка собственных полностью влитых веток. Проверки реализации не заменяют эти gates; следующая карточка здесь не начинается.
