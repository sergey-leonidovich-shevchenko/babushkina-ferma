#!/usr/bin/env python3
"""VBASE-005: воспроизводимый маршрут игровым вводом, два нативных видео и независимый допуск QA."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

from PIL import Image, ImageChops, ImageStat
from run_visual_baseline import command, environment

from common.paths import project_root
from common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
REPORT = ROOT / 'docs/reports/visual-overhaul/vbase-005'
SOURCES = ['tools/visual_motion.py', 'tools/visual_motion_route.gd', 'tools/visual_motion_capture.gd',
           'tools/encode_coordinate_video.swift', 'tools/visual_camera_points.gd',
           'scripts/core/game_input_router.gd', 'scripts/core/game_loop.gd', 'scripts/game_core.gd',
           'scripts/systems/location_transition_system.gd', 'scripts/systems/building_system.gd',
           'scripts/systems/camera_system.gd', 'scripts/systems/npc_movement_system.gd', 'project.godot',
           'docs/reports/visual-overhaul/vbase-005/routes.json']
VECTORS = {'A': [-1, 0], 'D': [1, 0], 'W': [0, -1], 'S': [0, 1]}


def read(path: Path):
    """Читает JSON как данные, без запуска содержимого."""
    return json.loads(path.read_text())


def sha(path: Path) -> str:
    """Подписывает исходные байты кадра, видео либо инструмента."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_source(folder: Path, source: dict) -> None:
    """Обновляет подписи даже у неполной или отклонённой съёмки; ошибки не исчезают при исключении."""
    source['artifacts'] = {str(p.relative_to(folder)): sha(p) for p in sorted(folder.rglob('*'))
                           if p.is_file() and p.name != 'source.json' and 'instrumentation' not in p.parts}
    (folder/'source.json').write_text(json.dumps(source, indent=2)+'\n')


def require(value, reason: str) -> None:
    """Сохраняет точную причину отказа вместо ложной зелёной приёмки."""
    if not value:
        raise ValueError(reason)


def pair(value) -> bool:
    """Не допускает NaN, бесконечность и строковые координаты в физическом следе."""
    return isinstance(value, list) and len(value) == 2 and all(type(x) in (int, float) and math.isfinite(x) for x in value)


