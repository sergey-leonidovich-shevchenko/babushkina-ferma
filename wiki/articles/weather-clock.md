# Погода и игровая пауза

VWEATHER-001 принята в PR №84 и влита 22 ноября 2026 года после независимого ревью и решения Team Lead. Дождь, снег и вспышка грозы используют разрешённое время после движения героя; пауза сохраняет их положение, а переход и загрузка сбрасывают фазу прежнего визита.

[Принятый PR №84](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/84): окончательный head `2b490b3e` версии 0.0.479 получил [независимое APPROVED](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/84#pullrequestreview-6008790041) и все 11 успешных CI. Полный локальный hook: 53 759 игровых проверок, обе серии перерисовки по 90 кадров, 127 архитектурных групп; Wiki — 167 тестов. В обоих общих CI отдельно прошли 53 777 игровых проверок. [Запись приёмки](../../docs/reports/visual-overhaul/vweather-001/closeout/result.json) различает эти проверки и отдельный учётный PR.

[Съёмка `8689c111`](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/actions/runs/44948199161) сохранила 160 PNG в четырёх сериях. Строгая проверка чистого окончательного head подтвердила прежние runtime/QA-байты с единственным исключением для версии проекта; новый native CI самого `2b490b3e` также успешен. [Матрица кадров и SHA архива](../../docs/reports/visual-overhaul/vweather-001/native-ci-02/summary.json) · [Локальные проверки снятого head](../../docs/reports/visual-overhaul/vweather-001/native-ci-02/local-gates.json) · [Неизменный исходный ZIP в Git](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/blob/2c96121133c48d52ececd61bffc023ac2b6eea0a/docs/reports/visual-overhaul/vweather-001/native-ci-02/artifact.zip).

[Карточка VWEATHER-001](#/development/tasks/visual--VWEATHER-001) · [Исходный план в GitHub](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/blob/e3935bc9a3a1ceda8ac810a9705b31909065cc92/docs/reports/visual-overhaul/vweather-001/PLAN.md) · [Порядок визуального кадра](post-motion-frame.md) · [Первый живописный участок](visual-pilot.md).

## Что проверяем

Во время ручной паузы осадки должны сохранять своё положение. Возвращение в игру добавляет только текущий разрешённый шаг, без скачка за время открытого меню. Та же граница действует для инвентаря, потери фокуса, редактора и режима уменьшения движения. В reduced motion гроза сохраняет дождь без вспышек.

Локальная фаза принадлежит одному игровому миру и его viewport. Вход в дом, возврат и загрузка завершают предыдущий визит; его частицы не должны оживать после перехода. Временное состояние не попадает в игровой слот и не меняет прогноз, календарь, дождевой полив или рост культур.

## Одна камера до и после

Принятая база, дождь, окно 1152×648:

![Исходная версия первой локации в дождь](../../docs/reports/visual-overhaul/vweather-001/native-ci-02/baseline-rain-full.png)

Кандидат при той же камере и игровом снимке:

![Кандидат с согласованными часами дождя](../../docs/reports/visual-overhaul/vweather-001/native-ci-02/candidate-rain-full.png)

Это исходные кадры CI. Для проверки паузы тот же renderer отдельно рисует только погоду: соседняя анимация листвы не влияет на сравнение. В обоих окнах 1152×648 и 1280×720 дождь, снег и гроза исходной версии смещаются на паузе. В кандидате все шесть пар RGBA совпадают: фаза 0.04 → 0.04, после возобновления 0.06, после входа и возврата 0. Камера сохраняет 120% на улице и 100% в доме; два настоящих viewport имеют независимое время.

База: первый кадр на паузе.

![База: первый кадр дождя на паузе](../../docs/reports/visual-overhaul/vweather-001/native-ci-02/baseline-rain-pause-a.png)

База: после реального ожидания; капли сместились.

![База: дождь продолжает двигаться во время паузы](../../docs/reports/visual-overhaul/vweather-001/native-ci-02/baseline-rain-pause-b.png)

Кандидат: первый кадр на паузе, фаза 0.04.

![Кандидат: дождь на паузе до ожидания](../../docs/reports/visual-overhaul/vweather-001/native-ci-02/candidate-rain-pause-a.png)

Кандидат: после ожидания, та же фаза 0.04 и те же RGBA.

![Кандидат: дождь сохраняет положение после ожидания](../../docs/reports/visual-overhaul/vweather-001/native-ci-02/candidate-rain-pause-b.png)

## Подтверждения и ограничения

Первый CI отклонил правильные 100% внутри дома из-за ошибочного требования reader. [Исходный отказ](../../docs/reports/visual-overhaul/vweather-001/failures/ci-01.json) и его архив сохранены; тот же настоящий набор воспроизводит old CLI exit1 → corrected CLI exit0. Все 14 регрессий на копиях реальных данных прошли. Первый CI остаётся failure; успешный второй CI не переписывает его историю.

Число модельных шагов часов не заменяет длительный аппаратный прогон. X11/llvmpipe не принимает Retina, GPU/FPS или VMAP-003. Новый рисунок дождя, маски крыш и снежный покров остаются за следующими VWEATHER-карточками. В изолированном слое после настоящего входа в дом всё ещё виден дождь; маска VWEATHER-003 остаётся открытой.
