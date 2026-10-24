# VFOLIAGE-006 — общий путь Godot в CI

Приоритетная доработка P1 по [повторному ревью](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/1#pullrequestreview-5623341575). Исходный head — `4ac0975fea99eb2b446cdc21bab1c3f95c167b2b`. [Run 39890933525](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/actions/runs/39890933525), job `120210262155`: architecture останавливался в `slice_audit.export` с `FileNotFoundError: godot`.

Скачанный Godot был доступен только шагам автоматических тестов, smoke и performance через их собственные `env`. Architecture также запускает движок, но до этих шагов не получал путь и пытался найти `godot` в PATH.

`FARM_GODOT_BIN` перенесён в общий `jobs.test.env` с абсолютным путём `${{ github.workspace }}/.ci/Godot_v4.7.1-stable_linux.x86_64`. Убраны три повторения на отдельных шагах. Все четыре проверки наследуют один путь к загруженному исполняемому файлу. Шаг загрузки остаётся перед architecture. Wiki сохраняет отдельный `WIKI_GODOT_BIN`.

Синтаксис YAML и наследование всех четырёх шагов проверены до запуска общего gate. Локальный gate использует явный абсолютный `FARM_GODOT_BIN`, Python 3.11.17 и Pillow 11.3.0. Проверки, пороги, runtime, шейдеры, ресурсы и нативные архивы не менялись; автоматический bump версии — единственное изменение project.godot и metadata приложения.

Фактический локальный результат фиксируется в `completion.json` и логах после полного gate. Результат нового GitHub run и окончательный head публикуются в PR и сообщении Tech Lead Agent после push; локальный успех не подменяет CI. До успешных всех обязательных шагов и одобрения текущего SHA карточка остаётся `in_progress`, слияние в main не разрешено. Точный ноль и читаемость приняты в предыдущем ревью; новой игровой карточки эта доработка не начинает.

Проба в отдельном проекте без `.godot` воспроизвела следующий блокирующий фактор: экспорт вернул 0, но журнал содержит ошибки отсутствующих импортированных текстур. Она отклонена и сохранена в `cold-export.json` / `cold-export-rejected.txt`. Перед architecture добавлен штатный `--headless --editor --path . --quit`, который уже используется run_tests.sh. Свежий CI должен подтвердить импорт и весь последующий gate.