def validate_run(data: dict, plan: dict) -> dict:
    """Проверяет весь путь, клавиши и две разрешённые дверные смены координат, не доверяя finished."""
    require(data.get('schema') == 1 and data.get('kind') == 'native-input-motion', 'native motion required')
    require(data.get('performance_eligible') is False, 'diagnostic readbacks cannot enter performance gate')
    require(data.get('simulation_live') is True and data.get('physics_hz') == 60, 'live fixed-clock simulation required')
    require(data.get('display_server') not in (None, 'headless') and data.get('renderer') == 'opengl3', 'native renderer required')
    require(data.get('preset') == plan['id'] and not data.get('fault') and not data.get('errors'), 'preset or native error')
    require(str(data.get('profile', '')).startswith('Codex-VBASE-005-') and data.get('finished') is True, 'isolated finished route required')
    require(data.get('conditions'), 'missing native conditions')
    for state in data['conditions']:
        require(all(state.get(k) == [1152, 648] for k in ('window', 'root', 'texture')), 'window/framebuffer mismatch')
        require(state.get('focus') is True and state.get('mode') == 0 and state.get('vsync') == 1, 'focus/mode/vsync mismatch')
    rows, steps = data['rows'], plan['steps']
    require({a['id']: a['position'] for a in rows[0]['actors']} == plan['crowd_fixture']['actors'], 'four-resident fixture differs')
    require(120 < len(rows) <= plan['max_ticks'] + 1 and rows[0]['player'] == plan['start'], 'short route or wrong start')
    require(rows[0]['camera'] == plan['start_camera'] and rows[0]['minutes'] == plan['minutes'], 'wrong initial camera/time')
    inputs = {}
    last_order = (-1, 0)
    for edge in data['inputs']:
        order = (edge['tick'], 0 if edge['phase'] == 'before' else 1)
        require(edge['phase'] in ('before', 'after') and edge['key'] in VECTORS and type(edge['pressed']) is bool, 'invalid input edge')
        require(last_order <= order and 1 <= edge['tick'] < len(rows), 'input order or range')
        inputs.setdefault(order, []).append(edge)
        last_order = order
    held, transitions = set(), []
    bridge_y, grass, overlap = [], 0, 0
    for index, row in enumerate(rows):
        require(row['tick'] == index and 0 <= row['step'] < len(steps), 'missing tick or invalid step')
        require(all(pair(row.get(k)) for k in ('player', 'foot', 'camera', 'direction')), 'invalid pose')
        require(row.get('live') is True and row.get('walkable') is True, 'paused simulation or blocked position')
        require(type(row['minutes']) in (int, float) and math.isfinite(row['minutes']) and abs(row['minutes'] - (plan['minutes'] + index / 60)) < 0.0001, 'world clock stopped or skipped')
        require(math.dist(row['foot'], row['player']) < 0.001, 'rendered feet differ from physics')
        expected_camera = [math.floor(max(0, min(plan['world_bounds'][i] - [1152, 648][i], row['player'][i] - [576, 324][i])) + 0.5) for i in range(2)] if row['location'] == 'overworld' else plan['interior_camera']
        require(row['camera'] == expected_camera, 'camera differs from reference projection')
        require(len({a['id'] for a in row['actors']}) == len(row['actors']) and all(pair(a['position']) for a in row['actors']), 'invalid actor observations')
        if index == 0:
            continue
        require(row.get('auto_physics') is True, 'native physics processing stopped')
        require(type(row.get('physics_delta')) in (float, int) and abs(row['physics_delta'] - 1/60) < 1e-9, 'observed physics delta differs')
        for edge in inputs.get((index, 0), []):
            require((edge['key'] in held) != edge['pressed'], 'duplicate input edge')
            held.add(edge['key']) if edge['pressed'] else held.remove(edge['key'])
        require(len(held) <= 1, 'diagonal or conflicting keyboard movement')
        before = rows[index - 1]
        if row['location'] != before['location']:
            transitions.append(index)
            if before['location'] == 'overworld' and row['location'] == 'cottage_interior':
                require(math.dist(before['player'], [360, 552]) <= 41.51 and row['player'] == [576, 500] and held == {'W'}, 'door entry bypassed')
            elif before['location'] == 'cottage_interior' and row['location'] == 'overworld':
                require(math.dist(before['player'], [576, 545]) <= 41.51 and row['player'] == [360, 648] and held == {'S'}, 'door exit bypassed')
            else:
                raise ValueError('unexpected location teleport')
        else:
            motion = [row['player'][axis] - before['player'][axis] for axis in range(2)]
            require(math.hypot(*motion) <= plan['speed'] / 60 + 0.01, 'non-physical jump')
            if math.hypot(*motion) > 0.001:
                require(held, 'movement without input')
                direction = VECTORS[next(iter(held))]
                require(sum(motion[i] * direction[i] for i in range(2)) > 0, 'movement opposes input')
        for edge in inputs.get((index, 1), []):
            require((edge['key'] in held) != edge['pressed'], 'duplicate after-step edge')
            held.add(edge['key']) if edge['pressed'] else held.remove(edge['key'])
        if row['location'] == 'overworld':
            x, y = row['player']
            if 830 <= x <= 898 and 350 <= y <= 580 and steps[row['step']]['tag'] == 'bridge': bridge_y.append(y)
            if steps[row['step']]['tag'] == 'grass' and row['road_distance'] >= 48: grass += 1
            visible = [a for a in row['actors'] if a['id'] in plan['crowd_fixture']['actors'] and abs(a['position'][0] - x) < 90 and abs(a['position'][1] - y) < 60]
            if len(visible) >= 3: overlap += 1
    require(not held and len(transitions) == 2, 'keys not released or door round trip missing')
    require(len(bridge_y) > 20 and min(bridge_y) < 400 and max(bridge_y) > 520, 'bridge not crossed between banks')
    require(grass >= 12 and overlap >= 6, 'grass or four-resident fixture not exercised')
    require(len(data['transitions']) == 2 and [e['tick'] for e in data['transitions']] == transitions, 'door event coverage differs')
    points = data['checkpoints']
    require([p['id'] for p in points] == [s['id'] for s in steps], 'checkpoint missing or reordered')
    previous_tick = 0
    for step, point in zip(steps, points):
        tick = point['tick']
        require(previous_tick < tick < len(rows), 'checkpoint tick invalid')
        require(point['position'] == rows[tick]['player'] and point['location'] == step['location'] and point['camera'] == rows[tick]['camera'], 'checkpoint does not match observed row')
        if step['kind'] == 'move': require(math.dist(point['position'], step['target']) <= plan['tolerance'], 'waypoint not reached')
        previous_tick = tick
    require(previous_tick == len(rows) - 1 and rows[-1]['location'] == 'overworld', 'route truncated after last waypoint')
    return dict(admission='VALID_MOTION_ROUTE', performance_eligible=False, ticks=len(rows)-1,
                seconds=(len(rows)-1)/60, grass_ticks=grass, overlap_ticks=overlap, door_transitions=transitions)


