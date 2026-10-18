#!/usr/bin/env python3
"""Проверяет предметный план CAMP и строит читаемые карточки без смены статусов."""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAN_DIR = ROOT / 'docs/epics/camp-2026-10'
STATUSES = {'backlog', 'ready', 'blocked', 'in_progress', 'done'}
STATIONS = {'field': 'в руках', 'workbench': 'верстак', 'candlebench': 'свечной стол'}
KINDS = {'new': 'новый предмет', 'existing': 'существующий предмет', 'module': 'сменный модуль', 'upgrade': 'улучшение экземпляра'}


def plain_effect(effect):
    """Читает реальный порядок HP/энергии/маны, не превращая временные баффы в лечение."""
    values = {'hp': 0, 'energy': 0, 'mana': 0}
    if effect and effect[0] in {'item_effect_heal', 'item_effect_heal_energy', 'item_effect_heal_mana'}:
        values['hp'] = effect[1]
        if effect[0] == 'item_effect_heal_energy':
            values['energy'] = effect[2]
        elif effect[0] == 'item_effect_heal_mana':
            values['mana'] = effect[2]
    return values


def read_plan(directory=PLAN_DIR):
    """Читает единственный источник карточек, не обращаясь к игре или сети."""
    return json.loads((directory / 'backlog.json').read_text())


