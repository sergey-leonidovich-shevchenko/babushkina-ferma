# REFACTOR-01 — полная карта инструментов перед переносом

Аудит 26 октября 2026 года. Начальная база `206918ab` и её завершённые gates сохранены в [отдельном начальном пакете](initial-206918ab/README.md); после принятия PR #8 выполнен fast-forward рабочей ветки и пересчёт по новой main. Основание — принятая main `ad60faf4bd46faa335babb6075737694927fc61f`, версия `0.0.341`, после PR #10/#11 и принятого PR #8. Результат — предложение структуры и воспроизводимая ведомость, **не выполненный перенос**. Карточка остаётся `in_progress` до независимого ревью точного head PR и решения Team Lead.

[Wiki](../../../wiki/articles/project-refactoring.md) · [карточка](../../epics/refactoring-2026-10/TASKS.md) · [полная таблица](snapshot/tool-map.md) · [CSV](snapshot/tool-map.csv) · [JSON](snapshot/tool-map.json) · [порядок пакетов](migration-batches.md) · [фактические проверки](checks.json).

## Что посчитано

Сборщик читает **все 24 056 Git blobs, 6 719 798 742 байт** точного commit, хеширует каждый SHA256 и отдельно анализирует текстовые ссылки. Рабочие изменения, ignored runtime, `.godot`, локальные UID и временные прогоны не подменяют основание. [Манифест](snapshot/baseline-files.jsonl.gz) содержит путь, Git blob, размер, mode и SHA каждого файла. Это позволяет сохранить не только избранные картинки, но и прежние планы, source-копии, raw, капсулы и неудачные попытки.

| Область | Непосредственных файлов | Рекурсивно | Исходники / отдельно UID |
| --- | ---: | ---: | --- |
| tools | 767 | 779 | в корне 553 исполняемых; всего 558 + 1 вложенный shader / 216 UID |
| scripts/systems | 564 | 564 | 282 GDScript / 282 UID |
| scripts/presentation | 184 | 184 | 89 GDScript + 3 shader / 92 UID |
| tests/suites | 350 | 350 | 174 suite + suite_base / 175 UID |
| tests/helpers | 6 | 6 | 3 GDScript / 3 UID |
| wiki/scripts | 20 | 20 | 15 MJS + 5 GDScript |
| docs/reports | 263 | 17 297 | доказательства; не список модулей для переноса |
| assets/game/items/ui/preview | 772 | 772 | 386 PNG + 386 import |

Под «исполняемыми исходниками» сохранён прежний набор расширений `.py/.gd/.sh/.swift/.mjs`; shader показан отдельно и включён в будущий бюджет корня. JSON и UID не выдаются за исходники. Физические строки длинных модулей не объявляются нарушением architecture: действующий лимит исключает пустые строки и комментарии.

## Предложенная структура

Явная [политика](migration-plan.json) назначает путь **каждому из 779 файлов**, а валидатор отклоняет пропуск, коллизию, выход за tools, разрыв UID-пары и необъяснённый корневой исходник. Сочетание Python/Godot/контролей одной подсистемы сохраняется. Таблица включает назначение, исходный SHA, CLI-декларации и `FARM_*`, tracked UID, точные и потенциальные ссылки, а также найденную цепочку зависимостей gate.

| Семейство | Целевой каталог | Всего файлов, включая UID |
| --- | --- | ---: |
| Общие проверки | tools/quality | 3 |
| Бэклоги и служебный учёт | tools/planning | 11 |
| Подготовка графики | tools/assets/authoring | 36 |
| Альфа и края | tools/assets/alpha | 8 |
| Нарезка атласов | tools/assets/slicing | 11 |
| Происхождение ресурсов | tools/assets/migration | 7 |
| Контракты текстур и UI | tools/assets/contracts | 59 |
| Подготовка аудио | tools/assets/audio | 5 |
| Пакеты и передача художнику | tools/build | 5 |
| Ручные стенды | tools/dev/art_review | 5 |
| Художественные проверки | tools/qa/art | 26 |
| Камера и нативный baseline | tools/qa/camera | 44 |
| Растительность | tools/qa/foliage | 102 |
| Грунт и дороги | tools/qa/ground | 113 |
| Объекты первой карты | tools/qa/world | 142 |
| CPU, память, диагностика | tools/qa/performance | 49 |
| Регрессии действующих систем | tools/qa/compatibility | 153 |

