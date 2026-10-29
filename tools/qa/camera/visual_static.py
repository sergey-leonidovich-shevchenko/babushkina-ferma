#!/usr/bin/env python3
"""Воспроизводимый нативный эталон деревни; Pillow нужен только для сравнения PNG."""
from __future__ import annotations
from tools.assets.contracts.source_paths import current_source
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from tools.common.git import git_environment
import uuid
from tools.qa.camera.visual_camera import ROOT, REGISTRY, SIZE, FIELDS, read, digest

REPORT = ROOT / 'docs/reports/visual-overhaul/vbase-004'
KIND = 'static-village-effects-off'
PRESET = 'village-static-noon-1152-v1'
NAMES = ['effects-0', 'effects-1', 'hud-0', 'hud-1', 'clean-0', 'clean-1', 'hud-restored', 'restored-0', 'restored-1']
EFFECTS = ['water_overlays', 'ambient_motion', 'orchard_weather', 'atmosphere', 'action_feedback']


def capture_errors(data: dict) -> list[str]:
    """Сверяет реальный ракурс, состояния проходов, время и условия каждого прочитанного кадра."""
    errors = []
    if data.get('schema') != 1 or data.get('kind') != KIND or data.get('preset') != PRESET: errors.append('preset')
    if data.get('performance_eligible') is not False or data.get('simulation_frozen') is not True: errors.append('static classification')
    if data.get('display_server') in [None, 'headless'] or data.get('renderer') != 'opengl3': errors.append('native renderer')
    if data.get('errors'): errors.append('native errors')
    if data.get('disabled_effects') != EFFECTS or data.get('minimum_delay_ms') != 2500: errors.append('effect/time contract')
    frames = data.get('frames', [])
    if [r.get('image') for r in frames] != [n + '.png' for n in NAMES]: return errors + ['frame coverage/order']
    point = read(REGISTRY)['points'][0]
    for name, row in zip(NAMES, frames):
        if any(row.get(k) != point[k] for k in FIELDS): errors.append('camera/scene drift: ' + name)
        if row.get('walkable') != 'walkable' or row.get('physics_processing') is not False: errors.append('simulation')
        if row.get('static_mode') is not name.startswith(('hud', 'clean')) or row.get('hud') is not (not name.startswith('clean')): errors.append('render mode')
        state = row.get('conditions', {})
        if any(state.get(k) != SIZE for k in ['window', 'framebuffer', 'root']) or state.get('focused') is not True or state.get('mode') != 0 or state.get('valid') is not True: errors.append('window/framebuffer/focus')
    for first, second in [(0, 1), (2, 3), (4, 5), (7, 8)]:
        a, b = frames[first], frames[second]
        if b.get('ticks_ms', 0) - a.get('ticks_ms', 0) < 2500 or b.get('draw_frame', 0) - a.get('draw_frame', 0) < 12: errors.append('no elapsed redraws')
    return errors


def pixel_errors(images: dict, masks: list) -> list[str]:
    """Сравнивает декодированные пиксели; маски применяются только к проверке снятого HUD."""
    from PIL import ImageChops, ImageDraw
    errors = []
    for name, image in images.items():
        if list(image.size) != SIZE: errors.append('PNG dimensions: ' + name)
    if errors: return errors
    same = lambda a, b: ImageChops.difference(images[a], images[b]).getbbox() is None
    for a, b in [('hud-0', 'hud-1'), ('clean-0', 'clean-1'), ('hud-0', 'hud-restored')]:
        if not same(a, b): errors.append('static pixels changed: ' + a + '/' + b)
    for a, b in [('effects-0', 'effects-1'), ('restored-0', 'restored-1'), ('hud-0', 'clean-0')]:
        if same(a, b): errors.append('missing control difference: ' + a + '/' + b)
    # У фиксированного кадра допускается только верхний HUD, хотбар и подпись бабушки.
    if masks != [[0, 0, 1152, 140], [0, 560, 1152, 88], [518, 316, 69, 27]]:
        return errors + ['HUD masks']
    delta = ImageChops.difference(images['hud-0'], images['clean-0'])
    draw = ImageDraw.Draw(delta)
    for x, y, w, h in masks: draw.rectangle((x, y, x+w-1, y+h-1), fill=(0, 0, 0))
    if delta.getbbox(): errors.append('HUD toggle changed world pixels: ' + str(delta.getbbox()))
    return errors


