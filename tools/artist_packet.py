#!/usr/bin/env python3
"""Проверяет воспроизводимый художественный комплект, не принимая новую графику игры."""
from __future__ import annotations

import csv
import hashlib
import io
import json
import re
import subprocess
from pathlib import Path
from common.paths import project_root

from common.git import git_environment

ROOT = project_root(__file__)
REPORT = Path('docs/reports/visual-overhaul/vrelease-005')
ART = Path('docs/reports/visual-overhaul')
# Этот текст — версия инструкции в принятом комплекте; живой CLI развивается отдельно.
HISTORICAL_DOCUMENTS = frozenset({'docs/SPRITE_STANDARD.md'})


def read(root: Path, path: Path) -> dict:
    """Читает источник художественного решения без изменения его байтов."""
    return json.loads((root / path).read_text())


def palette_svg(root: Path) -> str:
    """Строит читаемый лист точных принятых дневных и вечерних цветов."""
    data = read(root, ART / 'vart-003/palette.json')
    rows = ['<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1040" viewBox="0 0 1000 1040" role="img" aria-labelledby="title">',
            '<title id="title">Тёплая долина: шесть материалов, день и вечер, точные цвета sRGB</title>',
            '<rect width="1000" height="1040" fill="#f4efdf"/>',
            '<g font-family="sans-serif" fill="#3e2c25">',
            '<text x="32" y="42" font-size="26">Тёплая долина · VART-003 A</text>',
            '<text x="32" y="74" font-size="17">Тень → местный цвет → блик · sRGB · живописные переходы допустимы</text>']
    for index, material in enumerate(data['materials']):
        y = 110 + index * 150
        rows.append(f'<text x="32" y="{y}" font-size="21">{material["name"]}</text>')
        for phase, label, offset in [('day', 'День', 15), ('evening', 'Вечер', 73)]:
            rows.append(f'<text x="32" y="{y+offset+24}" font-size="17">{label}</text>')
            for stop, color in enumerate(data['variants']['a']['ramps'][material['id']][phase]):
                x = 145 + stop * 165
                rows.append(f'<rect x="{x}" y="{y+offset}" width="153" height="30" fill="{color}"/>')
                rows.append(f'<text x="{x}" y="{y+offset+48}" font-size="16">{color.upper()}</text>')
    return '\n'.join(rows + ['</g></svg>', ''])


def module_csv(root: Path) -> str:
    """Выгружает геометрию образцов без округления опоры и нормализации силуэтов."""
    data = read(root, ART / 'vart-008/modules.json')
    output = io.StringIO(newline='')
    writer = csv.writer(output, lineterminator='\n')
    writer.writerow(['id', 'kind', 'master_relative_to_vart_008', 'source_x_px', 'source_y_px',
                     'source_w_px', 'source_h_px', 'world_per_source_px', 'pivot_x_source_px',
                     'pivot_y_source_px', 'draw_width_world', 'draw_height_world',
                     'footprint_w_world', 'footprint_h_world', 'facing', 'runtime_integrated'])
    for part in data['parts']:
        footprint = part['footprint'] or ['', '']
        writer.writerow([part['id'], part['kind'], part['source'], *part['rect'], part['scale'],
                         *part['pivot'], part['rect'][2]*part['scale'], part['rect'][3]*part['scale'],
                         *footprint, part['facing'], 'false'])
    return output.getvalue()


