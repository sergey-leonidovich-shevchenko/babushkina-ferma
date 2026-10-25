#!/usr/bin/env python3
"""Independently verify VFOLIAGE-010 completeness, native pixels, culling, bounds and coverage."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import tarfile

from PIL import Image
from foliage_visibility_collect import ROOT, REPORT, digest

ROUTES = ('left', 'right', 'top', 'bottom', 'chunk', 'bush')
MODES = ('normal', 'low', 'offscreen', 'returned')


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read(path: Path) -> dict:
    return json.loads(path.read_text())


class Frames:
    """Decode the primary lossless archive or still-present PNG; never treat a thumbnail/MP4 as an oracle."""
    def __init__(self, root: Path):
        self.root = root
        self.storage = read(root / 'storage.json') if (root / 'storage.json').exists() else None
        self.cache: dict[str, Image.Image] = {}
        if self.storage:
            require(self.storage['view_fps'] == 24 and self.storage['simulation_hz'] == 120 and self.storage['steps_per_frame'] == 2 and self.storage['slowdown'] == 2.5, 'video timing metadata')
            for name, expected in self.storage['archives'].items():
                require(digest(root / name) == expected, 'archive SHA: ' + name)

    def image(self, name: str) -> Image.Image:
        path = self.root / name
        if self.storage and name in self.storage['frames']:
            row = self.storage['frames'][name]
            key = row['archive']
            if key not in self.cache:
                self.cache[key] = Image.open(self.root / key)
            archive = self.cache[key]
            require(archive.n_frames == 36, 'archive frame count')
            archive.seek(row['frame'])
            result = archive.convert('RGBA')
            require(hashlib.sha256(result.tobytes()).hexdigest() == row['rgba_sha256'], 'archived RGBA SHA')
            if row['kept_png']:
                require(path.exists() and digest(path) == row['png_sha256'], 'retained PNG SHA')
                require(Image.open(path).convert('RGBA').tobytes() == result.tobytes(), 'PNG/archive exact decode')
            return result
        require(path.exists(), 'missing native PNG: ' + name)
        return Image.open(path).convert('RGBA')


def verify_pixels(frames: Frames, prefix: str, row: dict, width: int) -> None:
    """Check a real native image only after cheap structural checks; invalid metadata never forces full video decode."""
    image = frames.image(prefix + row['image'])
    require(image.size == tuple(row['size']) and hashlib.sha256(image.tobytes()).hexdigest() == row['rgba_sha256'], 'native RGBA SHA')
    marker = 0
    for bit in range(16):
        color = image.getpixel((int((bit * 72 + 36) * width / 1152), 2))
        require(color in ((255, 255, 255, 255), (255, 0, 255, 255)), 'invalid native marker pixel')
        marker |= (color == (255, 255, 255, 255)) << bit
    require(marker == row['serial'], 'stale native marker')


def verify(root: Path, check_sources: bool = True) -> dict:
    """Reject missing/changed evidence and independently recompute pixels, limits and motion endpoints."""
    source = read(root / 'source.json')
    plan = read(root / 'plan-copy.json')
    require(source['task'] == plan['task'] == 'VFOLIAGE-010' and source['complete'], 'incomplete source')
    require(digest(root / 'plan-copy.json') == source['plan_sha256'], 'plan SHA')
    require(plan['widths'] == [1152, 1280] and plan['routes'] == list(ROUTES) and plan['frames'] == 36 and plan['delta'] == 1 / 120 and plan['steps_per_frame'] == 2 and plan['travel'] == 126, 'predeclared matrix')
    require(source['base_commit'] == plan['base_commit'] == '2fa58d3719ff89f6f61a755e531d963807762ae9', 'base identity')
    if check_sources:
        for name, expected in plan['sources'].items():
            require(digest(ROOT / name) == expected, 'current source SHA: ' + name)
        require(not subprocess.check_output(['git', 'diff', plan['base_commit'], '--', 'scripts', 'assets/game', 'main.tscn'], cwd=ROOT), 'production unexpectedly changed')
        with tarfile.open(REPORT / 'sources.tar.gz') as capsule:
            for name, expected in plan['sources'].items():
                if not name.startswith('assets/'):
                    require(hashlib.sha256(capsule.extractfile(name).read()).hexdigest() == expected, 'source capsule: ' + name)
    frames = Frames(root)
    viewing = read(root / 'viewing.json')
    require(viewing['primary_pixel_oracle'] is False and [(c['width'], c['route']) for c in viewing['clips']] == [(w, r) for w in (1152, 1280) for r in ROUTES], 'viewing clips matrix')
    for clip in viewing['clips']:
        metadata = clip['metadata']
        require(metadata['frames'] == 36 and metadata['fps'] == 24 and metadata['duration'] == 1.5 and metadata['width'] == clip['width'] and metadata['height'] == clip['width'] * 9 // 16, 'viewing clip timing/dimensions')
        for name, expected in clip['files'].items():
            require(digest(root / name) == expected, 'viewing clip SHA')
    for name, expected in source['artifacts'].items():
        path = root / name
        if path.exists():
            require(digest(path) == expected, 'artifact SHA: ' + name)
        else:
            require(frames.storage and name in frames.storage['frames'] and frames.storage['frames'][name]['png_sha256'] == expected, 'missing original artifact: ' + name)
    require([r['width'] for r in source['runs']] == [1152, 1280], 'both native runs required')
    result = {'task': 'VFOLIAGE-010', 'windows': [], 'frames': 0, 'exact_pairs': 0, 'coverage_targets': 0, 'fps_admitted': False}
    for run in source['runs']:
        width = run['width']
        prefix = str(width) + '/native/'
        capture = read(root / prefix / 'capture.json')
        require(run['exit'] == 0 and not run['timeout'] and not run['engine_errors'] and run['capture_complete'] and not run['capture_errors'], 'failed native wrapper')
        require(capture['complete'] and not capture['errors'] and capture['display'] != 'headless' and capture['profile'] == run['profile'] and capture['width'] == width, 'native identity/completion')
        log = (root / str(width) / 'engine.txt').read_text()
        clean = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', log)
        require(not re.search(r'^\s*(ERROR:|SCRIPT ERROR:)|Parse Error', clean, re.M), 'engine errors in raw log')
        require('Compatibility' in log and 'OpenGL' in log, 'actual native rendering backend')
        probes = capture['startup']
        require(probes and probes[-1]['ms'] >= 2000 and probes[-1]['ms'] < 7000 and probes[-1]['focused'] and probes[-1]['windowed'] and probes[-1]['window'] == probes[-1]['image'] == [width, width * 9 // 16], 'native startup geometry')
        require([r['id'] for r in capture['routes']] == list(ROUTES), 'route identity/order')
        expected = [(route, mode, i) for route in ROUTES for i in range(36) for mode in (['full', 'culled', 'unculled'] if i in (0, 17, 35) else ['full'])] + [('cost', mode, 0) for mode in MODES]
        rows = capture['records']
        require([(r['route'], r['mode'], r['index']) for r in rows] == expected and len(rows) == 256, 'complete native frame matrix')
        by_key = {}
        root_calls = []
        pixel_pairs = []
        for index, row in enumerate(rows):
            require(row['serial'] == index + 1 and row['focused'] and row['windowed'] and row['size'] == [width, width * 9 // 16] and row['presents'] >= 2 and row['drawn_frames'] >= 2, 'fresh/focused/windowed frame')
            require(row['draws'] and all(d['serial'] == row['serial'] and d['save_before'] == d['save_after'] == row['save_sha256'] for d in row['draws']), 'draw purity/serial')
            stats = row['budget']['statistics']
            require(stats['owners'] == stats['builds'] == 1 and stats['groups'] == 2 and 0 <= stats['active'] <= 8, 'bounded foliage resources')
            require(row['budget']['target_size'] == [768, 384] and row['budget']['nominal_target_rgba8_bytes'] == 1179648, 'native target payload/scale')
            root_calls.append(row['budget']['root_draw_calls'])
            by_key[row['route'], row['mode'], row['index']] = row
        for route in capture['routes']:
            first = by_key[route['id'], 'full', 0]
            last = by_key[route['id'], 'full', 35]
            end = [route['start'][i] + route['direction'][i] * 126 for i in range(2)]
            if route.get('camera_only'):
                expected_camera = [route['camera_start'][i] + route['direction'][i] * 126 for i in range(2)]
                require(math.dist(last['state']['camera'], expected_camera) < 0.01 and first['state']['camera'] != last['state']['camera'], 'camera pan endpoint')
                require(first['state']['player'] == last['state']['player'], 'camera pan must not fake hero travel')
            else:
                require(math.dist(last['state']['player'], end) < 0.01, 'actual hero movement endpoint')
                if route['id'] == 'chunk':
                    require(math.floor(first['state']['player'][0] / 384) == 4 and math.floor(last['state']['player'][0] / 384) == 5, 'actual chunk boundary crossed')
            for i in (0, 17, 35):
                a, b = by_key[route['id'], 'culled', i], by_key[route['id'], 'unculled', i]
                require(a['state'] == b['state'] and a['save_sha256'] == b['save_sha256'], 'culling pair state/camera/uniforms')
                pixel_pairs.append((a, b))
        cost = [by_key['cost', mode, 0]['budget'] for mode in MODES]
        require(len({c['target_id'] for c in cost}) == 1, 'cost modes rebuild target')
        for mode, row in zip(MODES, cost):
            if mode in ('normal', 'returned'):
                require(row['target_draw_calls_last_frame'] == 2 and row['target_primitives_last_frame'] == 192 and row['statistics']['active'] > 0, 'production canvas budget')
            else:
                require(row['target_update_mode'] == 0 and row['statistics']['active'] == row['statistics']['recovery_active'] == 0, 'inactive work not disabled')
        coverage_rows = capture['coverage']
        require(len(coverage_rows) == 13 and coverage_rows[0]['calibration'], 'coverage matrix/calibration')
        calibration = frames.image(prefix + coverage_rows[0]['image'])
        require([calibration.getpixel(p) for p in ((64, 64), (8, 8), (24, 24))] == [(0, 0, 0, 0), (1, 0, 0, 255), (2, 0, 0, 255)], 'additive 0/1/2 calibration')
        require([(r['scale'], r['extreme']) for r in coverage_rows[1:]] == [(s, [x, y]) for s in (1, 2, 4) for x, y in ((-1, -1), (1, -1), (-1, 1), (1, 1))], 'all extreme/DPI combinations')
        summaries = []
        for row in coverage_rows[1:]:
            scale = row['scale']
            image = frames.image(prefix + row['image'])
            require(image.size == (384 * scale, 192 * scale), 'coverage dimensions')
            counts = Counter(image.tobytes()[::4])
            fragments = sum(value * count for value, count in counts.items())
            covered = image.width * image.height - counts[0]
            require(fragments == row['fragments'] and covered == row['covered_pixels'] and max(counts) == row['maximum'] == 1, 'independent coverage count/no overlap')
            require(0 < fragments <= 8 * 72 * scale * math.ceil((72 + 4.36) * scale), 'fragment fill budget')
            require(row['draw_calls'] == 2 and row['primitives'] == 192 and row['nominal_rgba8_bytes'] == image.width * image.height * 4, 'coverage canvas/payload budget')
            require([g['kind'] for g in row['bounds']] == ['reeds', 'grass'], 'both native bounds groups required')
            for group in row['bounds']:
                bounds = group['aabb']
                for i in (range(6) if group['kind'] == 'reeds' else range(6, 8)):
                    lo = [(i % 4 * 96 + 12 - 5.71) * scale, (i // 4 * 96 + 12 - 4.36) * scale]
                    hi = [(i % 4 * 96 + 84 + 5.71) * scale, (i // 4 * 96 + 84 + 4.36) * scale]
                    require(all(bounds['position'][axis] <= lo[axis] and bounds['position'][axis] + bounds['size'][axis] >= hi[axis] for axis in (0, 1)), 'native MultiMesh AABB clips swept geometry')
            summaries.append({'scale': scale, 'extreme': row['extreme'], 'fragments': fragments, 'fill_ratio': fragments / (image.width * image.height), 'maximum': max(counts)})
            result['coverage_targets'] += 1
        for a, b in pixel_pairs:
            aa, bb = frames.image(prefix + a['image']), frames.image(prefix + b['image'])
            require(aa.crop((0, 8, width, aa.height)).tobytes() == bb.crop((0, 8, width, bb.height)).tobytes(), 'culling changes visible RGBA')
            result['exact_pairs'] += 1
        for row in rows:
            verify_pixels(frames, prefix, row, width)
            result['frames'] += 1
        result['windows'].append({'width': width, 'root_draw_calls_range': [min(root_calls), max(root_calls)], 'cost': dict(zip(MODES, cost)), 'coverage': summaries})
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=REPORT / 'native-01')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = verify(args.root)
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('FOLIAGE VISIBILITY VERIFIED:', result['frames'], 'native frames,', result['exact_pairs'], 'exact pairs,', result['coverage_targets'], 'coverage targets; no FPS admission')
