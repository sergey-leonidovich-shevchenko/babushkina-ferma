#!/usr/bin/env python3
"""Проверяет отдельный художественный комплект берега и сохранённую нативную витрину."""
from __future__ import annotations

import hashlib
import json
import math
import subprocess
from pathlib import Path

from PIL import Image, ImageChops
from visual_resources import vector

from common.git import git_environment

ROOT = Path(__file__).resolve().parents[1]
REPORT = Path('docs/reports/visual-overhaul/vshore-001')
NEW_IDS = ['stone-n', 'stone-e', 'stone-s', 'stone-w'] + [
    f'turn-{v}-{i}' for v in ['a', 'b'] for i in range(4)] + [
    'bridge-end-w', 'bridge-end-e', 'stone-earth-e', 'stone-earth-w']


def digest(path: Path) -> str:
    """Подписывает точные байты файла без автоматической переподписи доказательства."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> dict:
    """Читает сохранённые данные отдельно от генерируемых изображений."""
    return json.loads(path.read_text())


def historical(root: Path, commit: str, name: str, sha: str) -> bool:
    """Сверяет общие WATER-исходники по сохранённой истории, не замораживая будущую игру."""
    result = subprocess.run(['git','-C',str(root),'show',commit+':'+name],capture_output=True,check=False,env=git_environment())
    return result.returncode == 0 and hashlib.sha256(result.stdout).hexdigest() == sha


def tracked(root: Path, paths: list[str]) -> bool:
    """Отличает существующие локальные доказательства от действительно включённых в Git файлов."""
    result = subprocess.run(['git','-C',str(root),'ls-files','--error-unmatch','--',*paths],capture_output=True,check=False,env=git_environment())
    return result.returncode == 0


def local(root: Path, folder: Path, value: str) -> Path:
    """Разрешает ссылки между отчётами, запрещая выход и симлинк за пределы проекта."""
    if not isinstance(value, str) or Path(value).is_absolute(): raise ValueError('invalid relative path')
    path = (folder/value).resolve()
    if not path.is_relative_to(root.resolve()): raise ValueError('path escapes project')
    return path


def same_pixels(a: Image.Image, b: Image.Image) -> bool:
    """Сверяет все каналы, включая скрытый RGB прозрачного края."""
    return a.size == b.size and not any(c.getbbox() for c in ImageChops.difference(a.convert('RGBA'), b.convert('RGBA')).split())


def verify(root: Path = ROOT) -> list[str]:
    """Проверяет геометрию, источники, нарезку, кадры, движение, видео и WATER-регрессию."""
    folder = root/REPORT
    errors = []
    required = ['water-review.log','water-review.json','profile.json','source.json',
                'native/engine.log','native/capture.json','native/video-proof.json','native/camera-pan.mp4']
    if not tracked(root,[(REPORT/p).as_posix() for p in required]): errors.append('critical evidence is not in Git index')
    try:
        data, source = read(folder/'profile.json'), read(folder/'source.json')
        proof = read(folder/'native/capture.json')
        if data.get('task') != 'VSHORE-001' or data.get('status') != 'accepted_art_study': errors.append('unaccepted art profile')
        if any(data.get(k) is not False for k in ['runtime_integration', 'autotile_complete', 'performance_eligible']):
            errors.append('unsupported runtime/autotile/performance claim')
        if data.get('target') != [1152, 648] or data.get('field') != [960, 540] or data.get('zoom') != 1.2 or data.get('grid') != 24:
            errors.append('camera/scale changed')
        if data.get('art_direction') != {'style':'VART-001 A','palette':'VART-003 A','edge':'VART-005 A','density':'VART-006 B','light':'VART-007 A'}:
            errors.append('accepted art direction changed')
        for name, sha in source['files'].items():
            if digest(local(root, folder, name)) != sha: errors.append('master/prompt/reference SHA: '+name)
        if source.get('selected') != 'masters/stone-bank-v3.png': errors.append('rejected master selected')
        parts = data['parts']
        ids = [p['id'] for p in parts]
        if len(ids) != len(set(ids)) or len(ids) != 29 or {p['id'] for p in parts if p['family']=='stone'} != set(NEW_IDS):
            errors.append('incomplete or duplicate kit')
        exports = {p['id']:p for p in proof['exports']}
        if set(exports) != set(ids): errors.append('incomplete exports')
        stone_scales = set()
        for part in parts:
            label = part['id']
            if part.get('rotation') != 0 or part.get('flip') != [1,1]: errors.append('rotated/mirrored illuminated art: '+label)
            rect = part['rect']
            if not vector(rect,4) or any(type(n) is not int for n in rect) or min(rect[2:]) <= 0:
                errors.append('noninteger source rect: '+label); continue
            if not vector(part.get('pivot'),2) or not (0 <= part['pivot'][0] <= rect[2] and 0 <= part['pivot'][1] <= rect[3]):
                errors.append('invalid pivot: '+label)
            if type(part.get('scale')) not in [int,float] or not math.isfinite(part['scale']) or part['scale'] <= 0:
                errors.append('invalid scale: '+label)
            master = local(root,folder,part['source'])
            with Image.open(master) as raw:
                x,y,w,h = rect
                if x+w > raw.width or y+h > raw.height: errors.append('source rect outside master: '+label); continue
                expected = raw.crop((x,y,x+w,y+h)).convert('RGBA')
            if part['family'] == 'stone':
                stone_scales.add(part['scale'])
                bounds = expected.getchannel('A').point(lambda v: 255 if v >= 26 else 0).getbbox()
                if not bounds or min(bounds[0],bounds[1],w-bounds[2],h-bounds[3]) < 8:
                    errors.append('clipped dense silhouette: '+label)
            row = exports.get(label)
            if not row: continue
            file = local(root,folder/'native',row['file'])
            if digest(file) != row['sha256'] or row['rect'] != rect or row['size'] != [w,h]: errors.append('export metadata: '+label)
            with Image.open(file) as actual:
                if not same_pixels(actual,expected): errors.append('crop pixels differ from master: '+label)
        if len(stone_scales) != 1: errors.append('inconsistent stone scale')
        by = {p['id']:p for p in parts}
        deck = [by['bridge-deck-left'],by['bridge-deck-right']]
        if data['scene']['bridge'] != [432,312,192,72] or data['bridge_revision']['footprint'] != [192,72]:
            errors.append('wider bridge grid/footprint')
        if deck[0]['scale'] != deck[1]['scale'] or not math.isclose(sum(p['rect'][2]*p['scale'] for p in deck),204,abs_tol=.0001):
            errors.append('stretched/mismatched modular bridge')
        if data['bridge_revision'].get('native_walking_physics_changed') is not False:
            errors.append('art study cannot claim migrated bridge physics')
        errors.extend(verify_native(root,folder,data,proof))
        review = read(folder/'water-review.json')
        log = folder/'water-review.log'
        if digest(log) != review['log_sha256'] or 'SHORE WATER TESTS: 845 passed, 0 failed' not in log.read_text():
            errors.append('WATER regression evidence')
        if any(marker in log.read_text() for marker in ['ERROR:', 'SCRIPT ERROR', 'FAIL:']): errors.append('WATER engine error')
        if any(marker in (folder/'native/engine.log').read_text() for marker in ['ERROR:', 'SCRIPT ERROR']):
            errors.append('native engine error')
        for name, sha in review['sources'].items():
            if not historical(root,review['base_commit'],name,sha): errors.append('WATER historical source: '+name)
        if digest(root/'tools/shore_kit_review.gd') != review['runner_sha256']: errors.append('WATER runner changed')
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append('incomplete shore kit: '+str(exc))
    return errors


def verify_native(root: Path, folder: Path, data: dict, proof: dict) -> list[str]:
    """Не принимает headless, прежние кадры, неподвижное видео или неверную проекцию."""
    errors = []
    if proof.get('kind') != 'native-shore-art-study' or proof.get('display_server') == 'headless' or not proof.get('adapter'):
        errors.append('native display/adapter missing')
    if any(proof.get(k) is not False for k in ['native_gameplay','runtime_integration','performance_eligible']):
        errors.append('study classified as gameplay/FPS')
    if proof.get('target') != data['target'] or proof.get('field') != data['field'] or proof.get('zoom') != 1.2 or proof.get('camera_static') != [0,0]:
        errors.append('native camera mismatch')
    if proof.get('base_commit') != data['base_commit']: errors.append('base commit mismatch')
    if proof.get('texture_loads_inside_draw') != 0: errors.append('per-frame texture loads')
    mandatory = ['res://'+str(REPORT/'profile.json'),'res://'+str(REPORT/'source.json'),
                 'res://tools/shore_kit_canvas.gd','res://tools/shore_kit_capture.gd']
    if not set(mandatory) <= proof['sources'].keys(): errors.append('missing capture sources')
    for name, sha in proof['sources'].items():
        if name.startswith('res://scripts/'):
            valid = historical(root,proof['base_commit'],name[6:],sha)
        else:
            valid = name.startswith('res://') and digest(local(root,root,name[6:])) == sha
        if not valid:
            errors.append('capture source SHA: '+name)
    expected_ids = {p+'-'+b for p in ['stone','reuse'] for b in ['light','dark','grass']} | {'scene-narrow','scene-earth','scene-stone','scene-bridge','scene-grid'}
    if {f['id'] for f in proof['frames']} != expected_ids or len(proof['frames']) != 11: errors.append('native frame coverage')
    for frame in proof['frames']:
        file = local(root,folder/'native',frame['file'])
        with Image.open(file) as image:
            if image.size != (1152,648) or digest(file) != frame['sha256'] or frame['repeat_equal'] is not True:
                errors.append('invalid native frame: '+frame['id'])
    motion = proof['motion']
    if len(motion) != 120 or proof.get('fps') != 30 or proof.get('fixed_clock_video') is not True:
        errors.append('motion coverage/clock')
    if len({r['sha256'] for r in motion}) != 120: errors.append('repeated motion frames')
    for i,row in enumerate(motion):
        if row['frame'] != i or row['camera'] != [i*.5,i*.125]: errors.append('camera trajectory')
        if any(not math.isclose(a,b,abs_tol=.001) for a,b in zip(row['foot_pixel'],[(420-i*.5)*1.2,(336-i*.125)*1.2])):
            errors.append('motion projection')
    for index in [0,60,119]:
        file = folder/f'native/motion-{index:03d}.png'
        if digest(file) != motion[index]['sha256']: errors.append('motion witness SHA')
        with Image.open(file) as image:
            if image.size != (1152,648): errors.append('motion witness size')
    video = read(folder/'native/video-proof.json')
    chain = hashlib.sha256('\n'.join(r['sha256'] for r in motion).encode()).hexdigest()
    if video.get('capture_sha256') != digest(folder/'native/capture.json') or video.get('frame_chain_sha256') != chain:
        errors.append('video capture/frame chain changed')
    for name, sha in video['files'].items():
        if digest(local(root,folder/'native',name)) != sha: errors.append('video SHA: '+name)
    encoded = read(folder/'native/camera-pan.json')
    if any(encoded[k] != v for k,v in {'width':1152,'height':648,'frames':120,'fps':30,'duration':4}.items()):
        errors.append('encoded camera video dimensions/duration')
    return errors


if __name__ == '__main__':
    failures = verify()
    if failures: raise SystemExit('\n'.join(failures))
    print('SHORE KIT: 16 bank parts + wider modular deck, 29 exact crops, 11 native frames, camera video and 845 WATER assertions valid; no runtime/FPS acceptance')
