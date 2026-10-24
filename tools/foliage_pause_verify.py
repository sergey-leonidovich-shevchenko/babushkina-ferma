#!/usr/bin/env python3
"""Independently verify the fixed native VFOLIAGE-009 pause campaign."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import re
import subprocess
import tarfile
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'docs/reports/visual-overhaul/vfoliage-009'
MODES = ['inventory', 'journal', 'hero_menu', 'world_map', 'pause', 'settings',
         'confirmation', 'focus', 'suspended', 'focus_inventory', 'editor', 'cabinet', 'storage']
STAGES = ['before', 'entered', 'held', 'resumed1', 'resumed12']
COLORS = [(255, 0, 0, 255), (0, 255, 0, 255), (0, 0, 255, 255),
          (255, 255, 0, 255), (0, 255, 255, 255)]
DT = 1 / 60


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def close(a: float, b: float) -> bool:
    return math.isfinite(a) and math.isfinite(b) and abs(a - b) < 1e-10


def snapshot(data: dict, digest: str) -> dict:
    raw = data['snapshots'].get(digest)
    require(isinstance(raw, str) and sha(raw.encode()) == digest, 'snapshot SHA')
    return json.loads(raw)


def metadata(data: dict, width: int) -> dict:
    require(data['task'] == 'VFOLIAGE-009' and data['complete'] and not data['errors'], 'incomplete capture')
    require(data['display'] == 'macOS' and data['engine']['hash'] == 'a13da4feb8d8aefc283c3763d33a2f170a18d541', 'actual native engine')
    require(data['requested_width'] == width, 'requested window')
    require(data['profile'].startswith('Codex-VFOLIAGE-009-'), 'isolated profile')
    require(data['hardware_input_accepted'] is False and data['performance_eligible'] is False, 'false admission')
    rows = data['records']
    require([(r['mode'], r['stage']) for r in rows] == [(m, s) for m in MODES for s in STAGES], 'matrix coverage/order')
    for digest in data['snapshots']:
        snapshot(data, digest)
    states = {}
    last_frame = -1
    for row in rows:
        tag = row['mode'] + '/' + row['stage']
        require(row['tag'] == tag and row['marker_fresh'] and row['present_complete'], 'present/tag')
        require(row['visible'] and row['focused'], 'actual visible/focused window')
        if 'windowed' in row:
            require(row['windowed'], 'actual window mode')
        require(row['frames_before'] >= last_frame and row['frames_after'] >= row['frames_before'] + 2, 'actual present frames')
        last_frame = row['frames_after']
        size = [width, width * 9 // 16]
        require(row['window_size'] == size and row['image_size'] == size, 'window dimensions')
        require(row['target_size'] == [768, 384], 'target dimensions')
        require(row['marker_rgba8'] == list(COLORS[STAGES.index(row['stage'])]), 'phase color')
        require(row['window'] == tag + '/window.png' and row['target'] == tag + '/target.png', 'image path')
        require(row['state_sha'] == row['state_after_sha'] and row['save_sha'] == row['save_after_sha'], 'render mutated state/save')
        state = snapshot(data, row['state_sha'])
        snapshot(data, row['save_sha'])
        stats = state['statistics']
        require(stats['owners'] == 1 and stats['groups'] == 2 and stats['builds'] == 1, 'bounded foliage owner/target')
        require(0 <= stats['recovery_active'] <= stats['recovery_limit'] == 64, 'bounded recovery')
        fallback = row['mode'] in ['editor', 'cabinet', 'storage'] and row['stage'] in ['entered', 'held']
        require(state['zoom'] == (1.0 if fallback else 1.2), 'fixed zoom/fallback')
        require(stats['active'] == (0 if fallback else 5), 'active/fallback policy')
        if fallback:
            require(stats['recovery_active'] == 0, 'fallback recovery cleanup')
        require(row['game_draws'], 'missing actual game draw')
        for draw in row['game_draws']:
            require(draw['tag'] == tag and draw['save_equal'] and
                    draw['save_before_sha'] == draw['save_after_sha'] == row['save_sha'] and
                    close(draw['seconds'], state['seconds']), 'actual draw state/save')
        for draw in row['group_draws']:
            require(draw['name'] in ['reeds', 'grass'] and close(draw['seconds'], state['seconds']), 'actual shader draw')
            require(draw['indices'] == (list(range(6)) if draw['name'] == 'reeds' else [6, 7]), 'actual shader instances')
        states[(row['mode'], row['stage'])] = state
    indexed = {(r['mode'], r['stage']): r for r in rows}
    for mode in MODES:
        before, entered, held, first, resumed = [states[(mode, stage)] for stage in STAGES]
        a, b = indexed[(mode, 'entered')], indexed[(mode, 'held')]
        require(a['state_sha'] == b['state_sha'] and a['save_sha'] == b['save_sha'], 'paused state/save changed')
        require(close(entered['seconds'], before['seconds']), 'entry advanced clock')
        samples = b['paused_samples']
        require(len(samples) == 36 and [s['tick'] for s in samples] == list(range(1, 37)), 'paused sample coverage')
        for sample in samples:
            require(close(sample['delta'], DT) and close(sample['seconds'], entered['seconds']) and
                    sample['visual_equal'] and sample['save_equal'] and
                    sample['state_sha'] == a['state_sha'] and sample['save_sha'] == a['save_sha'], 'paused sample changed')
        require(close(first['seconds'], held['seconds'] + DT) and
                close(resumed['seconds'], held['seconds'] + 12 * DT), 'resume clock debt')
        require(first['world'] == resumed['world'] == 'overworld', 'resume world')
        if mode not in ['editor', 'cabinet', 'storage']:
            require(all(s['camera'] == before['camera'] and s['player'] == before['player'] for s in [entered, held, first, resumed]), 'fixed camera/player')
        if mode in ['cabinet', 'storage']:
            require(entered['world'] == 'cottage_interior', 'existing household UI')
    return indexed


def pixels(folder: Path, data: dict, width: int) -> int:
    rows = metadata(data, width)
    targets = {}
    windows = {}
    for (mode, stage), row in rows.items():
        with Image.open(folder / row['window']) as file:
            image = file.convert('RGBA')
        require(list(image.size) == row['image_size'], 'actual PNG window size')
        color = COLORS[STAGES.index(stage)]
        require(any(image.getpixel((16, y)) == color for y in range(64)), 'actual phase pixels')
        # Crop the QA-only six-pixel phase stripe; the UI itself must also have arrived.
        windows[(mode, stage)] = image.crop((0, 64, width, image.height)).tobytes()
        with Image.open(folder / row['target']) as file:
            image = file.convert('RGBA')
        require(list(image.size) == row['target_size'], 'actual PNG target size')
        targets[(mode, stage)] = image.tobytes()
    for mode in MODES:
        require(targets[(mode, 'entered')] == targets[(mode, 'held')], 'paused target RGBA changed')
        if mode not in ['focus', 'suspended', 'editor', 'cabinet', 'storage']:
            require(windows[(mode, 'before')] != windows[(mode, 'entered')], 'stale UI pixels')
        if mode not in ['editor', 'cabinet', 'storage']:
            require(targets[(mode, 'held')] != targets[(mode, 'resumed12')], 'target did not resume')
    return len(rows) * 2


def provenance(output: Path, plan: dict, plan_file: Path) -> dict:
    source = load(output / 'source.json')
    require(source['complete'] and source['task'] == 'VFOLIAGE-009', 'incomplete source')
    require(source['base_commit'] == plan['base_commit'], 'base commit')
    require(source['plan_sha256'] == sha((output / 'plan-copy.json').read_bytes()) == sha(plan_file.read_bytes()), 'plan SHA')
    require(source['sources'] == plan['sources'], 'declared sources')
    require([r['width'] for r in source['runs']] == [1152, 1280], 'native run coverage')
    require(len({r['profile'] for r in source['runs']}) == 2, 'unique native profiles')
    for run in source['runs']:
        require(run['wrapper_exit'] == 0 and not run['timeout'] and not run['engine_errors'] and
                run['capture_complete'] and not run['capture_errors'], 'native run failure')
        require(0 < run['after']['utc'] - run['before']['utc'] < 240, 'bounded native timestamps')
        folder = output / str(run['width'])
        require(load(folder / 'environment.json') == run, 'environment identity')
        require(load(folder / 'native/capture.json')['profile'] == run['profile'], 'capture profile identity')
        log = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', (folder / 'engine.txt').read_text())
        require(not re.search(r'^\s*(?:ERROR:|SCRIPT ERROR:)|Parse Error', log, re.M), 'engine log error')
    actual = {str(p.relative_to(output)): sha(p.read_bytes()) for p in output.rglob('*') if p.is_file() and p.name != 'source.json'}
    require(actual == source['artifacts'], 'artifact SHA/coverage')
    return source


def inputs(report: Path, plan: dict, capsule_name: str = 'inputs-focused.zip') -> None:
    runtime_paths = ['scripts', 'main.tscn', 'project.godot', 'assets/game/environment/village_ambient_atlas_v1.png']
    raw = subprocess.check_output(['git', 'archive', plan['base_commit'], *runtime_paths], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(raw)) as base:
        historical = {m.name: base.extractfile(m).read() for m in base.getmembers() if m.isfile()}
    with zipfile.ZipFile(report / capsule_name) as archive:
        require(set(archive.namelist()) == set(plan['sources']), 'source capsule coverage')
        for name, digest in plan['sources'].items():
            require(sha(archive.read(name)) == digest, 'source capsule SHA: ' + name)
            if name in historical:
                expected = historical[name]
                if name == 'project.godot':
                    expected = re.sub(rb'(?m)^config/version="[^"]*"$',
                                      b'config/version="' + plan['candidate_version'].encode() + b'"', expected)
                require(archive.read(name) == expected, 'production source differs from base: ' + name)


def verify(output: Path = REPORT / 'native-windowed', plan_file: Path = REPORT / 'plan-windowed.json') -> dict:
    plan = load(plan_file)
    suffix = plan_file.stem.removeprefix('plan')
    require(plan['modes'] == MODES and plan['stages'] == STAGES and plan['widths'] == [1152, 1280], 'fixed plan')
    require(sha((REPORT / plan.get('plan_text_file', 'PLAN' + suffix + '.md')).read_bytes()) == plan['plan_text_sha256'], 'plan text SHA')
    if 'supersedes_plan_sha256' in plan:
        require(sha((REPORT / plan.get('supersedes_plan_file', 'plan.json')).read_bytes()) == plan['supersedes_plan_sha256'], 'previous plan SHA')
    inputs(REPORT, plan, plan.get('source_capsule_file', 'inputs' + suffix + '.zip'))
    provenance(output, plan, plan_file)
    count = 0
    for width in [1152, 1280]:
        folder = output / str(width) / 'native'
        data = load(folder / 'capture.json')
        if plan.get('startup_geometry_required'):
            geometry(data, width)
            require(all(r.get('windowed') is True for r in data['records']), 'missing actual window mode')
        count += pixels(folder, data, width)
    return {'task': 'VFOLIAGE-009', 'native_states': count // 2, 'png': count,
            'paused_samples': 13 * 36 * 2, 'hardware_input_accepted': False, 'performance_eligible': False}


def geometry(data: dict, width: int) -> None:
    probes = data.get('startup_geometry', [])
    require(len(probes) >= 2, 'startup geometry missing')
    require(all(0 <= p['elapsed_ms'] < 7000 for p in probes), 'startup deadline')
    require(all(a['elapsed_ms'] <= b['elapsed_ms'] for a, b in zip(probes, probes[1:])), 'startup timestamps')
    size = [width, width * 9 // 16]
    tail = []
    for probe in reversed(probes):
        if probe['elapsed_ms'] < 1500 or not (probe['windowed'] and probe['window'] == probe['image'] == size):
            break
        tail.append(probe)
    require(len(tail) >= 2 and tail[0]['elapsed_ms'] - tail[-1]['elapsed_ms'] >= 500, 'startup stable geometry duration')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPORT / 'native-windowed')
    parser.add_argument('--plan', type=Path, default=REPORT / 'plan-windowed.json')
    args = parser.parse_args()
    print(json.dumps(verify(args.output, args.plan), ensure_ascii=False))