Каталог `tools/common` появится в 02 только под настоящие общие функции. Пустые папки и `__init__` ради внешнего вида не создаются. Установленные `tools/Godot.app`/`Godot.exe` остаются на месте.

### Девять будущих входов в корне

| Путь | Решение и реальный потребитель |
| --- | --- |
| tools/check_architecture.sh | CLI-фасад; pre-commit и Actions, реализация в quality |
| tools/bump_version.py | CLI-фасад; pre-commit и общий gate, реализация в planning |
| tools/task_batch.py | CLI-фасад; post-commit/status. Исторический publish не обходит PR |
| tools/smoke_test.sh | CLI-фасад Actions, прежние параметры и 180 кадров |
| tools/performance_gate.sh | CLI-фасад CPU gate Actions, прежние пороги и коды отказа |
| tools/performance_gate.py | Import/CLI-фасад frozen redraw_compare.py:22; сохраняет идентичность модуля и изменение gate.SAMPLER |
| tools/performance_sampler.gd | Полный прежний исходник + UID: frozen исполняемый test_causal.py читает именно этот путь |
| tools/water_audit.gd | Полный прежний исходник: физическая ссылка из frozen отчёта WATER должна продолжать открываться |
| tools/run.py | **Новый, только предложенный** единый Python launcher; без сотен старых wrappers |

План — **9 ≤ 30 исходников**, а не заявление о нынешнем корне. Шесть фасадов делегируют единственной реализации, два защищённых исходника не копируются. Основания, строки потребителей и граф доступны в JSON. Будущий README перечисляет эти исключения и проверяет их по реальным файлам в 06.

## Реальные связи и исторические доказательства

[Ledger](snapshot/references.jsonl.gz) хранит consumer, строку, вид связи, scope и target. Кандидаты search path дополнительно разобраны вручную для исполняемых frozen consumers. У каждого инструмента есть индексы строк ledger; команда `show` раскрывает их без поиска по всему репозиторию. Разделены:

- явный файловый путь, локальный Python import, Godot preload/load и UID;
- динамический шаблон, prefix-фильтр и import, которому ещё нужен search path: это **кандидаты**, не доказанные вызовы;
- CI/hooks/run_tests, живой код, текущая документация/данные и frozen code/raw;
- настоящая Markdown-ссылка и имя в команде или будущем плане.

Статическая цепочка gate означает достижимость файловых зависимостей, **не выполнение каждой ветви**. Старые ведомости тоже ссылаются на tools, поэтому наличие исторической строки не доказывает использование. Отсутствие распознанной ссылки не разрешает удалить инструмент. Сборщик не запускает массово `--help`: среди asset-builder есть незащищённый код верхнего уровня, способный писать ресурсы.

Индексированы семь ZIP/TAR, 28 members tools, без ошибок чтения и без извлечения или перепаковки. Старый member может отличаться от принятого исходника: это историческая версия, не повод её «исправить». [Индекс](snapshot/archives.json) и полный SHA-манифест сохраняют происхождение.

Критические адресные решения:

