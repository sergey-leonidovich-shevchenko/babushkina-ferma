# Вторая нативная серия VCOMPAT-010

[CI 45041661293](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/actions/runs/45041661293) успешно проверил exact head `1c0590048f38c8f8448abf48a88bb9a4e314f7f5` / tree `8550a2b4416be44a81e4613aa12f0be9f02f515f`. [Сводка и SHA](summary.json) фиксируют 136 полных PNG: baseline/candidate в окнах 1152×648 и 1280×720, по 34 кадра в каждой серии.

У всех начальных, холодных и twin-владельцев seed 20261015. Полные save/camera/player/location совпадают между вариантами; новый включённый профиль побайтно совпадает по RGBA с принятой базой. Отключение меняет представление, включение возвращает те же пиксели. Прежний интерьер сохраняется, независимые viewport не меняют соседнего владельца. Это проверка обратимости, не приёмка новой графики всей карты, FPS или VMAP-003.

Tech независимо скачал тот же artifact и выполнил `--check-current-candidate`: [source review 6013201866](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/88#pullrequestreview-6013201866), [подтверждение нативной проверки 4658898780](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/88#discussion_r4658898780). Первое P2 закрыто. [Все четыре workflow кандидата завершились успешно](ci-status.json), включая общий quality gate. Это **SOURCE PASS**, не финальное APPROVED отчётного head: его полный hook, post-bump Wiki, CI, независимое ревью и решение Team Lead сохраняются.

## Исходные байты

Artifact `14762117327`, job `137267236311`: 131469076 байт, SHA256 `cb87148e9b49a9d5dca75dc8abd23b8af3a41dc4deabeb91ea667e4b9e2edc1a`. [Три части и их SHA](parts.json) сохраняют исходный ZIP без перепаковки. Сборка выполняется только во временной папке; проверяются пути, порядок, размеры и SHA каждой части и всего архива.

```sh
python3 tools/run.py qa.world.rollback.archive \
  --archive docs/reports/visual-overhaul/vcompat-010/native-ci-02/parts.json \
  --expected-head 1c0590048f38c8f8448abf48a88bb9a4e314f7f5
```

Команда действительно выполнена и приняла все 136 PNG. На чистом коммите отчёта добавить `--check-current-candidate`: он требует тот же runtime и QA, разрешая только согласованный SemVer. Изменение игрового кода или QA-входов требует новой съёмки.

[Восемь отрицательных контролей](reader-controls.json) используют временную распаковку настоящего ZIP. Reader отклонил потерю seed у initial/cold/twin, разные скрытые RNG/контейнеры, отсутствующий PNG, подстановку on вместо off и повреждённый пиксель restore. Изменённые копии получили свои SHA, чтобы проверялась семантика, а не только целостность. Исходный архив сохранил свой SHA. [Журналы, CLI и точный сценарий](logs.zip) включают полный decoded job log; `reproduce-controls.txt` принимает оригинальный ZIP и новый путь JSON-вывода. Контрольные изображения не являются нативными доказательствами игры.

## Осмотр изображений

Просмотрены четыре листа всех 136 кадров: [baseline 1152](inspection-baseline-1152.jpg), [baseline 1280](inspection-baseline-1280.jpg), [candidate 1152](inspection-candidate-1152.jpg), [candidate 1280](inspection-candidate-1280.jpg). Это уменьшенные листы для осмотра; исходные полноразмерные PNG находятся в неизменённом ZIP.

Дополнительно просмотрены исходные пары 1280 px: [дом, новая графика](home-on.png), [дом, запасной профиль](home-off.png), [западный берег, новая графика](west-bank-on.png), [западный берег, запасной профиль](west-bank-off.png). Герой, NPC, содержимое мира и HUD сохраняют свои места; меняются существующие визуальные пути. Старые ресурсы запасного профиля не считаются новым художественным стандартом.

Первый CI1 и его исходный случайный мир остаются failure в соседнем каталоге `failures/ci-01`; успешная вторая серия не переписывает прежние доказательства. Карточка остаётся `in_progress`, merge и Task-Complete пока отсутствуют.
