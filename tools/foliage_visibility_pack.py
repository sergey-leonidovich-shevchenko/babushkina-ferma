#!/usr/bin/env python3
"""Losslessly archive every native RGBA frame before removing only declared successful staging PNGs."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from foliage_visibility_collect import digest, write


def pack(root: Path) -> None:
    """Keep capture.json unchanged, every RGBA SHA, all pair/cost PNG, and first/middle/last video PNG."""
    source = json.loads((root / 'source.json').read_text())
    if not source['complete']:
        raise ValueError('Failed or incomplete runs must remain intact')
    if (root / 'storage.json').exists():
        raise ValueError('Archive already exists')
    storage = {'schema': 1, 'format': 'animated WebP lossless/exact, every decoded RGBA byte verified', 'view_fps': 24, 'simulation_hz': 120, 'steps_per_frame': 2, 'slowdown': 2.5, 'frames': {}, 'archives': {}}
    staged = []
    for width in (1152, 1280):
        native = root / str(width) / 'native'
        capture = json.loads((native / 'capture.json').read_text())
        for route in capture['routes']:
            rows = [r for r in capture['records'] if r['route'] == route['id'] and r['mode'] == 'full']
            if [r['index'] for r in rows] != list(range(36)):
                raise ValueError('Incomplete predeclared route')
            images = [Image.open(native / r['image']).convert('RGBA') for r in rows]
            archive = native / route['id'] / 'motion.webp'
            durations = [round((i + 1) * 1000 / 24) - round(i * 1000 / 24) for i in range(36)]
            images[0].save(archive, save_all=True, append_images=images[1:], duration=durations, loop=0, lossless=True, exact=True, method=4)
            decoded = Image.open(archive)
            if decoded.n_frames != 36:
                raise ValueError('Encoder merged or lost a frame')
            for i, row in enumerate(rows):
                decoded.seek(i)
                rgba = decoded.convert('RGBA').tobytes()
                if rgba != images[i].tobytes() or hashlib.sha256(rgba).hexdigest() != row['rgba_sha256']:
                    raise ValueError('Lossless archive differs at ' + row['image'])
                relative = str((native / row['image']).relative_to(root))
                storage['frames'][relative] = {'archive': str(archive.relative_to(root)), 'frame': i, 'png_sha256': digest(native / row['image']), 'rgba_sha256': row['rgba_sha256'], 'kept_png': i in (0, 17, 35)}
                if i not in (0, 17, 35):
                    staged.append(native / row['image'])
            storage['archives'][str(archive.relative_to(root))] = digest(archive)
            print('PACKED', width, route['id'], archive.stat().st_size, flush=True)
    write(root / 'storage.json', storage)
    # Only after all archives round-trip exactly; raw engine metadata and every failed run are untouched.
    for path in staged:
        path.unlink()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    pack(parser.parse_args().root)