def validate(data, external, snapshot):
    """Отклоняет потерю предметов, ложную готовность, неизвестные материалы и циклы."""
    errors = []
    def need(condition, message):
        if not condition:
            errors.append(message)
    tasks = data['tasks']
    by_id = {t['id']: t for t in tasks}
    by_item = {t['item']: t for t in tasks}
    expected = {f'CAMP-{n:03}' for n in range(1, 101)}
    need(data['task_count'] == len(tasks) == 100, 'CAMP requires exactly 100 item tasks')
    need(snapshot['item_count'] == len(snapshot['items']), 'catalog snapshot count mismatch')
    need(set(by_id) == expected and len(by_id) == len(tasks), 'missing/duplicate task ID')
    need(len(by_item) == len(tasks), 'duplicate item output')
    need(len({t['title'] for t in tasks}) == len(tasks), 'duplicate item title')
    groups = {g['id'] for g in data['groups']}
    need(len(groups) == len(data['groups']) == 10, 'requires 10 unique groups')
    for group in groups:
        need(sum(t['group'] == group for t in tasks) == 10, 'group must contain 10 items: '+group)
    declared_external = set(data['external_dependencies'])
    need(declared_external <= set(external), 'unknown external owner')
    materials = data['materials']
    for key, value in materials.items():
        need(bool(value.get('title')) and bool(value.get('source')), 'material needs source: '+key)
        need(value['state'] in {'existing', 'planned'}, 'unknown material state: '+key)
        if value['state'] == 'existing':
            need(key in snapshot['items'], 'material absent from audited catalog: '+key)
        else:
            need(value.get('depends_on') in declared_external, 'planned material needs owner: '+key)
    for key, gate in data['gates'].items():
        need(gate['owner'] in by_id, 'gate owner missing: '+key)
        need(gate['status'] in STATUSES, 'gate status invalid: '+key)
        need(bool(gate.get('contract')), 'gate contract missing: '+key)
        if gate['owner'] in by_id:
            need(key in by_id[gate['owner']]['gates'], 'owner does not carry gate: '+key)
            if gate['status'] == 'done':
                need(by_id[gate['owner']]['status'] == 'done', 'gate done before owner: '+key)
    blueprints = []
    for task in tasks:
        key = task['id']
        def task_need(condition, message):
            need(condition, key+': '+message)
        task_need(task['group'] in groups, 'unknown group')
        task_need(task['kind'] in KINDS, 'unknown item kind')
        task_need(task['status'] in STATUSES, 'invalid status')
        task_need(task['priority'] in {'P0','P1','P2','P3'}, 'invalid priority')
        task_need(task['size'] in {'S','M','L'}, 'invalid size')
        task_need(bool(task['use']) and len(task['acceptance']) >= 2 and all(task['acceptance']), 'needs purpose and concrete acceptance')
        task_need((task['item'] in snapshot['items']) == (task['kind'] == 'existing'), 'existing/new item classification conflicts with audit')
        task_need(bool(re.fullmatch(r'[a-z][a-z0-9_]*', task['item'])), 'invalid item key')
        recipe = task['craft']
        task_need(recipe['station'] in STATIONS, 'unknown crafting station')
        task_need(type(recipe['count']) is int and recipe['count'] > 0, 'invalid output count')
        task_need(bool(recipe['inputs']), 'recipe without inputs')
        dependencies = set(task['depends_on'])
        task_need(len(dependencies) == len(task['depends_on']), 'duplicate dependencies')
        task_need(dependencies <= set(by_id) | declared_external, 'unknown dependency')
        task_need(key not in dependencies, 'self dependency')
        for material, count in recipe['inputs'].items():
            task_need(type(count) is int and count > 0, 'invalid ingredient quantity')
            task_need(material in materials or material in by_item, 'unknown material: '+material)
            if material in by_item and by_item[material]['id'] != key:
                task_need(by_item[material]['id'] in dependencies, 'missing item producer: '+material)
            if material in materials and materials[material]['state'] == 'planned':
                task_need(materials[material]['depends_on'] in dependencies, 'planned material without dependency: '+material)
        if 'prototype_effect' in task:
            effect = task['prototype_effect']
            task_need(set(effect) == {'hp','energy','mana'}, 'unknown effect stat')
            for stat, amount in effect.items():
                if stat not in {'hp','energy','mana'}:
                    continue
                task_need(type(amount) is int and amount >= 0, 'invalid effect amount')
                budget = sum(plain_effect(snapshot['food_effects'].get(material, []))[stat]*count for material, count in recipe['inputs'].items())
                task_need(amount*recipe['count'] <= budget, 'food batch exceeds ingredient effect budget: '+stat)
            if task['kind'] == 'existing':
                task_need(effect == plain_effect(snapshot['food_effects'].get(task['item'], [])), 'changed existing food effect')
        for gate in task['gates']:
            task_need(gate in data['gates'], 'unknown gate: '+gate)
            if gate in data['gates']:
                owner = data['gates'][gate]['owner']
                task_need(owner == key or owner in dependencies, 'missing common owner: '+gate)
        task_need(recipe['station'] != 'field' or 'field' in task['gates'], 'field recipe without common field system')
        unlock = task['unlock']
        task_need(unlock['kind'] in {'known','lesson','blueprint'} and bool(unlock.get('source')), 'invalid unlock/source')
        if unlock['kind'] == 'blueprint':
            blueprints.append(unlock.get('id'))
            task_need(unlock.get('id') == 'bp_camp_'+task['item'], 'unstable blueprint ID')
            task_need(bool(unlock.get('fallback')) and 'blueprints' in task['gates'], 'blueprint needs guaranteed fallback and common owner')
        if unlock['kind'] == 'lesson':
            task_need(bool(unlock.get('fallback')), 'lesson needs recovery')
        if task['status'] in {'ready','in_progress','done'}:
            for dep in dependencies:
                parent = by_id.get(dep, external.get(dep, {}))
                task_need(parent.get('status') == 'done', 'unaccepted blocker: '+dep)
            for gate in task['gates']:
                if gate in data['gates'] and data['gates'][gate]['owner'] != key:
                    task_need(data['gates'][gate]['status'] == 'done', 'unaccepted common gate: '+gate)
        if task['status'] == 'done':
            for gate in task['gates']:
                task_need(data['gates'].get(gate, {}).get('status') == 'done', 'done before common contract acceptance: '+gate)
            task_need(bool(task['evidence']) and bool(task['result']), 'done needs acceptance evidence/result')
    need(len(set(blueprints)) == len(blueprints), 'duplicate blueprint ID')
    need(sum(t['status'] == 'in_progress' for t in tasks) <= 1, 'WIP exceeds one')
    if data['status'] == 'done':
        need(all(t['status'] == 'done' for t in tasks), 'epic done before children')
    # Общий граф учитывает обратные ссылки VIS, чтобы межплановый цикл не прятался за реестром.
    graph = {**external, **by_id}
    visiting, visited = set(), set()
    def walk(key):
        if key in visiting:
            errors.append('dependency cycle at '+key)
            return
        if key in visited or key not in graph:
            return
        visiting.add(key)
        for dep in graph[key].get('depends_on', []):
            walk(dep)
        visiting.remove(key)
        visited.add(key)
    for key in by_id:
        walk(key)
    return errors


def task_link(task, nested=False):
    """Связывает индекс и соседние карточки устойчивыми якорями."""
    prefix = '' if nested else 'groups/'
    return f"[{task['id']}]({prefix}{task['group']}.md#{task['id'].lower()})"


def dependency_link(key, data, nested=False):
    """Ведёт к единственному владельцу общей механики, в том числе в VIS."""
    tasks = {t['id']: t for t in data['tasks']}
    if key in tasks:
        return task_link(tasks[key], nested)
    prefix = '../../' if nested else '../'
    epic = key.rsplit('-', 1)[0].lower()
    return f'[{key}]({prefix}visual-overhaul-2026-10/epics/{epic}.md#{key.lower()})'


