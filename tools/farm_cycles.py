#!/usr/bin/env python3
"""Выгружает кандидаты замкнутых цепочек из фактического каталога FARM."""

import argparse
import json
from pathlib import Path


def components(data):
    """Находит взаимно достижимые материалы, сохраняя внешние затраты каждого рецепта."""
    edges = {}
    transforms = []
    for recipe in data['recipes']:
        transforms.append({'id': recipe.get('id', recipe['output']),
                           'inputs': recipe['inputs'],
                           'outputs': {recipe['output']: recipe['count'],
                                       **recipe.get('byproducts', {})},
                           'station': recipe.get('station', 'workbench'),
                           'seconds': recipe.get('seconds', 0),
                           'energy': recipe.get('energy', 0)})
    for entry in data['research']:
        transforms.append({'id': 'recycle:' + entry['kind'],
                           'inputs': {entry['kind']: entry['batch']},
                           'outputs': entry['parts'], 'energy': entry['tier'] * 2,
                           'station': 'recycling', 'seconds': 0})
    for entry in transforms:
        for source in entry['inputs']:
            edges.setdefault(source, set()).update(entry['outputs'])
        for target in entry['outputs']:
            edges.setdefault(target, set())

    def reach(start):
        """Обходит граф без рекурсии и без изменения исходных каталогов."""
        seen, queue = set(), [start]
        while queue:
            node = queue.pop()
            if node in seen:
                continue
            seen.add(node)
            queue.extend(edges[node] - seen)
        return seen

    reachable = {node: reach(node) for node in edges}
    remaining, result = set(edges), []
    while remaining:
        node = min(remaining)
        group = {other for other in reachable[node] if node in reachable[other]}
        remaining -= group
        if len(group) < 2 and node not in edges[node]:
            continue
        candidates = [entry for entry in transforms
                      if group.intersection(entry['inputs'])
                      and group.intersection(entry['outputs'])]
        result.append({'materials': sorted(group), 'transforms': candidates})
    return result


def main():
    """Записывает кандидатов для балансового разбора, не объявляя каждую связь эксплойтом."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    data = json.loads(args.catalog.read_text())
    groups = components(data)
    free = {'research': [], 'recipes': [recipe for recipe in data['recipes']
            if recipe.get('station', 'workbench') in ('workbench', 'alchemy', 'cauldron')
            and not recipe.get('private_kitchen', False)
            and recipe.get('energy', 0) == 0 and recipe.get('seconds', 0) == 0]}
    args.output.write_text(json.dumps({'scope': 'SCC candidates, not a proof of arbitrary mixtures',
                                      'free_components': components(free),
                                      'components': groups}, ensure_ascii=False, indent=2) + '\n')
    print('FARM CYCLES:', len(groups), 'components')


if __name__ == '__main__':
    main()