def verify(folder: Path) -> list[str]:
    """Проверяет два независимых запуска, исходники и сохранённые изображения без доверия флагу успеха."""
    from PIL import Image, ImageChops
    source = read(folder / 'source.json'); errors = []; profiles = []; previous = None
    if source.get('kind') != KIND or source.get('performance_eligible') is not False or source.get('repeats') != 2: errors.append('source classification')
    if not re.fullmatch('[0-9a-f]{40}', source.get('commit', '')) or source.get('registry_sha256') != digest(REGISTRY): errors.append('source provenance')
    required = ['scripts/presentation/visual_reference_mode.gd', 'tools/visual_static_capture.gd', 'tools/visual_static.py', 'tools/visual_camera_points.gd']
    if any(not re.fullmatch('[0-9a-f]{64}', source.get('files', {}).get(n, '')) for n in required): errors.append('source hashes')
    for number in [1, 2]:
        run = folder / f'run-{number}'; data = read(run / 'capture.json'); errors += capture_errors(data); profiles.append(data.get('profile'))
        images = {}
        for name in NAMES:
            path = run / (name + '.png')
            with Image.open(path) as image: images[name] = image.convert('RGB')
            if source.get('images', {}).get(f'run-{number}/{path.name}') != digest(path): errors.append('PNG hash')
        errors += pixel_errors(images, data.get('hud_masks', []))
        if previous:
            for name in ['hud-0', 'clean-0']:
                if ImageChops.difference(previous[name], images[name]).getbbox(): errors.append('independent repeat differs: ' + name)
        previous = images
        if 'ERROR:' in (run / 'stdout.txt').read_text(): errors.append('engine errors')
    if len(set(profiles)) != 2 or any(not re.fullmatch(r'Codex-VBASE-004-[a-f0-9]{32}', str(p)) for p in profiles): errors.append('profiles reused/invalid')
    return errors


def capture(folder: Path) -> int:
    """Снимает две серии в новых процессах, сохраняя точные команды и хеши рабочего дерева."""
    folder.mkdir(parents=True, exist_ok=False)
    binary = os.environ.get('FARM_GODOT_BIN') or str(ROOT / 'tools/Godot.app/Contents/MacOS/Godot')
    if not Path(binary).is_file(): binary = shutil.which('godot') or binary
    git = lambda *args: subprocess.check_output(['git', *args], cwd=ROOT, text=True, env=git_environment()).strip()
    paths = ['project.godot', 'main.tscn', 'tools/visual_static.py', 'tools/visual_static_capture.gd', 'tools/visual_camera_points.gd']
    paths += [str(p.relative_to(ROOT)) for p in (ROOT / 'scripts').rglob('*.gd')]
    source = dict(kind=KIND, performance_eligible=False, repeats=2, commit=git('rev-parse', 'HEAD'), dirty=git('status', '--porcelain'),
                  registry_sha256=digest(REGISTRY), files={n: digest(current_source(ROOT, n)) for n in paths}, commands=[], images={})
    for number in [1, 2]:
        run = folder / f'run-{number}'; run.mkdir()
        command = [binary, '--path', str(ROOT), '--windowed', '--resolution', '1152x648', '--position', '80,80', '--rendering-method', 'gl_compatibility', '--log-file', str(run / 'engine.txt'), '--script', 'tools/qa/camera/visual_static_capture.gd', '--', f'--output={run}', '--profile=Codex-VBASE-004-' + uuid.uuid4().hex]
        source['commands'].append(command)
        (folder / 'source.json').write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n')
        print(f'Static capture {number}/2', flush=True)
        with (run / 'stdout.txt').open('w') as output:
            result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=150)
        if result.returncode or 'ERROR:' in (run / 'stdout.txt').read_text(): print(f'Rejected: {run}/stdout.txt'); return 2
        for path in run.glob('*.png'): source['images'][f'run-{number}/{path.name}'] = digest(path)
    (folder / 'source.json').write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n')
    errors = verify(folder)
    print('\n'.join(errors) if errors else 'STATIC: two independent pixel-identical HUD/clean pairs; live effects controls differ; not FPS')
    return 2 if errors else 0


def main() -> int:
    """Разделяет нативную съёмку и проверку уже сохранённых артефактов."""
    parser = argparse.ArgumentParser(); parser.add_argument('mode', choices=['capture', 'verify']); parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        if args.mode == 'capture':
            if args.output is None: parser.error('--output required')
            return capture(args.output.resolve())
        errors = verify((args.output or REPORT / 'native').resolve())
        print('\n'.join(errors) if errors else 'STATIC: valid native static-only reference')
        return 2 if errors else 0
    except (ValueError, OSError, KeyError, TypeError, ImportError, subprocess.SubprocessError) as error:
        print(f'STATIC rejected: {error}'); return 2


if __name__ == '__main__':
    raise SystemExit(main())