def verify(folder: Path) -> dict:
    """Проверяет два независимых запуска и сохранённые медиа, без повторного захвата на машине CI."""
    source = read(folder / 'source.json')
    plan = read(folder / 'routes.json')
    require(source.get('task') == 'VBASE-005' and source.get('performance_eligible') is False, 'wrong report classification')
    require(source.get('collection_complete') is True, 'incomplete native collection')
    require(re.fullmatch('[0-9a-f]{40}',source['base_commit']) and len(source['runs']) == 2, 'source revision or repeat count missing')
    require(source['runs'] == ['run-1', 'run-2'], 'unexpected run paths')
    required = {'routes.json'} | {f'{run}/{name}' for run in source['runs'] for name in
                               ('capture.json','stdout.txt','engine.txt','environment.json','walk.mp4','walk.json','walk.decoded.png',
                                'encoder.txt','keyframes.json','start.png','finish.png','crowd.png','bridge.png','grass.png','door-inside.png','door-outside.png')}
    require(required == set(source['artifacts']), 'artifact coverage differs')
    for name, signature in source['artifacts'].items():
        path = (folder / name).resolve()
        require(path.is_relative_to(folder.resolve()) and path.is_file() and sha(path) == signature, 'artifact differs: ' + name)
    for name, signature in source['sources'].items():
        path = (folder / 'instrumentation' / name).resolve()
        require(path.is_relative_to((folder / 'instrumentation').resolve()) and sha(path) == signature, 'archived source differs')
    require(set(source['sources']) == set(SOURCES), 'source coverage differs')
    require(sha(folder / 'routes.json') == source['sources']['docs/reports/visual-overhaul/vbase-005/routes.json'], 'route definition differs from captured source')
    results, reports = [], []
    for run in source['runs']:
        case = folder / run
        data = read(case / 'capture.json'); reports.append(data); results.append(validate_run(data, plan))
        environment = read(case / 'environment.json')
        argv = environment['command']
        clock_index = argv.index('--fixed-fps') if '--fixed-fps' in argv else len(argv)
        require(environment.get('exit_code') == 0 and '--headless' not in argv and clock_index+1 < len(argv) and argv[clock_index+1] == '60', 'actual launch clock/native arguments differ')
        require(not any(x in (case / 'stdout.txt').read_text() for x in ('ERROR:', 'SCRIPT ERROR', 'Parse Error')), 'engine error in log')
        video = read(case / 'walk.json')
        require([video['width'], video['height']] == [1152, 648] and video['fps'] == 20 and video['frames'] == len(data['frames']), 'video geometry/count differs')
        require(abs(video['duration'] - len(data['frames']) / 20) < 0.01, 'video duration differs')
        require((case / 'walk.mp4').stat().st_size > 1024 and b'ftyp' in (case / 'walk.mp4').read_bytes()[:32], 'invalid MP4')
        with Image.open(case / 'start.png') as first, Image.open(case / 'walk.decoded.png') as decoded:
            require(first.size == decoded.size == (1152, 648), 'native/decoded PNG size differs')
            require(sum(ImageStat.Stat(ImageChops.difference(first.convert('RGB'), decoded.convert('RGB'))).mean) / 3 < 6, 'video content/orientation differs')
        for frame in data['frames']:
            require(frame['readback'] == [1152, 648] and 0 <= frame['tick'] < len(data['rows']), 'frame tick/readback differs')
            row = data['rows'][frame['tick']]
            require(frame['player'] == row['player'] and frame['camera'] == row['camera'] and frame['location'] == row['location'], 'frame/physics mismatch')
        require(data['frames'][0]['tick'] == 0 and data['frames'][-1]['tick'] == len(data['rows']) - 1, 'video does not cover whole route')
        expected_ticks = list(range(0, len(data['rows']), 3))
        if expected_ticks[-1] != len(data['rows'])-1: expected_ticks.append(len(data['rows'])-1)
        require([f['tick'] for f in data['frames']] == expected_ticks, 'video sampling timeline differs')
        for edge in read(case / 'keyframes.json'):
            require(edge['frame'] in data['frames'] and edge['file'] in source['artifacts'], 'keyframe provenance differs')
            with Image.open(folder / edge['file']) as image: require(image.size == (1152, 648), 'keyframe size differs')
    a, b = reports
    require(a['pid'] != b['pid'] and a['profile'] != b['profile'], 'process/profile reused')
    require(all(a[k] == b[k] for k in ('engine', 'adapter', 'renderer', 'preset', 'checkpoints', 'inputs', 'transitions')), 'non-comparable route configuration')
    require(len(a['rows']) == len(b['rows']), 'repeat duration differs')
    for left, right in zip(a['rows'], b['rows']):
        require(all(left[k] == right[k] for k in ('tick', 'step', 'location', 'player', 'camera', 'actors')), 'repeat physics/camera differs')
    return dict(admission='VALID_MOTION_PAIR', performance_eligible=False, base_commit=source['base_commit'], repeats=results)


