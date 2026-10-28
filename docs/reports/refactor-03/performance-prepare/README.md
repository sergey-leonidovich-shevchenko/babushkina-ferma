# REFACTOR-03 — performance source-root/Git, 0.0.370

Перед физическим переносом performance подготовлены8 source-root sites,8 производственных Git-read sites и1 Git-read старого fixture, а также2 публичных shell-root. Меняются12 прежних source (10Python/2shell), добавляются package marker и5 реальных context-тестов. Физических переносов и перемещений UID нет: root314, полная03 остаётся `in_progress`/PR21 draft до бюджета≤30 и окончательной приёмки.

`baseline/adaptation-plan.json` содержит точные before/after тексты и SHA. Python использует существующие source-root/Git helpers; системные команды collector сохраняют прежний контекст, только Git получает собственные cwd/env. Shell определяет корень через собственный tools/run.py вместо cwd-зависимого git rev-parse. План/бюджет50, повторы, часы, schema/FROZEN/SCHEDULE, алгоритмы анализа и save worker не меняются.

## Реальные регрессии и сохранение поведения

Один test source проверяет5 настоящих случаев: asset_state/revision явного проекта; provenance старого native-пакета в code history; collector rev-parse; публичный shell --help с чужим одноимённым файлом; smoke shell с fake-engine свидетелем argv/cwd. Последний случай не запускает игру и не является FPS-допуском. Настоящие два Git fixture имеют разные commits/assets, чужие index/config и вызывающее окружение сохраняются. Source SHA один для `context-red.txt` (4fail/1error) и `context-green.txt` (5/0).

Настоящий before/after `profile.py` запускает старые CLI из другой cwd. Анализаторы пишут только во внешние копии JSON; assets audit читает настоящий граф; VPERF contract/controls пересчитываются по прежним signed-архивам. Проверяются два существующих output refusal с неизменным sentinel. Отдельный настоящий audit создаёт и прерывает только14 собственных headless save-worker процессов на прежних checkpoints; public smoke исполняет headless main180. Это API/сохранность поведения, **не новый GPU/FPS, окно или художественная приёмка**.

Первый before-профиль ошибочно передал --controls без его обязательного --output controls. Его code/logs сохранены (`profile-attempt01.py.gz`, `before-05.txt`); правильная полная серия — before attempt02. Продуктовая CLI-семантика не менялась. Первый before smoke использовал обычное окружение: его userdata fingerprint не заявляется. Дополнительный before smoke повторён в temporary HOME; настоящий SceneTree probe без Game подтвердил путь userdata внутри него (`before-isolated-smoke.json`). After и последующие native QA используют изолированные HOME/XDG. Слоты/default files для SIGKILL worker всегда только собственные временные.

Первый after-прогон выявил ещё один старый consumer: test_reviewed_old_wrapper_reproduces_overwrite наследовал чужой GIT_DIR при git show закреплённого79a1a65f. `after-18.txt`, `test-redraw-before-consumer-git.py.gz` и первоначальный план сохранены; вызову добавлен тот же git_environment, старый commit/тело/утверждения не ослаблены. Он является девятым Git-read site. После этого повторён полный after attempt02. Все108 прежних методов/assertions пяти suites сохраняются; вместе с5 новыми они выполняются из foreign cwd/Git.

## Приёмка и границы

`audit.py` проверяет точный scope/mode,108 старых методов/assertions,37 полей/21 module,85 авторских ignored UID+water anchor, сохранность runtime/artwork/старых reports/планов и других6 карточек. `source-freeze.json` связывает проверенный код с manifest. Собственная полная серия architecture/Game/normal/F10/Wiki обязательна; browser отдельно проверяет актуальную статью, карточку, profile attachment и390px.

Предыдущий369 headc6f323d8 принят независимым review5690215352 и Team. Его фактический CI8/8 и review сохранены в baseline; они не заменяют CI/review370. Авторские реальные worker/smoke и проверка старых FPS-данных разделены. После нового exact-head review/решения Team продолжится физический performance-перенос в рамках полной03; отдельного разрешения владельца не требуется. Параллельный чужой план07 не включён. Очередь остаётся полная03 →07 →06 → первая overworld доVMAP-003, без новых механик/карт.
