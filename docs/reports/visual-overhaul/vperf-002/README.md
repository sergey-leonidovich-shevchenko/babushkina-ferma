# VPERF-002 · Бюджет первой деревни

Эталон для разработки — Intel MacBook Pro `MacBookPro16,1` с i7-9750H, 16 ГиБ RAM и Radeon Pro 5300M, macOS 15.4.1, Godot 4.7.1 OpenGL Compatibility. Эта машина уже использовалась в VBASE-002 и нативной серии VPERF-001. Берём питание от сети и выключенный экономичный режим, чтобы сравнения опирались на условия полной принятой серии. Частоту дисплея фиксируем в паспорте будущего прогона. Эталон рассчитан на режим 60 Гц. Минимальные системные требования остаются открытыми. [Аппаратный профиль VBASE-002](../vbase-002/profile.json) · [Бюджет и настройки JSON](budget.json)

## Сцена и условия сравнения

`overworld-entry-1152-ac-v1` использует состояние деревни из точки `overworld-entry-v1` и устанавливает позицию VPERF-001 перед измерением. Окно, корневой viewport и контрольный PNG — по 1152×648 физических пикселей. Логическое игровое поле — 960×540, мир 120%, HUD 100%. Герой стоит в `(600.25, 700.25)`, смещение штатной камеры `(120.25, 430.25)`, допуск меньше 0,001 мировой единицы. Начальное состояние — день 1, 12:00 до прогрева, семя `20261015`, ясная погода. Ввод героя выключен, физика, часы и события мира идут штатно. [Точка VBASE-003](../vbase-003/camera-points.json) · [Нативный паспорт VPERF-001](../vperf-001/native/source.json)

Базовый запуск использует действующую графику, обычный свет, русский HUD, включённый VSync и физику 60 Гц. Дополнительный лимит кадров отключён (`max_fps=0`). Звук и тряска выключены, уменьшение движения включено. Каждый из трёх повторов по 30 секунд и отдельный непрерывный запуск на 600 секунд начинает с нового процесса и изолированного игрового профиля. После 120 idle-вызовов прогрева собираются все интервалы. Наблюдатель откладывает запись и чтение PNG до выхода из измеряемого участка. RSS, CPU, питание и конкурирующие процессы опрашиваются каждые 5 секунд. [Контракт VPERF-001](../vperf-001/README.md)

Во всех повторах серии фиксируются один Git SHA и дерево игрового проекта, хеши измерителя, бинарника и конфигурации, GPU и драйвер, питание, частота, размеры, точка и настройки. При сравнении двух режимов на том же коммите фиксируется единственный задуманный переключатель. Для сравнения двух ревизий повторяются обе серии на одном стенде с тем же измерителем, условиями и камерой. Различия в исходниках перечисляются отдельно. Изменение режима питания, потеря фокуса, сдвиг камеры, пауза, другой размер или обрыв записи делают запуск непригодным для сравнения. Такой запуск сохраняется с причиной, серия повторяется целиком. Валидный медленный прогон остаётся в серии.

Живой маршрут для приёмки пилота использует ориентир VBASE-001 с 16 точками и штатным вводом: от дома через мост к площади и обратно. Перед живым замером VRELEASE-004 повторно сверяет положение, маршрут и камеру на масштабе 120% и том же коммите для сравниваемых режимов. Результаты движения и неподвижной точки публикуются отдельно. Маршрут с переходами и проверка памяти за 30–60 минут относятся к VPERF-009. [Маршрут VBASE-001](../vbase-001/README.md)

## Правило бюджета

Цель 60 кадров в секунду соответствует 1000/60 мс. Для наблюдаемых интервалов `RenderingServer.frame_post_draw` пороги на каждый короткий повтор и весь десятиминутный прогон заданы так:

| Показатель | Предельное значение | Зачем |
| --- | ---: | --- |
| p95 | ≤ 16,7 мс | Основная цель стабильного ритма около 60 Гц |
| p99 | ≤ 25,0 мс | Ограничивает частые заметные провалы |
| Доля интервалов > 33,4 мс | ≤ 0,1% | Ограничивает кадры длиннее примерно двух периодов 60 Гц |
| Максимум | ≤ 50,0 мс | Ловит одиночный рывок, который скрывают перцентили |

Пороги хвоста — инженерное решение для этого эталона. Квантили считаются по всем интервалам одним методом VPERF-001: линейная интерполяция между соседями на позиции `(n − 1) × q`. Порог применяется к неокруглённым значениям. Для каждого прогона сохраняются N, p50/p95/p99/max, число и доля поздних кадров, самый длинный блок таких кадров и их отметки времени в raw-журнале. Длинный прогон показывает распределение целиком и по минутам. Медиана и худший p95 трёх повторов сообщаются рядом. Любое превышение в любом из четырёх валидных прогонов означает невыполнение бюджета.

