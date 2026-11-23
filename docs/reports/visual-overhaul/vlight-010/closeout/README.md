# Учёт принятой VLIGHT-010

23 ноября 2026 принята реализация [PR №90](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/90).
Независимый Tech Lead дал [APPROVED](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/90#pullrequestreview-6018708449)
точному head `a1e9c8d587a206ece892a9737352366bb1ea821a`, версия 0.0.493.
Все 12 текущих CI завершились успешно; Team Lead принял тот же SHA.
GitHub использует COMMENTED для явного независимого вердикта общего аккаунта,
как предусмотрено `docs/CODE_REVIEW.md`.

Обычный merge `2ad79b4e24b39a953a651d88e68e55e1536eecee` выполнен в
13:48:41 +05:00. Родители — принятая main `d0f748105d57abade82f5c36e7f4e61aaa9ab3cb`
и одобренный head. Tree `b92e43190e160c530ee7941cd7cde57d6927cbac` точно равен
одобренному. [Машинная запись](result.json), [независимый вердикт](implementation-review.json)
и [все CI](implementation-checks.json) сохраняют фактические идентификаторы.

## Принятое поведение и доказательства

Временный профиль принадлежит одному владельцу: standard сохраняет прежние пиксели,
low использует 65% alpha той же календарной кривой и пропускает декоративные
ореолы/оконный луч, off пропускает световой проход. Сохранения, календарь,
HUD, корпуса предметов, двери, враги, ресурсы и контактные тени сохраняются.
Два viewport независимы; общий visual rollback первой карты возвращает прежний
свет и сохраняет запрошенный профиль для повторного включения графики.
Существующий дом участвует как регрессия перехода, его интерьер не переделан.

[Первый оригинальный пакет](../native-ci-01/archive.json) остаётся побайтным:
173941412 bytes, SHA256 `a8206c84afd1e48f9a2fc54b12f133c7b51917c4bd0f44148303776d8f4d2c11`.
Три части, 270 PNG, 304 артефакта, 46 QA-входов, галереи, 1440 samples,
19 повреждённых копий и парное воспроизведение прежнего дефекта reader сохранены.
Снимок `verification.json` и CI source2 сохраняют историческое назначение.

[Свежий native CI](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/actions/runs/45135670704)
одобренного a1e9c8d также успешен. Artifact 14799912833: 173941860 bytes,
SHA256 `21a122f0c546b3affa5a1e871b627f10543b69d645e60b09732b13ee9e28a803`.
Автор и независимый ревьюер выполнили полный readonly reader с expected-head
и `--check-current-candidate` на чистых checkout: 270 PNG / четыре запуска,
standard точно равен baseline. Независимый вычисленный summary полностью равен
JSON текущего CI. Все 270 новых PNG побайтно равны исходной серии;
прежде просмотренные кадры остаются теми же. [Происхождение свежего пакета](implementation-native.json).

P2 про исчезнувшую ссылку PR в действующей карточке исправлен. Настоящий computed
TaskBoard старого 200f9d23 возвращал null, исправленного — label/URL PR90.
Независимый ревьюер закрыл исходный thread ответом 4663196203. Авторские реальные
клики при 1280/390 px открыли PR90 в новых собственных вкладках. Первая ошибочная
мобильная навигация в предметы сохранена и за PASS не засчитана; причина не установлена.
Статья, четыре PNG и семь вложений прошли побайтную HTTP-сверку на working-task
a1e9c8d/.493/sourceDirty=false; горизонтального overflow и console warnings/errors нет.

## Проверки реализации и отдельного учёта

Полный обычный hook реализации: quality 275 целых файлов / 0 ошибок,
architecture 132 группы / 1727 тестов (один Linux-only skip на macOS),
Game 54121/0, normal/F10 по 90/0. Post-bump Wiki 167/0; normal userdata неизменны,
собственный override удалён. [Санитизированные локальные receipts, stdout и browser proof](implementation-local-logs.zip)
не включают исходные hashes обычных userdata или сервисные токены.

Оба текущих общих CI-журнала независимо прочитаны: quality 275/0,
architecture PASS, water 55/0, Game 54139/0, normal/F10 по 90/0, smoke 180,
по шесть valid/budget-passed performance-серий. Оба Wiki дали167/0.
[Выдержка PR-журнала](implementation-pr-test-excerpt.txt) и
[выдержка push-журнала](implementation-push-test-excerpt.txt) явно являются выдержками;
полные журналы доступны по ссылкам соответствующих jobs в [ведомости](implementation-checks.json).
Локальные и CI-счётчики относятся к разным прогонам.

Actual Linux early-output guard выполнен в обоих текущих core-jobs: exit2
с точным отказом до engine; 351 существующий файл и оригинальный архив неизменны.
Флаги real_engine_invoked, real_x_connection_claimed и synthetic_native_positive
равны false. Это ранний отрицательный сценарий captured CLI93df8ef6,
его QA-входы совпадают с текущими; положительная нативная серия проверена отдельно.
[Точные результаты обоих общих jobs](implementation-core-results.json).

Этот отдельный учёт меняет VLIGHT-010 на done, её результат, доказательства,
генерируемые представления и объяснение в Wiki. Единственный
`Task-Complete: VLIGHT-010` относится к учётному коммиту после принятой реализации.
Другие 1036 visual-карточек, top metadata, planning state/sources, LIGHT-00,
runtime/QA/art и frozen evidence сохраняются. [Ведомость сохранности](preservation.json).
[Фактические функции графа Wiki](route.json) проверяют переход85/93 →86/93,
отсутствие потерянных зависимостей/циклов и открытый VMAP-003.

Учёт требует собственных полного штатного hook, post-bump Wiki, strict-current,
браузера, CI, независимого exact-head ревью и решения Team Lead до слияния.
При подготовке этого документа эти gates учёта ещё не объявляются выполненными.
Следующая карточка не начинается до его полной приёмки.

GPU/аппаратный FPS, Retina, длительная сессия, новые рисунки источников VLIGHT-004…009,
object-local свет, маски крыш, меню VPERF-010, VRELEASE-003 и VMAP-003 остаются открытыми.
Разброс исходных CPU-наблюдений перекрывается: ускорение не доказано.
Локальный GUI Godot для этой реализации не запускался.