1. `check_architecture.sh → docs/reports/visual-overhaul/vfoliage-006/causal-investigation/instrumentation/test_causal.py → tools/performance_sampler.gd` — реальная живая цепочка в frozen code. Сам sampler сохраняет старый путь и байты.
2. `test_redraw_observer.py → redraw_compare.py:22` импортирует performance_gate с явным ROOT/tools и присваивает `gate.SAMPLER` (строка81). Это разрешённый вручную search-path кандидат. Один module-identity facade сохранит mutable globals и API; простое `from implementation import *` не подходит. Импорты реализации на performance_protocol в03 становятся квалифицированными.
3. `docs/reports/water-2026-10/README.md:36` — единственная frozen физическая Markdown-ссылка на tools. Сохраняем water_audit.gd; link checker остаётся включённым. Остальные 24 физические ссылки обновляются в их живых документах при переносе.
4. 52 совпадения imports `SOURCES/OVERLAY/SOURCE_FILES`: например, meadow_verify читает descriptor текущего collector для старой капсулы. В 02/03 явно отделить неизменяемое старое пространство имён источников от новых физических путей. **Не переписывать** план, capsule SHA или source-key старого опыта под будущий HEAD.
5. Prefix-проверки вида `startswith("tools/village_bench")` в readers — классификация старого overlay, а не поиск новой папки. При переносе сохранить историческую семантику отдельно от текущего collector.
6. [Три живых неразрешённых имени](reference-decisions.json) разобраны вручную: сокращение tools/tests в прозе; будущий tools/README.md в критерии 03; не реализованный visual_environment_review.gd в импортированном плане. Это не три потерянных исполняемых файла. Исторические неразрешённые ссылки остаются в ledger и не замалчиваются.

[739 адресов для просмотра](snapshot/hazards.json) — не 739 доказанных багов: 208 нерекурсивных кандидатов, 166 file-relative привязок, 149 imports с требуемым search path, 118 фиксированных parent-depth, 52 общих исторических descriptors, 29 prefix-проверок, 9 вложенных Git-вызовов и 8 search-path совпадений. [Межсемейные imports/preload](snapshot/cross-family-imports.json) задают порядок небольших пакетов, не только красивое дерево.

## UID, пути и два воспроизведённых риска

Из 302 Godot-исходников tools у 216 есть tracked UID, у **86 нет UID в Git**. Локальные ignored sidecars существуют; их отдельная [локальная ведомость](local-uid-observation.json) не выдаётся за содержимое принятого commit. `.gitignore` сначала исключает `tools/*`, затем разрешает отдельные имена — новые папки сами в Git не попадут. В 02/03 нужны точечные разрешения тематических каталогов, поштучный preflight UID и перенос исходника вместе с выбранным стабильным sidecar. Не делать общий `git add -f tools` и не пересоздавать принятые UID. Godot рекомендует сохранять и коммитить sidecars при переносе [в официальной статье об UID](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/).

Проверены настоящие неизменённые фрагменты принятой базы в disposable fixtures:

- [Глубина пути](experiments/root-depth.json): byte-identical check_documentation.py проходит в tools и отказывает во вложенной tools/quality из-за `.parent.parent`. Настоящий проект не перемещался. Общее определение корня — обязательное условие 02.
- [Окружение hook](experiments/git-hook-environment.json): точный метод test_required_log_must_be_indexed из test_shore_kit с искусственными `GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE` меняет **только disposable parent config** и падает. Граница с очисткой GIT_* проходит и сохраняет config/index. SHA настоящих config/index до/после одинаковы. Сам test_shore_kit.py здесь не исправлен; изоляция — первый адресный шаг 02 перед запуском hooks во время переносов.