Idle-интервалы, render-интервалы, CPU процесса и мониторы кадра Godot публикуются раздельно. Внешний CPU показывает нагрузку на ядра, время GPU остаётся `null`, пока отдельный поддержанный таймер его не измерит. RSS, static и texture bytes отражают разные виды памяти. Draw calls помогают объяснить изменения нагрузки. Граница `frame_post_draw` измеряет ритм отрисовки. Физический показ кадра на дисплее и аппаратные 60 FPS требуют отдельного измерения. [Определения и ограничения VPERF-001](../vperf-001/README.md#что-именно-измеряется)

## Проверка порогов на исходных записях

Ниже повторно рассчитаны значения исходной нативной серии VPERF-001 на Git-базе `7056f24d949477d01aefd2c42b7640acf7794f09` с семью заархивированными входами и конфигурацией 0.0.276. Все четыре файла `render-rows.csv.gz` прочитаны целиком, и статистика совпала с принятой сводкой. Историческая серия показывает масштаб тогдашней проблемы. У неё нет отдельного показания частоты дисплея, а дерево текущего проекта отличается. [Сырые записи и хеши](../vperf-001/native/source.json) · [Принятая сводка](../vperf-001/summary.json) · [Повторный расчёт и хеши JSON](historical-replay.json)

| Прогон | Интервалы | p50 / p95 / p99 / max, мс | > 33,4 мс | Доля | Самая длинная серия |
| --- | ---: | --- | ---: | ---: | ---: |
| Повтор 1 | 690 | 36,760 / 81,453 / 123,059 / 155,503 | 504 | 73,04% | 52 |
| Повтор 2 | 801 | 35,122 / 56,306 / 68,844 / 75,199 | 498 | 62,17% | 51 |
| Повтор 3 | 793 | 35,088 / 52,072 / 57,171 / 67,997 | 552 | 69,61% | 31 |
| Длинный цикл | 16514 | 34,471 / 51,737 / 66,264 / 119,547 | 10400 | 62,98% | 67 |

Медиана трёх коротких p95 — 56,306 мс. Эта серия подтверждает, что правила отсекают наблюдавшиеся рывки. VPERF-002 фиксирует целевой бюджет. Выполнение бюджета текущим билдом, GPU-время, релизный минимум и стоимость живого пилота остаются отдельными открытыми проверками.

Из корня проекта с Python и зависимостями штатного QA можно заново проверить
исходную серию и рассчитать опубликованные пороги. Первая команда сверяет весь
архив по штатной проверке. Вторая берёт список прогонов из VPERF-001,
сверяет SHA256 каждого CSV и пересчитывает итог по трём коротким повторам.
Для отрицательного контроля замените путь `historical-replay.json` в команде путём к копии.

```sh
python3 tools/run.py qa.performance.perf_contract
python3 - docs/reports/visual-overhaul/vperf-002/historical-replay.json <<'PY'
import hashlib
import json
import sys
from itertools import groupby
from pathlib import Path
from statistics import median
from tools.qa.performance.perf_contract import SCHEDULE, distribution, require, rows

root = Path('docs/reports/visual-overhaul')
native = root / 'vperf-001/native'
manifest_path = native / 'source.json'
manifest = json.loads(manifest_path.read_bytes())
budget = json.loads((root / 'vperf-002/budget.json').read_text())['budget']['limits_in_each_run']
replay = json.loads(Path(sys.argv[1]).read_text())
require(manifest['schedule'] == SCHEDULE, 'unexpected VPERF-001 schedule')
require(replay['base_commit'] == manifest['base_commit'], 'recorded base differs')
require(replay['source_manifest_sha256'] == hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        'recorded source manifest hash differs')
require(set(replay['runs']) == {run for run, _, _ in SCHEDULE}, 'recorded run set differs')

short_p95 = []
for run, seconds, _ in SCHEDULE:
    expected = replay['runs'][run]
    member = f'{run}/render-rows.csv.gz'
    path = native / member
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    require(digest == manifest['artifacts'][member], f'{run}: source CSV hash differs')
    require(digest == expected['render_csv_sha256'], f'{run}: recorded CSV hash differs')
    fields = ['usec', 'interval_ms', 'render_frame', 'process_frame']
    values = [row['interval_ms'] for row in rows(path, fields)]
    stats = distribution(values)
    late = [value > budget['late_interval_ms_exclusive'] for value in values]
    fraction = sum(late) / len(late)
    streak = max((sum(group) for is_late, group in groupby(late) if is_late), default=0)
    checks = {
        'p95': stats['p95'] <= budget['p95_ms_inclusive'],
        'p99': stats['p99'] <= budget['p99_ms_inclusive'],
        'late_fraction': fraction <= budget['late_fraction_inclusive'],
        'max': stats['max'] <= budget['max_ms_inclusive'],
    }
    require(len(values) == expected['render_intervals'], f'{run}: interval count differs')
    require(stats == expected['render_interval_ms'], f'{run}: distribution differs')
    require((sum(late), fraction, streak) ==
            (expected['late_count'], expected['late_fraction'], expected['longest_late_streak']),
            f'{run}: late intervals differ')
    require(checks == expected['historical_threshold_results'] and
            all(checks.values()) == expected['historical_thresholds_met'],
            f'{run}: threshold decisions differ')
    if seconds == 30:
        short_p95.append(stats['p95'])
    print(run, len(values), stats['p95'], checks)

require(len(short_p95) == 3, 'expected three independent short repeats')
require(median(short_p95) == replay['short_p95_median_ms'], 'short p95 median differs')
require(max(short_p95) == replay['short_p95_worst_ms'], 'short p95 worst differs')
print('short p95 median/worst:', median(short_p95), max(short_p95))
PY
```
