"""Проверка исходных водных трасс; квантили общие с эпиком OPT."""

if not __package__:
    from tools.common.launch import prepare_imports
    from tools.common.paths import project_root
    prepare_imports(project_root(__file__))

import json

from tools.qa.performance.analyze_optimization_audit import statistics

from tools.common.paths import project_root

FOLDER = project_root(__file__) / 'docs/reports/water-2026-10'
LOCATIONS = {'overworld', 'village_river', 'cave_lake', 'moon_glade', 'pirate_ship'}


def analyze(report, expected_pixels, locations=LOCATIONS):
    """Отклоняет подмену разрешения, потерю фокуса, усечённые и недостоверные данные."""
    if report.get('pause_on_focus_loss', False) is not False:
        raise ValueError('Focus pause must be disabled for a live simulation benchmark')
    if report['render_pixels'] != list(expected_pixels):
        raise ValueError('Неверный реальный framebuffer')
    if report['driver'] != 'opengl3' or 'native frame_post_draw' not in report['protocol']:
        raise ValueError('Нужен нативный Compatibility renderer')
    if report['canvas'] != [1152, 648] or report['seed'] != 20261015:
        raise ValueError('Несопоставимые условия')
    rows = report['measurements']
    expected = {(loc, repeat) for loc in locations for repeat in range(3)}
    if {(row['location'], row['repeat']) for row in rows} != expected or len(rows) != len(expected):
        raise ValueError('Нет трёх независимых повторов каждой сцены')
    output = []
    for row in rows:
        count = report['samples_per_repeat']
        if count < 60 or len(row['frame_usec']) != count:
            raise ValueError('Усечённая трасса')
        if row['focused_frames'] != count:
            raise ValueError('Не все кадры с фокусом')
        stats = statistics([value / 1000 for value in row['frame_usec']])
        if stats['p95_ms'] != row['p95_usec'] / 1000:
            raise ValueError('Неверный сохранённый квантиль')
        output.append({'location': row['location'], 'repeat': row['repeat'], 'draw': stats,
                       'terrain_rebuilds': row['terrain_rebuilds'], 'texture_bytes': row['texture_bytes']})
    return {'admission': 'VALID_DIAGNOSTIC_BASELINE', 'render_pixels': list(expected_pixels),
            'note': 'Fixed native target, live scene and host composite; not exclusive GPU cost or OPT route acceptance.',
            'measurements': output}


def main():
    """Публикует прозрачную таблицу и проверенные квантили без скрытия выбросов."""
    results = []
    lines = ['# Native baseline summary', '',
             'Fixed native render target + host composite. Shared OPT quantiles; no GPU/route acceptance claim.', '',
             '| Target | Mode | Location | Repeat | p95 ms | p99 ms | Max ms | Terrain rebuilds |',
             '|---|---|---|---:|---:|---:|---:|---:|']
    links = []
    for width, height in [(1152, 648), (1920, 1080), (3584, 2016)]:
        path = FOLDER / 'before' / f'native-{width}.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        result = analyze(data, (width, height))
        results.append(result)
        links.append(f'[normal {width}](before/native-{width}.json)')
        for row in result['measurements']:
            stats = row['draw']
            lines.append(f"| {width}x{height} | normal | {row['location']} | {row['repeat']} | " +
                         f"{stats['p95_ms']} | {stats['p99_ms']} | {stats['max_ms']} | {row['terrain_rebuilds']} |")
    path = FOLDER / 'before-f10/native-1152.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    result = analyze(data, (1152, 648), {'overworld'})
    results.append(result)
    links.append('[F10](before-f10/native-1152.json)')
    for row in result['measurements']:
        stats = row['draw']
        lines.append(f"| 1152x648 | F10 | overworld | {row['repeat']} | {stats['p95_ms']} | " +
                     f"{stats['p99_ms']} | {stats['max_ms']} | {row['terrain_rebuilds']} |")
    (FOLDER / 'native-summary.md').write_text('\n'.join(lines) + '\n\nRaw data: ' + ', '.join(links) + '.\n', encoding='utf-8')
    (FOLDER / 'baseline-analysis.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
    print('WATER BASELINE: 48 verified diagnostic repeats; OPT/GPU acceptance: not claimed')


if __name__ == '__main__':
    main()
