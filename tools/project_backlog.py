#!/usr/bin/env python3
"""Офлайн-проверка и читаемое представление плана разработки в репозитории."""

import argparse
from collections import Counter
import json
from pathlib import Path
import re

from common.paths import project_root

ROOT = project_root(__file__)
FOLDER = ROOT / 'docs/backlog/2026-10'
REPOSITORY = 'sergey-leonidovich-shevchenko/babushkina-ferma'
STATES = ('backlog', 'ready', 'blocked', 'in_progress', 'done')


def load_plan(folder=FOLDER):
    """Читает локальный план без сети и доступа к учётным данным."""
    return json.loads((folder / 'backlog.json').read_text(encoding='utf-8'))


def topological_tasks(plan):
    """Упорядочивает задачи от оснований к зависимым и обнаруживает циклы."""
    pending = {task['id']: task for task in plan['tasks']}
    ordered = []
    while pending:
        available = [task for task in pending.values()
                     if all(dep not in pending for dep in task['dependencies'])]
        if not available:
            raise ValueError('Цикл зависимостей')
        for task in available:
            ordered.append(task)
            del pending[task['id']]
    return ordered


def branch_name(task):
    """Привязывает ветку к ID задачи из файла, без искусственного номера issue."""
    return 'codex/' + task['id'].lower() + '-' + task['branch_slug']


def validate(plan, root=ROOT):
    """Проверяет границы исходного плана, файлы, связи и подтверждения статусов."""
    if plan.get('schema') != 1 or plan.get('repository') != REPOSITORY:
        raise ValueError('Неподдерживаемая схема или другой репозиторий')
    if plan.get('repository_mode') != 'local-files':
        raise ValueError('План ведётся в файлах')
    if len(plan['epics']) != 6 or len(plan['tasks']) != 50:
        raise ValueError('Ожидаются 6 эпиков и 50 задач исходного плана')
    all_ids = [e['id'] for e in plan['epics']] + [t['id'] for t in plan['tasks']]
    if len(set(all_ids)) != len(all_ids):
        raise ValueError('Повтор идентификатора')
    tasks = {t['id']: t for t in plan['tasks']}
    epics = {e['id']: e for e in plan['epics']}
    sources = {s['id'] for s in plan['sources']}
    milestones = {m['id'] for m in plan['milestones']}
    if len(sources) != len(plan['sources']) or len(milestones) != 3:
        raise ValueError('Повтор источника или неверные этапы')
    if not re.fullmatch(r'[a-f0-9]{40}', plan['baseline_commit']):
        raise ValueError('Нужен точный исходный commit')
    for source in plan['sources']:
        if not source['url'].startswith('https://'):
            raise ValueError('Источник должен иметь HTTPS-ссылку')
    for task in tasks.values():
        if not re.fullmatch(r'[A-Z]+-\d{2}', task['id']):
            raise ValueError('Неверный ID задачи')
        if task['epic'] not in epics or task['milestone'] not in milestones:
            raise ValueError('Неизвестный эпик или этап: ' + task['id'])
        if task['priority'] not in ('P1', 'P2', 'P3') or task['size'] not in ('S', 'M', 'L'):
            raise ValueError('Неверный приоритет или размер')
        if not re.fullmatch(r'[a-z][a-z0-9]*(?:-[a-z0-9]+)*', task['branch_slug']):
            raise ValueError('Неверное имя ветки: ' + task['id'])
        if len(task['acceptance']) < 3 or not task['scope'] or not task['verification']:
            raise ValueError('Нет проверяемого результата: ' + task['id'])
        if not set(task['sources']).issubset(sources):
            raise ValueError('Неизвестный источник')
        deps = task['dependencies']
        if len(set(deps)) != len(deps) or any(d not in tasks or d == task['id'] for d in deps):
            raise ValueError('Неизвестная, повторная или собственная зависимость')
        if task['status'] not in STATES:
            raise ValueError('Неизвестный статус')
        if task['status'] in ('ready', 'in_progress', 'done'):
            if task['needs'] or any(tasks[d]['status'] != 'done' for d in deps):
                raise ValueError('Готовая задача содержит блокирующие условия')
        if task['status'] == 'done' and not task['result'].strip():
            raise ValueError('Завершение требует подтверждения результата')
        for filename in task['files']:
            path = (root / filename).resolve()
            if not path.is_relative_to(root.resolve()) or not path.exists():
                raise ValueError('Нет локального файла: ' + filename)
    counts = Counter(t['epic'] for t in tasks.values())
    if any(counts[e['id']] != e['expected_tasks'] for e in epics.values()):
        raise ValueError('Не совпало распределение задач')
    if sum(t['status'] == 'in_progress' for t in tasks.values()) > 1:
        raise ValueError('Одновременно в работе больше одной задачи')
    if not {f'OPT-{i:02}' for i in range(1, 14)}.issubset(tasks):
        raise ValueError('Потеряны прежние OPT-01…13')
    topological_tasks(plan)


def bullets(items, checkboxes=False):
    """Форматирует параллельные пункты без изменения их содержания."""
    return '\n'.join(('- [ ] ' if checkboxes else '- ') + item for item in items)


def task_link(identifier):
    """Ссылается на устойчивый якорь внутри читаемого плана."""
    return f'[{identifier}](#{identifier.lower()})'