def capture(folder: Path) -> None:
    """Снимает новый полный набор; сырые PNG временные, ошибки и выбранные кадры сохраняются."""
    require(not folder.exists(), 'output must be new')
    folder.mkdir(parents=True)
    shutil.copy2(REPORT / 'routes.json', folder / 'routes.json')
    source = dict(task='VBASE-005', schema=1, performance_eligible=False, base_commit=command(['git','rev-parse','HEAD']),
                  dirty_paths=command(['git','status','--short']), sources={}, artifacts={}, runs=[], collection_complete=False)
    for name in SOURCES:
        target = folder / 'instrumentation' / name; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, target); source['sources'][name] = sha(target)
    save_source(folder, source)
    godot = os.environ.get('FARM_GODOT_BIN', str(ROOT / 'tools/Godot.app/Contents/MacOS/Godot'))
    with tempfile.TemporaryDirectory(prefix='farm-motion-') as temporary:
        raw = Path(temporary)
        for repeat in range(1, 3):
            name = f'run-{repeat}'; case = folder / name; case.mkdir(); native = raw / name
            source['runs'].append(name)
            profile = 'Codex-VBASE-005-' + uuid.uuid4().hex
            call = [godot, '--path', str(ROOT), '--windowed', '--fixed-fps', '60', '--audio-driver', 'Dummy',
                    '--log-file', str(case / 'engine.txt'), '--script', 'tools/visual_motion_capture.gd', '--',
                    '--output=' + str(native), '--profile=' + profile]
            before = environment(); print('MOTION '+name, flush=True)
            (case / 'environment.json').write_text(json.dumps(dict(before=before, command=call), indent=2)+'\n')
            save_source(folder, source)
            with (case / 'stdout.txt').open('w') as log:
                try:
                    result = subprocess.run(call, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=240)
                    code = result.returncode
                except subprocess.TimeoutExpired:
                    code = 124
            if (native / 'capture.json').is_file(): shutil.copy2(native / 'capture.json', case / 'capture.json')
            (case / 'environment.json').write_text(json.dumps(dict(before=before, after=environment(), command=call, exit_code=code), indent=2)+'\n')
            save_source(folder, source)
            require(code == 0, 'native route rejected; capture and log retained: '+name)
            data = read(case / 'capture.json')
            validate_run(data, read(folder / 'routes.json'))
            frames = data['frames']; selected = [('start', frames[0]), ('finish', frames[-1])]
            points = {p['id']:p for p in data['checkpoints']}
            for label, tick, location in [('crowd',points['crowd-through']['tick']//2,'overworld'),
                                           ('bridge',(points['bridge-turn']['tick']+points['bridge-cross']['tick'])//2,'overworld'),
                                           ('grass',points['grass-west']['tick'],'overworld'),
                                           ('door-inside',points['door-enter']['tick'],'cottage_interior'),
                                           ('door-outside',points['door-leave']['tick'],'overworld')]:
                frame = next(f for f in frames if f['tick'] >= tick and f['location'] == location)
                selected.append((label, frame))
            keyframes = []
            for label, frame in selected:
                filename = label + '.png'; shutil.copy2(native / 'frames' / frame['file'], case / filename)
                keyframes.append(dict(frame=frame, file=name+'/'+filename))
            (case / 'keyframes.json').write_text(json.dumps(keyframes, indent=2)+'\n')
            env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(raw/'clang-cache'), SWIFT_MODULECACHE_PATH=str(raw/'swift-cache'))
            with (case / 'encoder.txt').open('w') as log:
                subprocess.run(['swift', str(ROOT/'tools/encode_coordinate_video.swift'), str(native/'frames'), str(case/'walk.mp4'), '20', '2500000'],
                               env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
            save_source(folder, source)
    source['collection_complete'] = True
    save_source(folder, source)
    print(json.dumps(verify(folder), indent=2))


def verify_controls(folder: Path) -> dict:
    """Требует наблюдаемый дефект, а не один флаг fault; проверка не запускает графику на CI."""
    source = read(folder/'source.json')
    require(source.get('controls') == ['resize','pause','focus','teleport'], 'native control coverage differs')
    require(source.get('performance_eligible') is False, 'controls cannot enter performance gate')
    require(sha(folder/'collector.py') == source['collector_sha256'], 'control collector differs')
    positive = read(folder.parent/'native/source.json')
    require(source['base_commit'] == positive['base_commit'], 'control runtime differs')
    require(set(source['native_sources']) == {'tools/visual_motion_capture.gd','tools/visual_motion_route.gd','docs/reports/visual-overhaul/vbase-005/routes.json'}, 'control instrumentation coverage differs')
    for name, signature in source['native_sources'].items():
        require(positive['sources'].get(name) == signature, 'control/native instrumentation differs')
    expected = {'collector.py'} | {f'{name}/{file}' for name in source['controls'] for file in ('capture.json','stdout.txt','engine.txt','environment.json','last.png')}
    require(set(source['artifacts']) == expected, 'control artifacts missing')
    for name, signature in source['artifacts'].items():
        path = (folder/name).resolve()
        require(path.is_relative_to(folder.resolve()) and sha(path) == signature, 'control artifact differs')
    observed = {}
    for name in source['controls']:
        data = read(folder/name/'capture.json')
        require(data['kind'] == 'native-input-motion' and data['fault'] == name and data['errors'] and not data['finished'], 'native control not rejected')
        require(read(folder/name/'environment.json')['exit_code'] == 2, 'unexpected control process result')
        require(data['display_server'] != 'headless', 'headless control cannot prove native failure')
        if name == 'resize': ok = any(s['window'] != [1152,648] or s['texture'] != [1152,648] for s in data['conditions']) or any(f['readback'] != [1152,648] for f in data['frames'])
        elif name == 'focus': ok = any(s['focus'] is False for s in data['conditions'])
        elif name == 'pause': ok = any(r.get('auto_physics') is False and r['minutes'] == before['minutes'] for before,r in zip(data['rows'],data['rows'][1:]))
        else: ok = any(a['location'] == b['location'] and math.dist(a['player'],b['player']) > 20 for a,b in zip(data['rows'],data['rows'][1:]))
        require(ok, 'requested native fault was not observed: '+name)
        with Image.open(folder/name/'last.png') as image:
            require(list(image.size) == data['frames'][-1]['readback'], 'control PNG/readback differs')
        observed[name] = data['errors']
    return dict(admission='VALID_NATIVE_REJECTIONS', performance_eligible=False, observed=observed)


def capture_controls(folder: Path) -> None:
    """Создаёт четыре отдельных отклоняемых запуска и сохраняет весь след, журнал и последний Image."""
    require(not folder.exists(), 'control output must be new')
    folder.mkdir(parents=True)
    shutil.copy2(ROOT/'tools/visual_motion.py', folder/'collector.py')
    names = ['resize','pause','focus','teleport']
    source = dict(controls=names, performance_eligible=False, collector_sha256=sha(folder/'collector.py'),
                  base_commit=command(['git','rev-parse','HEAD']), native_sources={name:sha(ROOT/name) for name in SOURCES if name.endswith(('visual_motion_capture.gd','visual_motion_route.gd','routes.json'))})
    godot = os.environ.get('FARM_GODOT_BIN', str(ROOT/'tools/Godot.app/Contents/MacOS/Godot'))
    for name in names:
        case = folder/name; case.mkdir(); print('MOTION CONTROL '+name, flush=True)
        with tempfile.TemporaryDirectory(prefix='farm-motion-control-') as raw:
            native = Path(raw)/name
            call = [godot,'--path',str(ROOT),'--windowed','--fixed-fps','60','--audio-driver','Dummy','--log-file',str(case/'engine.txt'),
                    '--script','tools/visual_motion_capture.gd','--','--output='+str(native),'--profile=Codex-VBASE-005-'+uuid.uuid4().hex,'--fault='+name]
            with (case/'stdout.txt').open('w') as log:
                result = subprocess.run(call, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=90)
            (case/'environment.json').write_text(json.dumps(dict(command=call,exit_code=result.returncode),indent=2)+'\n')
            require((native/'capture.json').is_file(), 'control failed without observations: '+name)
            shutil.copy2(native/'capture.json',case/'capture.json')
            data = read(case/'capture.json')
            if data['frames']: shutil.copy2(native/'frames'/data['frames'][-1]['file'],case/'last.png')
            source['artifacts']={str(p.relative_to(folder)):sha(p) for p in sorted(folder.rglob('*')) if p.is_file() and p.name!='source.json'}
            (folder/'source.json').write_text(json.dumps(source,indent=2)+'\n')
            require(result.returncode == 2, 'control unexpectedly succeeded: '+name)
    print(json.dumps(verify_controls(folder),indent=2))


def main() -> int:
    """Запускает нативную съёмку только явно; обычная проверка работает офлайн."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('capture','verify','capture-controls','verify-controls'))
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        folder = (args.output or REPORT/('controls' if 'controls' in args.action else 'native')).resolve()
        if args.action == 'capture': capture(folder)
        elif args.action == 'capture-controls': capture_controls(folder)
        elif args.action == 'verify-controls': print(json.dumps(verify_controls(folder),indent=2))
        else: print(json.dumps(verify(folder), indent=2))
        return 0
    except (ValueError, KeyError, OSError, TypeError, IndexError, subprocess.SubprocessError, StopIteration) as error:
        print('MOTION REJECTED: '+str(error))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