Сборщик аудита сам очищает GIT_* для вложенного Git. Его контроли используют настоящий временный repo и linked worktree с пробелами, другую cwd и `.git`-файл. Для будущего launcher argv, коды отказа, env и смысл относительного output сохраняются отдельно по командам: нельзя бездумно менять cwd у всех CLI. Python начинает module search с каталога скрипта либо cwd для `-m`; глобальный PYTHONPATH не является решением [по документации Python](https://docs.python.org/3.12/library/sys_path_init.html).

## Другие каталоги: адресные решения

Полные имена файлов, будущие пути, UID и потребители перечислены в [other-catalogs.json](snapshot/other-catalogs.json). Это предложение для 04/05 после полезного выпуска tools и решения Team Lead, не разрешение переместить весь production.

| Семейство | Решение | Польза / граница |
| --- | --- | --- |
| systems/storage, 6 GDScript | Предложить 05: scripts/systems/storage | Один домен ввода, сортировки и переноса; прежние save/инвентари |
| systems/furnace, 3 GDScript | Предложить 05: scripts/systems/furnace | Малый data/locale/system домен, без остальных ремёсел |
| presentation/storage, 4 GDScript | Предложить 05: scripts/presentation/storage | Actions/geometry/renderer/cache вместе с systems-storage |
| presentation/foliage, 7 GDScript + 2 shader | Предложить 05: scripts/presentation/foliage | Общие UV/root/wind/contact/recovery bindings и UID |
| suites/foliage, 8 suites | Предложить 04: tests/suites/foliage | Сохранить nested run из ArchitectureSuite и прямые QA-профили |
| suites/storage, 4 suites | Предложить 04: tests/suites/storage | Не потерять вложенные grid/cache suites |
| helpers, 3 GDScript | Оставить | Уже отдельные короткие сценарии; новая глубина не помогает |
| reports, 17 297 файлов | Оставить frozen | Индекс/Wiki вместо переименования доказательств |
| wiki/scripts, 20 исходников | Оставить | Границы catalog/store/API/runtime/export уже видны |
| preview, 386 PNG/import пар | Оставить | Стабильная адресация по ID, не перегруженный модуль кода |

Остальные systems/presentation/suites **не включены**: один размер папки не доказывает пользу. Длинные locale/level_editor/debug-модули потребуют отдельного поведенческого анализа; данный аудит не разрешает их разрезание. Для suites есть полный [граф активации](snapshot/suite-registry.json): 174 suite, 37 прямых верхних запусков, нет недостижимых наборов, циклов и повторных статических путей; suite_base учтён отдельно. Это статическая исходная ведомость для будущего сравнения, фактический Game записан в проверках.

## Воспроизведение и приёмка

```sh
python3 -m unittest discover -s docs/reports/refactor-01/instrumentation -p 'test_*.py' -v
python3 docs/reports/refactor-01/instrumentation/audit.py check --snapshot docs/reports/refactor-01/snapshot
python3 docs/reports/refactor-01/instrumentation/audit.py show --snapshot docs/reports/refactor-01/snapshot --path tools/performance_sampler.gd
```

`check` повторно читает **все** blobs базы, строит весь пакет в новом temp и побайтно сравнивает каждый результат и инвентарь файлов; одной проверки счётчиков или checksum summary недостаточно. Сбор нового пакета: `collect --base <точные 40 hex> --output <новый каталог с существующим родителем>`. Старый output никогда не дописывается. Инструмент требует стандартную библиотеку Python3.10+ и доступный локальный Git commit; без истории нужно сначала получить закреплённую базу, не заменять её HEAD.

`python3 docs/reports/refactor-01/verify_scope.py` отдельно сверяет все старые байты с manifest, новые публикуемые пути, порядок Wiki index и неизменность чужих карточек/реестров. Это scoped-проверка текущего кандидата, не guard будущего HEAD; [результат](scope-audit.json) и настоящий отрицательный контроль лишнего собственного временного исходника сохранены отдельно. 29 контролей включают порчу карты/UID/budget/пакета, динамические ссылки, настоящий Git с наследуемым окружением, linked worktree и запуск из другой cwd. Опыты `probes.py --base <точный SHA> --output <новый каталог>` дополнительно воспроизводят два текущих риска. Доказательства исходной принятой базы перечислены в [baseline-verification.json](baseline-verification.json), а свежие architecture, Game, redraw normal/F10 и Wiki — в [checks.json](checks.json). Старые журналы не выдаются за новые запуски.

Снимок аудита не добавлен в глобальный gate: он намеренно закрепляет старую базу, а не запрещает развитие репозитория. Новый редакционный integration-audit из PR #8 фиксирует статус `01=ready` именно своего head: его нельзя выдавать за универсальный gate будущего in_progress/done и возвращать ради него карточку назад. Принятые записи PR #8 сохраняются по точной базе, текущий статус01 проверяется отдельно. Guard 06 должен проверять актуальные размещение/принадлежность, а не навечно весь нынешний список. Переносы 02/03, новый игровой код, FPS-улучшения, новая нативная съёмка и VMAP-003 этой задачей не приняты.