def render(plan):
    """Собирает полные карточки и обзор из единственного изменяемого источника."""
    source_map = {s['id']: s for s in plan['sources']}
    counts = Counter(t['status'] for t in plan['tasks'])
    sections = ['# План разработки: 6 эпиков и 50 задач',
        'План от 15 октября 2026. Ведём в файлах репозитория. Это очередь без сроков и автоматического запуска; ' +
        'реализация и подтверждения отмечены в карточках. Исходный commit: `' + plan['baseline_commit'] + '`.',
        '[Исследование и первичные источники](RESEARCH.md) · [Рабочий процесс](../../BACKLOG_WORKFLOW.md) · ' +
        '[Редактируемый источник](backlog.json) · [Дополнительные эпики](../README.md). ' +
        'Этот Markdown создаётся командой `python3 tools/project_backlog.py --write`.',
        '## Состояние\n\n' + ', '.join(f'`{state}`: {counts[state]}' for state in STATES) +
        '. Статус `done` требует записанного результата; исходные критерии и наличие тестов не означают выполнения.',
        '## Эпики\n\n| ID | Направление | Задач |\n|---|---|---:|\n' +
        '\n'.join(f"| [{e['id']}](#{e['id'].lower()}) | {e['title']} | {e['expected_tasks']} |" for e in plan['epics']),
        '## Порядок\n\nНачать с OPT-01: закрепить честный замер до следующего изменения производительности. ' +
        'Далее SAFE-05/SAFE-03 и QA-01; следующие пункты выбираем по дефектам и данным. Одна задача в работе. ' +
        'S/M/L — относительный объём, не срок; L можно разбить до начала.\n\n' +
        bullets(task_link(t['id']) + ' — ' + t['title'] for t in plan['tasks'] if t['status'] == 'ready'),
        '## Этапы без дат\n\n' + bullets(m['title'] + ': ' + m['description'] for m in plan['milestones']),
        '## Ограничения\n\nСохраняем светлый пергамент, компактный HUD без миникарты/цифровых часов, ' +
        'паузу рюкзака и отсутствие тряски экрана. Макеты отдельно → выбор пользователя → игровые ресурсы. ' +
        'Мировые предметы смотрят влево/вправо/вниз; направления персонажей имеют свой контракт.\n\n' +
        'Сохранены 13 прежних OPT и 320 **запланированных**, а не пройденных сценариев. Последние оптимизации учтены. ' +
        '30 мин/2 ч, неподтверждённые устройства и художественный выбор остаются открытыми. ' +
        'TD-ART-017 остаётся отдельной партией в реестре долга; не расширяет текущие ограниченные арт-задачи.']
    for epic in plan['epics']:
        sections += [f'<a id="{epic["id"].lower()}"></a>\n\n## {epic["id"]} — {epic["title"]}', epic['goal']]
        for task in (t for t in plan['tasks'] if t['epic'] == epic['id']):
            sections += [f'<a id="{task["id"].lower()}"></a>\n\n### {task["id"]} — {task["title"]}',
                f"**{task['status']} · {task['priority']} · {task['size']} · {task['kind']}**. Ветка: `{branch_name(task)}`.",
                '**Сейчас:** ' + task['baseline'], '**Результат:** ' + task['outcome'],
                '**Объём:**\n\n' + bullets(task['scope']),
                '**Приёмка:**\n\n' + bullets(task['acceptance'], True),
                '**Проверка:**\n\n' + bullets(task['verification']),
                '**Зависимости:** ' + (', '.join(task_link(d) for d in task['dependencies']) or 'нет') + '.']
            if task['needs']:
                sections.append('**Условия:** ' + ', '.join(task['needs']) + '. Выбор дизайна/физический доступ нельзя считать полученным без подтверждения.')
            if task['kind'] in ('investigation', 'validation'):
                sections.append('Гипотеза может не подтвердиться: достаточны воспроизводимые данные и вывод; переписывание кода не обязательно.')
            if task['legacy']:
                sections.append('**Прежние ID:** ' + ', '.join(task['legacy']) + '.')
            sections += ['**Файлы:** ' + ', '.join(f'[{p}](../../../{p})' for p in task['files']) + '.',
                '**Основания:** ' + ', '.join(f"[{s}]({source_map[s]['url']})" for s in task['sources']) + '.',
                '**Подтверждение результата:** ' + (task['result'] or 'пока нет; задача открыта.')]
    return '\n\n'.join(sections) + '\n'


def main():
    """Проверяет план или явно обновляет его читаемую версию без сетевых действий."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='Обновить читаемый README из JSON')
    args = parser.parse_args()
    plan = load_plan()
    validate(plan)
    output = render(plan)
    target = FOLDER / 'README.md'
    if args.write:
        target.write_text(output, encoding='utf-8')
    elif target.read_text(encoding='utf-8') != output:
        raise ValueError('README устарел: python3 tools/project_backlog.py --write')
    print(f"BACKLOG OK: {len(plan['epics'])} epics / {len(plan['tasks'])} tasks / " +
          f"{sum(t['status'] == 'ready' for t in plan['tasks'])} Ready; network: 0")


if __name__ == '__main__':
    main()
