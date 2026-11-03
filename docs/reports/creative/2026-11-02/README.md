# IDEA-REVIEW-20261102 · чужой выбор и самостоятельный мир

[Обзор](../../../../wiki/articles/creative-review-2026-11-02.md) · [реестр мест](../../../../wiki/articles/crossing-and-trust-register.md) · [редакционная карточка](../../../backlog/wiki-workspace-2026-10/README.md).

Base `ebf2779fdd721676bb05614c7e2cfd172349d8b3` /metadata405. Предыдущий обзор `8841929c587d7730ddf4a57a18c3858fbee815bb` остаётся открытым PR36; его10 идей учтены при сравнении. Этот отчёт не переписывает прошлый и не реализует новые механики.

[План](plan.json), [десять предложений](proposals.json), [принятые/открытыеPR](accepted-and-pending.json), [Git-разница](reviewed-changes.json), [занятыеID](occupied-ids.json), [опубликованные реестры](published-branches.json), [проверка73 refs](number-reservation.json), [сверка тем](duplicate-review.json), [прочитанные ближайшие области](nearest-scopes.json), [проверенные источники](references.json), [просмотренные сохранённые материалы](viewed-materials.json).

Предметный результат:10 эпиков/52 будущие задачи,19 взрослых ролей/35 узлов/105 ответов/60 будущих F. Старые241/80 и очереди/история сохранены. Статусы игровых карточек backlog, редакционной in_progress.

[Математические свидетели](design-witness.json) и [их воспроизводимый расчёт](design-witness.py.txt) — две последовательности10/11 сдвигов334, не игровая реализация/будущий F. Расчёт не принимает физическую навигацию, графику, ввод или аудиторию.

Фактические проверки после запуска будут отдельными lossless архивами с SHA и frozen источниками. Полный pre-commit не пропускается. Обычные commit/push в своей ветке, PR base main, independent exact-head review/CI и решение Team Lead; main автором не сливается.


## Фактические предварительные проверки

[Actual producer self-review](quality-self-review.json), source405:14 реальных команд/связанный worktree/чужие cwd/environment/Git, собственные temporary проекты удалены, источник/чужие index/config сохранены. ZIP хранит реальные файлы с SHA. [Редакционный профиль](editorial-first.json), [документация](documentation-first.log.gz), [Wiki151/0](wiki-first.log.gz) и [smoke180](smoke-first.log.gz) прошли. [53 буквальных имени веток](branch-name-check.json) приняты настоящим Git. [Foreign Git retry](foreign-audit.json) успешен; [первый helper attempt](foreign-audit-attempt1.json) ссылался на отсутствующий старый entrypoint и не считается проверкой продукта.

**Performance gate не прошёл.** [Первый запуск](performance-first.json), [отдельный повтор](performance-serial.json), [чистая main405](performance-baseline.json) и [сравнение](performance-comparison.json) сохраняют фактический exit1/complete=true/budget=false. Первый запуск шёл рядом со сборкой и содержит timeout; отдельно повторено без неё. На чистом detached main405 также все серии ниже50. Runtime-код кандидата побайтно тот же, project.godot только metadata. Причина не изолирована, native FPS не измерен; это не разрешение принять плохой gate. Ветка/PR могут быть опубликованы как draft для ревью с явным нерешённым пунктом, main автором не сливается, исправление игрового кода остаётся Developer/Team Lead по действующему курсу.

Контрольный clone был создан только для проверки, его HEAD/чистота сверены и собственный checkout удалён после lossless архива. Порог, engine и argv не менялись ради зелёного результата. Старые отчёты не тронуты.

[Браузерная проверка](browser/verified/manifest.json): 16 наблюдённых проверок при metadata406 — десять отдельных статей, шесть оценок, реальная цепочка статья→задача→эпик, зависимости159/VMAP, поиск/Tab, ширина390 без горизонтального переполнения и консоль0 ошибок. Это проверка Wiki, не будущих игровых F. Скриншоты и lossless DOM с SHA сохранены. Повторный `pnpm --dir wiki check` также151/0.

[Незавершённый первый hook](interrupted-preflight/interruption.json) сохранён с exit143: автор нашёл старые allowed-path номера/имя реестра в собственном аудиторе и остановил только свой commit group. Это не успешный architecture/Game gate. [Реальная регрессия](interrupted-preflight/scope-regression.json): старый аудитор отказывает на staged IDEA-332, исправленный проходит и также отклоняет неожиданный untracked sentinel; sentinel удалён. Все новые пути теперь проверяются и до staging. Новый полный hook обязателен. [Повтор с чужим Git](foreign-audit-staged.json) сохранён отдельно от первоначального профиля.

[Draft PR](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/40) · [Публикация](PUBLICATION.md). Первый проверенный head `b754cde4c86f0ef06a8184225d6c3a89e3ecf563`: architecture 113/1505, Game 53549/0, normal/F10 90/90, Wiki 151/0. Это не снимает performance FAIL. Финальный отдельный epoch — publish-1/gates.json после успеха; редакционная in_progress.

[Публикационный браузер407](browser/publication/manifest.json): пять адресных проверок — обзор/PR40, редакционная in_progress/первый SHA, буквальная ветка,390px без переполнения и консоль0. Десять proposal-статей побайтно прежние. Это не повторная игровая/аудиторная/FPS приёмка.
