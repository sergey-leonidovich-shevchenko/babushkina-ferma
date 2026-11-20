# Сверка счётчиков callbacks

Замечание P2 [ревью 5986554924](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/78#pullrequestreview-5986554924) относится к учётному JSON на head `5d67e5ca5c1138583df25f3b240d72e187379d4e`: поле `observed_twin_callbacks` ошибочно содержало общий итог 132. Исходный принятый отчёт уже разделял 108 обычных и 24 twin callbacks.

[Один и тот же сценарий](reproduce.py.txt) заново читает настоящие массивы `draws` в шести `capture.json` из `native/1152.zip` и `native/1280.zip`, сверяет их SHA с исходным manifest и проверяет сохранность ZIP до/после. Числа выводятся из данных: 54 world-случая дали 108 callbacks; 12 twin-состояний — 24; общий итог — 132. JSON теперь имеет три однозначных поля: `observed_world_case_callbacks`, `observed_twin_callbacks`, `observed_callbacks_total`.

```sh
python3 docs/reports/visual-overhaul/vlight-001/closeout/review-counts/reproduce.py.txt --root "$PWD" --revision 5d67e5ca5c1138583df25f3b240d72e187379d4e
# exit 1: прежняя неверная twin-подпись и отсутствие явных world/total полей
python3 docs/reports/visual-overhaul/vlight-001/closeout/review-counts/reproduce.py.txt --root "$PWD"
# exit 0: исправленные поля соответствуют реальному архиву
```

[Старый результат](before.txt), [исправленный](after.txt) и [receipt](receipt.json) сохраняют тот же SHA сценария, шесть источников и оба ZIP. Это адресная проверка семантики учётных чисел, не новая игровая/визуальная/FPS-приёмка. Native, production и 14 producer inputs не меняются. Обязательные полный hook, Wiki, браузер нового JSON-вложения, CI и повторное независимое ревью относятся к новому head и не заменяются проверками `5d67e5c`.