def example(root: Path) -> dict:
    """Заполняет пример настоящими данными принятого дерева, сохраняя статус макета."""
    part = next(p for p in read(root, ART / 'vart-008/modules.json')['parts'] if p['id'] == 'tree')
    master = (ART / 'vart-006/density-b.png').as_posix()
    return {
        'schema': 'artist-handoff-1', 'id': 'reference.vart008.tree', 'task': 'VART-008',
        'owner': 'Художественный эталон VART-008', 'kind': 'tree', 'status': 'accepted_mockup',
        'runtime_integration': False,
        'source': {'file': master, 'sha256': hashlib.sha256((root/master).read_bytes()).hexdigest(),
                   'origin': 'Генерация imagegen по сохранённому промпту VART-006 B',
                   'rights_review': 'Открыто: юридическую приёмку выпуска этот пример не выполняет'},
        'decisions': {'style': 'VART-001 A', 'palette': 'VART-003 A', 'edge': 'VART-005 A',
                      'density': 'VART-006 B', 'light': 'VART-007 A'},
        'views': {'neutral': {'source_rect_px': part['rect'], 'pivot_source_px': part['pivot'],
                             'world_per_source_px': part['scale'],
                             'draw_size_world': [part['rect'][i]*part['scale'] for i in [2, 3]],
                             'footprint_world': part['footprint']}},
        'layers': {'color': 'Мастер; контакт и солнечная тень отдельны в стенде',
                   'data_masks': 'Не заказаны и не подключены этим примером'},
        'export': {'illustration': 'RGBA8 sRGB PNG, straight alpha',
                   'sampling': 'linear, repeat disabled в отдельном стенде',
                   'mipmaps': 'Стенд VART-008 создаёт собственную цепочку; runtime-импорт отдельно',
                   'padding': 'Поля исходного региона; не разрешение на общий linear-атлас'},
        'consumers': {'Game': 'не подключено', 'F12': 'не подключено', 'Wiki': 'эталон VART-008'},
        'review': {'package_source_commit': read(root, REPORT/'references.json')['source_commit'],
                   'configuration': 'VART-008/native/capture.json; 1152x648, поле 960x540, zoom 1.2',
                   'frame': (ART/'vart-008/native/pilot-a-front.png').as_posix(),
                   'frame_sha256': hashlib.sha256((root/ART/'vart-008/native/pilot-a-front.png').read_bytes()).hexdigest(),
                   'rollback': 'Игровая ссылка не менялась; предыдущие мастера сохранены',
                   'open': ['Production-слои и маски', 'Навигация и коллизии', 'Бюджет памяти/FPS']}}


def verify(root: Path = ROOT, manifest: dict | None = None) -> list[str]:
    """Отклоняет порчу, выход ссылок за проект, смену Git-основания и устаревшие производные."""
    errors = []
    try:
        data = manifest if manifest is not None else read(root, REPORT/'references.json')
        commit = data.get('source_commit', '')
        if data.get('schema') != 1 or not re.fullmatch('[a-f0-9]{40}', commit):
            return ['invalid schema/source commit']
        if data.get('runtime_changed') is not False or data.get('performance_accepted') is not False:
            errors.append('artist packet cannot claim runtime/performance acceptance')
        refs = data.get('references', [])
        paths = [r['file'] for r in refs]
        if len(paths) != len(set(paths)): errors.append('duplicate reference')
        article = (root/'wiki/articles/artist-packet.md').read_text()
        required = {str(ART/'vart-008/modules.json'), str(ART/'vart-003/palette.json'),
                    str(ART/'vcamera-006/camera-profile.json'), str(ART/'vrelease-001/acceptance.json')}
        required.update(re.findall(r'!\[[^\]]*\]\(../../([^)]*)\)', article))
        required.discard((REPORT/'palette.svg').as_posix())
        if required - set(paths): errors.append('missing reference coverage')
        for row in refs:
            path = Path(row['file'])
            if path.is_absolute() or '..' in path.parts or not (root/path).resolve().is_relative_to(root.resolve()):
                errors.append('reference escapes project: '+str(path)); continue
            if path.as_posix() not in HISTORICAL_DOCUMENTS:
                raw = (root/path).read_bytes()
                if hashlib.sha256(raw).hexdigest() != row['sha256']:
                    errors.append('reference SHA256 mismatch: '+str(path))
            old = subprocess.run(['git', '-C', str(root), 'show', commit+':'+path.as_posix()],
                                 capture_output=True, check=False, env=git_environment())
            if old.returncode or hashlib.sha256(old.stdout).hexdigest() != row['sha256']:
                errors.append('reference differs from Git source: '+str(path))
        for name, expected in [('palette.svg', palette_svg(root)), ('modules.csv', module_csv(root))]:
            if (root/REPORT/name).read_text() != expected: errors.append('stale derived file: '+name)
        if read(root, REPORT/'handoff-example.json') != example(root): errors.append('stale handoff example')
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append('incomplete packet: '+str(exc))
    return errors


if __name__ == '__main__':
    failures = verify()
    if failures: raise SystemExit('\n'.join(failures))
    print('ARTIST PACKET: Git-pinned sources, palette, 28 modules and handoff example valid; runtime gates remain open')