def recipe_text(task, data):
    """Показывает русские имена и точные количества, сохраняя машинные ID в карточке."""
    titles = {key: value['title'] for key, value in data['materials'].items()}
    titles.update({t['item']: t['title'] for t in data['tasks']})
    return ' + '.join(f'{titles[key]} ×{count}' for key, count in task['craft']['inputs'].items())+f" → ×{task['craft']['count']}"


def documents(data):
    """Строит только представления; исходные статусы, доказательства и рецепты не меняет."""
    tasks = data['tasks']
    lines = ['# CAMP — указатель 100 предметных задач', '',
        'Источник — [backlog.json](backlog.json); правила, границы и общая приёмка — [README](README.md).', '',
        'Рецепты и числовые эффекты — прототипы для баланса. Все карточки открыты до собственной приёмки; наличие карточки не означает наличие предмета в игре.', '']
    for group in data['groups']:
        lines += [f"## {group['title']}", '', '| ID | Предмет | Изготовление | Приоритет / объём | Статус |', '|---|---|---|---|---|']
        for task in tasks:
            if task['group'] == group['id']:
                lines.append(f"| {task_link(task)} | {task['title']} | {STATIONS[task['craft']['station']]} | {task['priority']} / {task['size']} | {task['status']} |")
        lines.append('')
    result = {'TASKS.md': '\n'.join(lines)}
    for group in data['groups']:
        lines = [f"# CAMP — {group['title']}", '', '[Все 100 задач](../TASKS.md) · [Общий контракт и приёмка](../README.md) · [Источник](../backlog.json)', '']
        for task in tasks:
            if task['group'] != group['id']:
                continue
            key = task['id']
            lines += [f'<a id="{key.lower()}"></a>', '', f"## {key} — {task['title']}", '',
                f"**Статус:** {task['status']} · **Приоритет:** {task['priority']} · **Объём:** {task['size']} · **Тип:** {KINDS[task['kind']]}", '',
                f"**Ключ предмета/уровня:** `{task['item']}`. **Ветка:** `codex/{key.lower()}-{task['item'].replace('_','-')}`.", '',
                '**Для игрока:** '+task['use'], '',
                f"**Изготовление:** {STATIONS[task['craft']['station']]}. **Черновой рецепт:** {recipe_text(task, data)}.", '']
            if task.get('prototype_effect'):
                labels = {'hp':'HP','energy':'энергия','mana':'мана'}
                effect = ', '.join(f'{labels[stat]} +{value}' for stat, value in task['prototype_effect'].items() if value)
                lines += ['**Черновой эффект одной порции:** '+effect+'.', '']
            unlock = task['unlock']
            label = {'known':'базовое знание', 'lesson':'обучение', 'blueprint':'найденный чертёж'}[unlock['kind']]
            lines += [f"**Открытие — {label}:** {unlock['source']}"]
            if unlock.get('id'):
                lines.append(f"**ID чертежа:** `{unlock['id']}`.")
            if unlock.get('fallback'):
                lines.append('**Страховка получения:** '+unlock['fallback'])
            lines += ['', '**Зависимости:** '+(', '.join(dependency_link(dep, data, True) for dep in task['depends_on']) or '—')+'.', '',
                '**Общие системы:** '+', '.join(f"[{data['gates'][g]['title']}](../README.md#{g})" for g in task['gates'])+'.', '',
                '**Приёмка предмета** (вместе с [общей приёмкой](../README.md#acceptance)):', '']
            lines += ['- '+value for value in task['acceptance']]
            lines += ['', '**Подтверждения:** '+('; '.join(task['evidence']) or 'пока отсутствуют; реализация открыта')+'.', '',
                '**Результат:** '+(task['result'] or 'не принят; статус меняется вручную после реализации и проверок')+'.', '']
        result['groups/'+group['id']+'.md'] = '\n'.join(lines)
    return result


def main():
    """Проверяет исходник и синхронность; запись требует явного флага и не трогает JSON."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    data = read_plan()
    external_data = json.loads((ROOT / 'docs/epics/visual-overhaul-2026-10/backlog.json').read_text())
    external = {task['id']: task for task in external_data['tasks']}
    snapshot = json.loads((PLAN_DIR / 'catalog-snapshot.json').read_text())
    errors = validate(data, external, snapshot)
    if not errors:
        for relative, content in documents(data).items():
            path = PLAN_DIR / relative
            if args.write:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            elif not path.exists() or path.read_text() != content:
                errors.append('stale document: '+relative)
    if errors:
        raise SystemExit('\n'.join(errors))
    field = sum(t['craft']['station'] == 'field' for t in data['tasks'])
    print(f'CAMP: 100 item tasks, {field} field recipes, graph and documents valid; runtime acceptance not claimed')


if __name__ == '__main__':
    main()
