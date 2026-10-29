#!/usr/bin/env python3
"""VCAMERA-002: native paired camera comparison, signed evidence and offline rejection."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
from common.git import git_environment
import tempfile
import uuid

from PIL import Image, ImageChops, ImageStat

from common.paths import project_root
from common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
REPORT = ROOT / 'docs/reports/visual-overhaul/vcamera-002'
CASES = {'base': [1152, 648], 'full-hd': [1920, 1080], 'retina-2x': [2304, 1296]}
MODES = {'rounded': True, 'fractional': False}
SOURCES = ['project.godot', 'scripts/systems/camera_system.gd', 'scripts/game_core.gd',
           'scripts/core/game_loop.gd', 'scripts/core/game_input_router.gd',
           'scripts/systems/animation_renderer.gd', 'scripts/systems/hero_visual_system.gd',
           'scripts/systems/presentation_system.gd', 'scripts/systems/navigation_system.gd',
           'scripts/systems/player_system.gd', 'scripts/systems/ui_scale_system.gd',
           'scripts/systems/fence_system.gd', 'tools/visual_camera_points.gd',
           'tools/camera_quantization_capture.gd', 'tools/camera_quantization.py',
           'tools/encode_coordinate_video.swift',
           'docs/reports/visual-overhaul/vcamera-002/legacy_camera_system.gd']


def read(path):
    """Reads diagnostic data without evaluating it."""
    return json.loads(Path(path).read_text())


def sha(path):
    """Binds a report to the exact bytes of its source or media."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    """Rejects a failed condition with a concrete cause."""
    if not condition:
        raise ValueError(message)


def near(actual, expected, tolerance=0.001):
    """Accepts finite numeric pairs within engine arithmetic precision."""
    return (isinstance(actual, list) and len(actual) == 2 and
            all(type(x) in (float, int) and math.isfinite(x) for x in actual) and
            math.dist(actual, expected) <= tolerance)


def validate_run(data, size, snap, retina=False):
    """Checks full diagonal motion, actual camera/feet/pointer, native conditions and clock."""
    require(data.get('schema') == 1 and data.get('kind') == 'quantization-native', 'native capture required')
    require(data.get('performance_eligible') is False and not data.get('errors'), 'diagnostic classification or native errors')
    require(data.get('display_server') == 'macOS' and data.get('renderer') == 'opengl3', 'native macOS OpenGL required')
    require(data.get('snap') is snap and data.get('requested') == size, 'wrong comparison variant/window')
    require(str(data.get('profile', '')).startswith('Codex-VCAMERA-002-'), 'isolated profile required')
    require(data.get('fps') == 60 and data.get('manual_steps') == 358, 'controlled simulation clock differs')
    require(data.get('content_scale_mode') == 1 and data.get('content_scale_size') == [1152, 648] and data.get('content_scale_factor') == 1, 'project scaling changed')
    initial = data.get('initial', {})
    require(initial.get('window') == size and initial.get('root') == size and initial.get('focused') is True and initial.get('mode') == 0, 'initial native window/focus invalid')
    if retina:
        require(data.get('hidpi') is True and data.get('screen_scale', 0) >= 2, 'Retina not observed')
    rows = data.get('frames', [])
    require(len(rows) == 360, 'incomplete two-scene recording')
    expected_inputs = []
    for start, end, key in [(0, 180, 'D'), (180, 360, 'A')]:
        expected_inputs += [{'after_rows': start, 'key': k, 'pressed': True} for k in [key, 'S']]
        expected_inputs += [{'after_rows': end, 'key': k, 'pressed': False} for k in [key, 'S']]
    require(data.get('inputs') == expected_inputs, 'routed diagonal input edges missing')
    scale = size[0] / 1152
    for i, row in enumerate(rows):
        stage, frame = divmod(i, 180)
        require(row.get('index') == i and row.get('stage') == stage and row.get('frame') == frame, 'frame order or missing scene cut')
        require(row.get('location') == 'overworld' and row.get('walkable') is True and row.get('automatic_physics') is False, 'location/collision or uncontrolled physics')
        require(row.get('window') == size and row.get('readback') == size and row.get('visible') == [1152, 648] and row.get('focused') is True and row.get('window_mode') == 0, 'window/readback/focus')
        require(row.get('foot_pixel') is True and row.get('fiducial') is True, 'native marker pixels missing')
        require(near(row.get('stretch_scale'), [scale, scale]), 'stretch scale')
        require(abs(row.get('minutes', 0) - (720 + frame / 60)) < 1e-5 and abs(row.get('delta', -1) - (1/60 if frame else 0)) < 1e-9, 'world clock stopped or double-stepped')
        player, camera = row['player'], row['camera']
        require(near(player, player), 'nonfinite player')
        raw = [max(0, min(1248, player[0] - 576)), max(0, min(720, player[1] - 324))]
        expected = [math.floor(x+0.5) for x in raw] if snap else raw
        require(near(camera, expected) and near(row.get('unsnapped'), raw), 'camera quantization differs')
        require(near(row.get('background'), [-x for x in camera]), 'background offset mismatch')
        require(near(row.get('foot_world'), player) and near(row.get('foot_canvas'), [player[j] - camera[j] for j in range(2)]), 'rendered feet/physics mismatch')
        require(near(row.get('movement'), [(1 if stage == 0 else -1)/math.sqrt(2), 1/math.sqrt(2)]), 'diagonal key direction differs')
        if frame == 0:
            require(near(player, [562.25 if stage == 0 else 60.25, 672.25]), 'prepared scene starts elsewhere')
        else:
            before = rows[i-1]['player']
            require(0 <= player[1] - before[1] <= 0.301 and math.dist(player, before) <= 0.301, 'teleport or invalid physical step')
            if stage == 0:
                require(near(player, [562.25 + frame*18/math.sqrt(2)/60, 672.25 + frame*18/math.sqrt(2)/60], 0.01), 'slow diagonal route differs')
        pointer = ([600 + (-0.125 if frame % 2 == 0 else 0.125), 696.125] if stage == 0 else [[0.125, 23.875, 24.125][frame % 3], 720.125])
        logical = [pointer[j] - camera[j] for j in range(2)]
        require(near(row.get('pointer_world'), pointer) and near(row.get('pointer_canvas'), logical) and near(row.get('pointer_received'), logical), 'pointer inverse differs')
        require(near(row.get('pointer_window'), [x*scale for x in logical]), 'double DPI or wrong window mapping')
        cell = [math.floor(x/24) for x in pointer]
        require(row.get('pointer_cell') == cell and near(row.get('cell_origin_canvas'), [cell[j]*24 - camera[j] for j in range(2)]), 'pointer cell drift')
    require(rows[179]['camera'][0] > 20 and 40 <= rows[359]['player'][0] < 40.3, 'follow threshold/physical edge not covered')
    tracking = rows[90:180]
    deviations = [[r['foot_canvas'][j] - [576, 324][j] for r in tracking] for j in range(2)]
    peak = [max(axis) - min(axis) for axis in deviations]
    stalled = sum(abs(rows[i]['camera'][1] - rows[i-1]['camera'][1]) < 1e-7 for i in range(1, 180))
    maximum = max(abs(rows[i]['camera'][1] - rows[i-1]['camera'][1]) for i in range(1, 180))
    return {'center_peak_to_peak_logical': peak, 'center_peak_to_peak_framebuffer': [v*scale for v in peak],
            'stalled_camera_y_steps': stalled, 'max_camera_y_step_logical': maximum}


def manifest(folder, source):
    """Keeps incomplete attempts explicit and signs all retained evidence."""
    source['artifacts'] = {str(p.relative_to(folder)): sha(p) for p in sorted(folder.rglob('*'))
                           if p.is_file() and p.name != 'source.json' and 'instrumentation' not in p.parts}
    (folder/'source.json').write_text(json.dumps(source, indent=2)+'\n')


def verify(folder):
    """Checks the native six-case pair, source archives, actual PNG/media and observed jitter metrics."""
    require((folder/'source.json').is_file(), 'native comparison packet missing; VCAMERA-002 remains unaccepted')
    source = read(folder/'source.json')
    require(source.get('complete') is True and source.get('performance_eligible') is False and re.fullmatch('[a-f0-9]{40}', source.get('base_commit', '')), 'incomplete provenance')
    require(set(source.get('sources', {})) == set(SOURCES), 'incomplete source manifest')
    for name, digest in source['sources'].items():
        require(sha(folder/'instrumentation'/name) == digest, 'archived source hash: '+name)
    files = {str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name != 'source.json' and 'instrumentation' not in p.parts}
    require(files == set(source['artifacts']), 'artifact coverage differs')
    for name, digest in source['artifacts'].items():
        require('..' not in Path(name).parts and not Path(name).is_absolute() and sha(folder/name) == digest, 'artifact hash: '+name)
    metrics, profiles, pids = {}, [], []
    for case, size in CASES.items():
        pair = []
        for mode, snap in MODES.items():
            name = case+'-'+mode
            path = folder/name
            data = read(path/'capture.json')
            metrics[name] = validate_run(data, size, snap, case == 'retina-2x')
            pair.append(data['frames']); profiles.append(data['profile']); pids.append(data['pid'])
            env = read(path/'environment.json')
            require(env['exit_code'] == 0 and '--headless' not in env['command'], 'native command failed')
            video = read(path/'walk.json')
            require([video['width'], video['height']] == size and video['frames'] == 360 and video['fps'] == 60 and abs(video['duration'] - 6) < 0.01, 'video metadata')
            require((path/'walk.mp4').read_bytes()[4:8] == b'ftyp' and (path/'walk.mp4').stat().st_size < 8*1024*1024, 'bounded MP4 required')
            for frame in [0, 180, 359]:
                image = Image.open(path/('frame-%04d.png' % frame)).convert('RGB')
                require(list(image.size) == size, 'native PNG dimensions')
                x, y = round(20*size[0]/1152), round(164*size[1]/648)
                require(sum(abs(a-b) for a,b in zip(image.getpixel((x,y)), [255,0,255])) < 10, 'native PNG fiducial')
            first = Image.open(path/'frame-0000.png').convert('RGB')
            decoded = Image.open(path/'walk.decoded.png').convert('RGB')
            require(decoded.size == first.size and sum(ImageStat.Stat(ImageChops.difference(first, decoded)).mean)/3 < 6, 'video first-frame orientation/content')
        require(all(a['player'] == b['player'] and a['minutes'] == b['minutes'] and a['facing'] == b['facing'] and near(a['pointer_world'], b['pointer_world']) for a,b in zip(*pair)), 'physics/pointer differs between policies')
    require(len(set(profiles)) == 6 and len(set(pids)) == 6, 'independent native processes required')
    return metrics


def capture(folder):
    """Records each native variant in a new profile and encodes after the game exits."""
    require(not folder.exists(), 'fresh output required')
    folder.mkdir(parents=True)
    source = {'schema': 1, 'task': 'VCAMERA-002', 'performance_eligible': False, 'complete': False,
              'base_commit': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True, env=git_environment()).strip(),
              'sources': {p:sha(ROOT/p) for p in SOURCES}, 'artifacts': {}}
    for p in SOURCES:
        target = folder/'instrumentation'/p; target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(ROOT/p,target)
    manifest(folder,source)
    with tempfile.TemporaryDirectory(prefix='farm-quantization-') as raw:
        temporary = Path(raw)
        for case, size in CASES.items():
            for mode, snap in MODES.items():
                name = case+'-'+mode
                print('CAPTURE '+name,flush=True)
                target = folder/name; target.mkdir()
                native = temporary/name
                cmd = [str(ROOT/'tools/Godot.app/Contents/MacOS/Godot'), '--path', str(ROOT), '--windowed', '--audio-driver','Dummy',
                       '--log-file',str(target/'engine.log'),'--script','res://tools/camera_quantization_capture.gd','--',
                       '--output='+str(native),'--profile=Codex-VCAMERA-002-'+uuid.uuid4().hex,'--size=%dx%d'%tuple(size)]
                if snap: cmd.append('--snap')
                launch = ['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args',*cmd[1:]]
                with (target/'stdout.txt').open('w') as log:
                    result = subprocess.run(launch,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600)
                env = {'command':launch,'exit_code':result.returncode,'exit_code_scope':'LaunchServices launcher; engine completion checked in capture.json'}
                (target/'environment.json').write_text(json.dumps(env,indent=2)+'\n')
                if (native/'capture.json').exists(): shutil.copy2(native/'capture.json',target/'capture.json')
                for frame in [0, 180, 359]:
                    image = native/('frames/%04d.png'%frame)
                    if image.exists(): shutil.copy2(image,target/('frame-%04d.png'%frame))
                manifest(folder,source)
                engine = (target/'engine.log').read_text() if (target/'engine.log').exists() else ''
                require(result.returncode == 0 and engine and 'ERROR:' not in engine and 'ERROR:' not in (target/'stdout.txt').read_text(), 'native error: '+name)
                validate_run(read(target/'capture.json'),size,snap,case=='retina-2x')
                environment = dict(os.environ,CLANG_MODULE_CACHE_PATH=str(temporary/'clang-cache'),SWIFT_MODULECACHE_PATH=str(temporary/'swift-cache'))
                with (target/'encoder.txt').open('w') as log:
                    subprocess.run(['swift',str(ROOT/'tools/encode_coordinate_video.swift'),str(native/'frames'),str(target/'walk.mp4'),'60','4000000'],env=environment,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=240)
                shutil.rmtree(native)
                manifest(folder,source)
    source['complete'] = True; manifest(folder,source)
    metrics = verify(folder)
    (folder.parent/'metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
    print('VALID_CAMERA_QUANTIZATION',flush=True)


def main():
    """Collects new evidence or verifies the frozen historical set without a display."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['capture','verify'])
    parser.add_argument('--output',type=Path,default=REPORT/'native')
    args = parser.parse_args()
    try:
        if args.command == 'capture': capture(args.output.resolve())
        else: print(json.dumps(verify(args.output.resolve()),indent=2))
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(str(error)) from error


if __name__ == '__main__':
    main()
