#!/usr/bin/env python3
"""Снимает и проверяет точки камеры; статические кадры не допускаются в замер производительности."""
from __future__ import annotations
from tools.assets.contracts.source_paths import current_source

import argparse
import hashlib
import html
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
from tools.common.git import git_environment
import uuid

from tools.common.paths import project_root
from tools.common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
REPORT = ROOT / 'docs/reports/visual-overhaul/vbase-003'
REGISTRY = REPORT / 'camera-points.json'
SIZE = [1152, 648]
FIELDS = ['id', 'location', 'player', 'camera', 'facing', 'day', 'minutes', 'phase', 'seed', 'season', 'weather']


def read(path: Path) -> dict:
    """Читает паспорт или реестр из файла без выполнения его содержимого."""
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    """Связывает данные с точными байтами файла."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def registry_errors(data: dict) -> list[str]:
    """Проверяет уникальные точки, конечные координаты и единый исходный профиль."""
    errors = []
    points = data.get('points', [])
    if data.get('schema') != 1 or data.get('preset') != 'camera-entry-noon-1152-v1' or data.get('viewport') != SIZE:
        errors.append('registry preset')
    if len(points) != 30 or len({p.get('id') for p in points}) != 30 or len({p.get('location') for p in points}) != 30:
        errors.append('registry coverage/duplicates')
    for point in points:
        if set(FIELDS + ['label']) - point.keys(): errors.append('missing point fields'); continue
        if not re.fullmatch(r'[a-z_]+-entry-v1', point['id']) or point['id'] != point['location'] + '-entry-v1': errors.append('point id')
        for key in ['player', 'camera', 'facing']:
            value = point[key]
            if not isinstance(value, list) or len(value) != 2 or any(type(v) not in (int, float) or not math.isfinite(v) for v in value): errors.append('point vector')
        for key, value in dict(day=1, minutes=720, phase='day', seed=20261015, season='spring', facing=[0, 1]).items():
            if point[key] != value: errors.append('point preset ' + key)
        if point['weather'] not in ['clear', 'wind']: errors.append('point climate')
    return errors


def capture_errors(data: dict, registry: dict) -> list[str]:
    """Сверяет каждый фактический кадр с реестром и отклоняет потерю фокуса либо подмену профиля."""
    errors = []
    if data.get('kind') != 'static-camera-reference' or data.get('performance_eligible') is not False or data.get('simulation_frozen') is not True: errors.append('not a static-only reference')
    if data.get('display_server') in [None, 'headless'] or data.get('renderer') != 'opengl3': errors.append('native renderer')
    if data.get('preset') != registry['preset'] or data.get('hud') is not True or data.get('reduced_motion') is not True: errors.append('capture preset')
    if data.get('errors'): errors.append('native errors')
    expected = {p['id']: p for p in registry['points']}
    rows = data.get('points', [])
    if len(rows) != len(expected) or {r.get('id') for r in rows} != set(expected): errors.append('capture coverage')
    for row in rows:
        point = expected.get(row.get('id'))
        if point is None: continue
        for key in FIELDS:
            if row.get(key) != point[key]: errors.append(f'{point["id"]}: {key}')
        if row.get('walkable') != 'walkable' or row.get('physics_processing') is not False: errors.append('pose not frozen/walkable')
        if row.get('readback') != SIZE or row.get('image') != point['id'] + '.png': errors.append('image identity/size')
        conditions = row.get('conditions', [])
        if len(conditions) != 12: errors.append('missing preparation frames')
        for state in conditions:
            if any(state.get(k) != SIZE for k in ['window', 'framebuffer', 'root']) or state.get('focused') is not True or state.get('mode') != 0 or state.get('valid') is not True:
                errors.append('window/framebuffer/focus')
    return errors


def verify(folder: Path, registry: dict) -> list[str]:
    """Проверяет два независимых запуска, привязку исходников и настоящие PNG заданного размера."""
    errors = registry_errors(registry)
    source = read(folder / 'source.json')
    if not re.fullmatch('[0-9a-f]{40}', source.get('commit', '')) or source.get('registry_sha256') != digest(REGISTRY): errors.append('source/registry provenance')
    if source.get('kind') != 'static-camera-reference' or source.get('performance_eligible') is not False: errors.append('source classification')
    if source.get('repeats') != 2: errors.append('two repeats required')
    profiles = []
    for repeat in range(1, source['repeats'] + 1):
        run = folder / f'run-{repeat}'
        capture = read(run / 'capture.json')
        errors += capture_errors(capture, registry)
        profiles.append(capture.get('profile'))
        for row in capture.get('points', []):
            name = row.get('image', '')
            if Path(name).name != name: errors.append('unsafe image path'); continue
            path = run / name
            if not path.exists(): errors.append('missing PNG'); continue
            raw = path.read_bytes()
            if raw[:8] != b'\x89PNG\r\n\x1a\n' or len(raw) < 24 or list(struct.unpack('>II', raw[16:24])) != SIZE: errors.append('PNG dimensions')
            if source.get('images', {}).get(f'run-{repeat}/{name}') != digest(path): errors.append('PNG hash')
        if 'ERROR:' in (run / 'stdout.txt').read_text(): errors.append('engine errors')
    if len(set(profiles)) != len(profiles) or any(not str(p).startswith('Codex-VBASE-003-') for p in profiles): errors.append('profiles reused')
    return errors


def gallery(folder: Path, registry: dict) -> None:
    """Создаёт локальный указатель настоящих кадров двух повторов без монтажа изображений."""
    cards = []
    for point in registry['points']:
        name = html.escape(point['id'])
        cards.append(f'<section><h2>{html.escape(point["label"])} <small>{name}</small></h2><p>Герой {point["player"]} · камера {point["camera"]} · {point["weather"]}</p><div>' + ''.join(f'<a href="run-{i}/{name}.png"><img loading="lazy" src="run-{i}/{name}.png" alt="Повтор {i}: {name}"></a>' for i in [1, 2]) + '</div></section>')
    (folder / 'index.html').write_text('<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>VBASE-003 · камеры</title><style>body{background:#f5f2e9;color:#282824;font:16px/1.5 system-ui;margin:24px}main{max-width:1600px;margin:auto}small{font-size:14px;font-weight:normal}section{margin:32px 0}section div{display:flex;gap:16px}a{width:50%}img{width:100%;height:auto}h2{font-size:20px}@media(max-width:900px){section div{display:block}a{display:block;width:100%}}</style><main><h1>30 точек камеры · два нативных повтора</h1><p>День 1, полдень, seed 20261015, 1152×648. Симуляция остановлена. Вода и свечение используют системное время: пиксельная идентичность не требуется. Это проверка ракурсов, не FPS и не новый художественный эталон.</p>' + ''.join(cards) + '</main></html>')


def run_capture(folder: Path, point: str) -> int:
    """Запускает свежие нативные процессы последовательно и сохраняет неуспешный запуск для разбора."""
    registry = read(REGISTRY)
    errors = registry_errors(registry)
    if errors: raise ValueError(errors)
    if point and point not in {p['id'] for p in registry['points']}: raise ValueError('unknown point')
    folder.mkdir(parents=True, exist_ok=False)
    binary = os.environ.get('FARM_GODOT_BIN') or str(ROOT / 'tools/Godot.app/Contents/MacOS/Godot')
    if not Path(binary).is_file(): binary = shutil.which('godot') or binary
    git = lambda *args: subprocess.check_output(['git', *args], cwd=ROOT, text=True, env=git_environment()).strip()
    paths = ['project.godot', 'main.tscn', 'tools/visual_camera_points.gd', 'tools/visual_camera_capture.gd', 'tools/visual_camera.py']
    source = dict(kind='static-camera-reference', performance_eligible=False, commit=git('rev-parse', 'HEAD'),
                  dirty=git('status', '--porcelain'), registry_sha256=digest(REGISTRY), repeats=2,
                  files={name: digest(current_source(ROOT, name)) for name in paths}, images={}, commands=[])
    (folder / 'registry.json').write_text(json.dumps(registry, ensure_ascii=False, indent=2) + '\n')
    for repeat in [1, 2]:
        run = folder / f'run-{repeat}'; run.mkdir()
        command = [binary, '--path', str(ROOT), '--windowed', '--resolution', '1152x648', '--position', '80,80', '--rendering-method', 'gl_compatibility', '--log-file', str(run / 'engine.txt'), '--script', 'tools/qa/camera/visual_camera_capture.gd', '--', f'--output={run}', '--profile=Codex-VBASE-003-' + uuid.uuid4().hex]
        if point: command.append('--point=' + point)
        source['commands'].append(command)
        (folder / 'source.json').write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n')
        print(f'Capture {repeat}/2', flush=True)
        with (run / 'stdout.txt').open('w') as output:
            result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=240)
        if result.returncode or 'ERROR:' in (run / 'stdout.txt').read_text():
            print(f'Rejected; see {run}/stdout.txt'); return 2
        for path in run.glob('*.png'): source['images'][f'run-{repeat}/{path.name}'] = digest(path)
    (folder / 'source.json').write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n')
    if point:
        print('Single-point probe only; full coverage not accepted'); return 0
    errors = verify(folder, registry)
    if errors: print('\n'.join(errors)); return 2
    gallery(folder, registry)
    print('CAMERA: 30 locations × 2 native repeats; not performance eligible'); return 0


def main() -> int:
    """Разделяет съёмку новых данных, проверку сохранённых свидетельств и проверку только реестра."""
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['capture', 'verify', 'check'])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--point', default='')
    args = parser.parse_args()
    try:
        if args.mode == 'capture':
            if args.output is None: parser.error('--output required')
            return run_capture(args.output.resolve(), args.point)
        errors = registry_errors(read(REGISTRY)) if args.mode == 'check' else verify((args.output or REPORT / 'native').resolve(), read(REGISTRY))
        print('\n'.join(errors) if errors else 'CAMERA: valid static reference contract')
        return 2 if errors else 0
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f'CAMERA rejected: {error}'); return 2


if __name__ == '__main__':
    raise SystemExit(main())
