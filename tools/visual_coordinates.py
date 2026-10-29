#!/usr/bin/env python3
"""Снимает нативный контракт координат и проверяет реальные кадры, ввод и матрицы."""
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
from common.git import git_environment
import tempfile
import uuid

from common.paths import project_root
from common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
REPORT = ROOT / 'docs/reports/visual-overhaul/vcamera-001/native'
CASES = {'base': [1152, 648], 'full-hd': [1920, 1080], 'retina-2x': [2304, 1296], 'letterbox': [1024, 768]}
SOURCES = ['project.godot', 'scripts/systems/camera_system.gd', 'scripts/systems/animation_renderer.gd',
           'scripts/systems/hero_visual_system.gd', 'scripts/systems/presentation_system.gd',
           'scripts/systems/ui_scale_system.gd', 'scripts/game_core.gd', 'scripts/game_context.gd',
           'scripts/core/game_input_router.gd', 'scripts/systems/fence_system.gd',
           'tools/visual_coordinates_capture.gd', 'tools/encode_coordinate_video.swift']


def read(path: Path) -> dict:
    """Читает данные проверки без исполнения содержимого."""
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    """Привязывает паспорт к точным байтам артефакта."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def near(a, b, tolerance=0.001) -> bool:
    """Сравнивает конечные числовые пары с допуском арифметики движка."""
    return isinstance(a, list) and len(a) == 2 and all(isinstance(x, (int, float)) and math.isfinite(x) for x in a) and math.dist(a, b) <= tolerance


def capture_errors(data: dict, size: list[int], retina=False) -> list[str]:
    """Отклоняет неверный ввод, двойной масштаб, сдвиг стоп и подмену нативного запуска."""
    errors = []
    if data.get('schema') != 1 or data.get('kind') != 'coordinate-contract-native' or data.get('performance_eligible') is not False: errors.append('classification')
    if data.get('display_server') in [None, 'headless'] or data.get('renderer') != 'opengl3': errors.append('native renderer')
    if data.get('errors') or not str(data.get('profile', '')).startswith('Codex-VCAMERA-001-'): errors.append('native faults/profile')
    if data.get('content_scale_mode') != 1 or data.get('content_scale_size') != [1152, 648] or data.get('content_scale_factor') != 1: errors.append('project scaling')
    if retina and (data.get('screen_scale', 0) < 2 or data.get('hidpi') is not True): errors.append('Retina not observed')
    rows = data.get('frames', [])
    if len(rows) != 96 or data.get('fps') != 24: errors.append('motion coverage'); return errors
    scale = min(size[0]/1152, size[1]/648)
    offset = [(size[0]-1152*scale)/2, (size[1]-648*scale)/2]
    target = [round(1152*scale), round(648*scale)]
    for index, row in enumerate(rows):
        required = {'player','camera','foot_world','foot_canvas','foot_window','foot_framebuffer','pointer_requested','pointer_window','pointer_received','pointer_world','pointer_cell'}
        if not required <= row.keys() or any(not near(row[k], row[k]) for k in required): errors.append('missing/nonfinite geometry'); continue
        if row.get('frame') != index or abs(row.get('time', -100)-index/24) > 0.0001: errors.append('timeline')
        if row.get('window') != size or row.get('readback') != target or row.get('visible') != [1152, 648] or row.get('window_mode') != 0 or row.get('focused') is not True: errors.append('window/framebuffer/focus')
        if row.get('fiducial') is not True or row.get('foot_pixel') is not True: errors.append('real marker pixel')
        player = [556.25+index*0.75, 672.25]
        camera = [math.floor(max(player[0]-576, 0)+0.5), 348]
        if not near(row.get('player'), player) or not near(row.get('camera'), camera): errors.append('player/camera route')
        if not near(row.get('background'), [-v for v in camera]): errors.append('background origin')
        if not near(row.get('foot_world'), player) or not near(row.get('foot_canvas'), [player[i]-camera[i] for i in range(2)]): errors.append('feet/physics')
        pointer = row['pointer_requested']
        if not near(row.get('pointer_received'), pointer): errors.append('engine pointer inverse')
        world = [pointer[i]+camera[i] for i in range(2)]
        if not near(row.get('pointer_world'), world) or row.get('pointer_cell') != [math.floor(v/24) for v in world]: errors.append('pointer grid')
        for src, dst in [('pointer_requested','pointer_window'), ('foot_canvas','foot_window')]:
            if not near(row.get(dst), [offset[i]+row[src][i]*scale for i in range(2)]): errors.append('physical mapping')
        if not near(row.get('foot_framebuffer'), [v*scale for v in row['foot_canvas']]): errors.append('readback mapping')
        matrix = row.get('final_transform')
        if not isinstance(matrix, list) or len(matrix) != 3 or not near(matrix[0], [scale,0]) or not near(matrix[1], [0,scale]) or not near(matrix[2], offset): errors.append('window matrix')
    return sorted(set(errors))


def verify(folder: Path, current_sources=False) -> list[str]:
    """Проверяет четыре нативных запуска, видео, исходные PNG и паспорт без заявления о FPS."""
    from PIL import Image, ImageChops, ImageStat
    errors = []
    source = read(folder/'source.json')
    if source.get('performance_eligible') is not False or not re.fullmatch('[0-9a-f]{40}', source.get('base_commit', '')): errors.append('provenance')
    required = {f'{name}/{file}' for name in CASES for file in ['capture.json','frame-0000.png','walk.mp4','walk.json','walk.decoded.png','stdout.txt','encoder.txt','engine.log']}
    required |= {'base/frame-0048.png','base/frame-0095.png'}
    if set(source.get('artifacts', {})) != required or set(source.get('sources', {})) != set(SOURCES): errors.append('incomplete provenance manifest')
    profiles = []
    for name, size in CASES.items():
        case = folder/name
        report = read(case/'capture.json')
        errors += [name+': '+e for e in capture_errors(report, size, name == 'retina-2x')]
        profiles.append(report.get('profile'))
        video = read(case/'walk.json')
        target = report['frames'][0]['readback']
        if [video.get('width'), video.get('height')] != target or video.get('frames') != 96 or video.get('fps') != 24 or abs(video.get('duration', 0)-4) > 0.01: errors.append(name+': video metadata')
        first = Image.open(case/'frame-0000.png').convert('RGB')
        decoded = Image.open(case/'walk.decoded.png').convert('RGB')
        if list(first.size) != target or decoded.size != first.size: errors.append(name+': PNG size'); continue
        # Декодирование H.264 допускает потери цвета, но переворот или другой кадр дают большой отказ.
        difference = sum(ImageStat.Stat(ImageChops.difference(first, decoded)).mean)/3
        if difference > 6: errors.append(name+': video orientation/content')
        transform = report['frames'][0]['stretch_transform']
        x = round(transform[0][0]*20+transform[2][0]); y = round(transform[1][1]*164+transform[2][1])
        if sum(abs(a-b) for a,b in zip(first.getpixel((x,y)), (255,0,255))) > 10: errors.append(name+': PNG fiducial position')
    if len(set(profiles)) != len(CASES): errors.append('profiles reused')
    for filename, sha in source.get('artifacts', {}).items():
        file = folder/filename
        if '..' in Path(filename).parts or not file.is_file() or digest(file) != sha: errors.append('artifact hash: '+filename)
    for path, sha in source.get('sources', {}).items():
        if not re.fullmatch('[0-9a-f]{64}', sha) or (current_sources and digest(ROOT/path) != sha): errors.append('source hash: '+path)
    return errors


def capture(folder: Path) -> None:
    """Создаёт новые профили и записывает исходные кадры; сжатие выполняется только после завершения игры."""
    if folder.exists(): raise ValueError('Нужен новый каталог, прежние доказательства не перезаписываются')
    folder.mkdir(parents=True)
    godot = Path(os.environ.get('FARM_GODOT_BIN', ROOT/'tools/Godot.app/Contents/MacOS/Godot'))
    source = {'schema': 1, 'task': 'VCAMERA-001', 'performance_eligible': False,
              'base_commit': subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True, env=git_environment()).strip(),
              'worktree_patch': subprocess.check_output(['git','diff','--','scripts/systems/animation_renderer.gd'], cwd=ROOT, text=True, env=git_environment()),
              'sources': {path:digest(ROOT/path) for path in SOURCES}, 'artifacts': {}}
    (folder/'source.json').write_text(json.dumps(source, ensure_ascii=False, indent=2)+'\n')
    with tempfile.TemporaryDirectory(prefix='farm-coordinates-') as raw:
        temporary = Path(raw)
        for name, size in CASES.items():
            print('CAPTURE '+name, flush=True)
            case = folder/name; case.mkdir()
            native = temporary/name
            command = [str(godot), '--path', str(ROOT), '--windowed', '--audio-driver', 'Dummy', '--log-file', str(case/'engine.log'),
                       '--script','res://tools/visual_coordinates_capture.gd','--','--output='+str(native),
                       '--profile=Codex-VCAMERA-001-'+uuid.uuid4().hex, '--size=%dx%d'%tuple(size)]
            with (case/'stdout.txt').open('w') as log: result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            # Паспорт отказа сохраняется до остановки: неверный запуск нельзя скрыть успешным повтором.
            shutil.copy2(native/'capture.json', case/'capture.json')
            shutil.copy2(native/'frames/0000.png', case/'frame-0000.png')
            if result.returncode or 'ERROR:' in (case/'stdout.txt').read_text(): raise ValueError('Ошибка движка: '+name)
            if name == 'base':
                for frame in [48,95]: shutil.copy2(native/f'frames/{frame:04d}.png',case/f'frame-{frame:04d}.png')
            environment = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(temporary/'clang-cache'), SWIFT_MODULECACHE_PATH=str(temporary/'swift-cache'))
            with (case/'encoder.txt').open('w') as log:
                subprocess.run(['swift',str(ROOT/'tools/encode_coordinate_video.swift'),str(native/'frames'),str(case/'walk.mp4'),'24'], env=environment, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
    for file in sorted(folder.rglob('*')):
        if file.is_file() and file.name != 'source.json': source['artifacts'][str(file.relative_to(folder))] = digest(file)
    (folder/'source.json').write_text(json.dumps(source, ensure_ascii=False, indent=2)+'\n')
    errors = verify(folder, current_sources=True)
    if errors: raise ValueError(str(errors))
    print('COORDINATES: four native runs, four videos, pixel/input/source verification passed')


def main() -> None:
    """Выбирает новый захват либо проверку исторического набора."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['capture','verify'])
    parser.add_argument('--output', type=Path, default=REPORT)
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    if args.command == 'capture': capture(args.output.resolve())
    else:
        errors = verify(args.output.resolve(), args.current_sources)
        if errors: raise SystemExit('\n'.join(errors))
        print('COORDINATES: native transforms, pointer, feet, videos and artifact hashes valid')


if __name__ == '__main__': main()
