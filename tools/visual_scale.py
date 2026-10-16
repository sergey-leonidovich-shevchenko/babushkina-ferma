#!/usr/bin/env python3
"""Нативное сравнение размера героя и двух полей обзора без изменения игровой физики."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT/'docs/reports/visual-overhaul/vart-002'
FIELDS = {'current': ([1152,648],1.0), 'wide': ([1440,810],0.8), 'close': ([960,540],1.2)}
SCENES = {'plaza': [1248,744], 'farm': [744,936]}
SOURCES = ['project.godot','main.tscn','scripts/systems/camera_system.gd','scripts/systems/hero_visual_system.gd',
           'scripts/systems/animation_renderer.gd','scripts/systems/render_system.gd','scripts/systems/world_visibility_system.gd',
           'scripts/presentation/visual_reference_mode.gd','scripts/systems/navigation_system.gd','scripts/game_context.gd',
           'assets/game/characters/hero_v3/walk_master.png','tools/visual_scale_capture.gd']


def read(path: Path) -> dict:
    """Читает паспорт без выполнения вложенного содержимого."""
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    """Связывает данные с точными байтами источника или кадра."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def near(a, b) -> bool:
    """Сравнивает конечные координаты с небольшим допуском арифметики движка."""
    return isinstance(a,list) and len(a)==len(b) and all(type(x) in (int,float) and math.isfinite(x) for x in a) and math.dist(a,b)<0.001


def capture_errors(data: dict) -> list[str]:
    """Отклоняет разный центр, изменённые коллизии, неверное отсечение либо потерю нативного кадра."""
    errors = []
    if data.get('kind')!='native-fov-study' or data.get('schema')!=1 or data.get('performance_eligible') is not False or data.get('simulation_frozen') is not True: errors.append('classification')
    if data.get('display_server') in [None,'headless'] or data.get('renderer')!='opengl3' or data.get('errors'): errors.append('native conditions')
    if data.get('hud_size')!=[1152,648] or data.get('input_enabled') is not False: errors.append('HUD/input contract')
    if not str(data.get('profile','')).startswith('Codex-VART-002-') or data.get('disabled_effects')!=['water_overlays','ambient_motion','orchard_weather','atmosphere','action_feedback']: errors.append('capture preset')
    rows = data.get('points',[])
    expected = {s+'-'+v for s in SCENES for v in FIELDS}
    if len(rows)!=6 or {p.get('id') for p in rows}!=expected: errors.append('comparison coverage')
    states = {s:[] for s in SCENES}
    for row in rows:
        scene, variant = row.get('scene'), row.get('variant')
        if scene not in SCENES or variant not in FIELDS: errors.append('unknown preset'); continue
        field, zoom = FIELDS[variant]; player = SCENES[scene]
        origin = [player[i]-field[i]/2 for i in range(2)]
        if row.get('field')!=field or row.get('zoom')!=zoom or row.get('logical_viewport')!=field: errors.append('field/scale')
        for key, value in [('player',player),('camera_center',player),('camera_origin',origin),('hero_canvas_feet',[576,324]),('visible_world',origin+field),('hero_projected_frame_size',[96*zoom,96*zoom])]:
            if not near(row.get(key),value): errors.append('geometry: '+key)
        if row.get('world_readback')!=[1152,648]: errors.append('world target')
        matrix = row.get('projection',[])
        if len(matrix)!=3 or not all(near(a,b) for a,b in zip(matrix,[[zoom,0],[0,zoom],[0,0]])): errors.append('projection matrix')
        before, after = row.get('physical_before',{}), row.get('physical_after',{})
        if before!=after or before.get('radius')!=18 or before.get('speed')!=210 or before.get('hp')!=100 or before.get('energy')!=12 or before.get('physics_processing') is not False: errors.append('physics changed')
        if not re.fullmatch('[0-9a-f]{64}',before.get('save_sha256','')): errors.append('state proof')
        states[scene].append(before.get('save_sha256'))
        conditions = row.get('conditions',{})
        if conditions.get('window')!=[1152,648] or conditions.get('readback')!=[1152,648] or conditions.get('focused') is not True or conditions.get('mode')!=0: errors.append('window/framebuffer/focus')
    if any(len(set(values))!=1 for values in states.values()): errors.append('different world state between variants')
    return sorted(set(errors))


def silhouette(path: Path) -> list[dict]:
    """Измеряет видимую фигуру по альфа-каналу, не изменяя исходный PNG."""
    from PIL import Image
    image = Image.open(path).convert('RGBA')
    mask = image.getchannel('A').point(lambda value:255 if value>=26 else 0)
    result = []
    for index, direction in enumerate(['down','left','right']):
        box = mask.crop((192*index,0,192*(index+1),192)).getbbox()
        result.append({'direction':direction,'bbox':list(box) if box else [],'height':box[3]-box[1] if box else 0,'width':box[2]-box[0] if box else 0})
    return result


def decision_errors(review: dict, profile: dict) -> list[str]:
    """Не допускает расхождения выбора пользователя, проекции и физического контракта."""
    errors = []
    selected = review.get('selection')
    if review.get('status')!='approved' or selected not in FIELDS: return ['unapproved scale choice']
    field, zoom = FIELDS[selected]
    if profile.get('status')!='approved' or profile.get('selection')!=selected: errors.append('profile choice differs')
    if review.get('runtime_integration') is not False or profile.get('runtime_integration') is not False: errors.append('unverified runtime integration')
    expected = {'task':'VART-002','output_size':[1152,648],'world_field':field,'world_zoom':zoom,'scope':'whole_world',
                'hud_zoom':1.0,'hero_world_frame':[96,96],'hero_physical_radius':18,'hero_speed':210,'grid_world_size':24,
                'reference_silhouette_alpha_threshold':26,'art_direction':'VART-001 A'}
    for key, value in expected.items():
        if profile.get(key)!=value: errors.append('profile contract: '+key)
    if profile.get('reference_silhouette_down_px')!=silhouette(REPORT/f'native/hero-{selected}.png')[0]['height']: errors.append('profile silhouette differs')
    if review.get('options',{}).get(selected,{}).get('field')!=field or review.get('options',{}).get(selected,{}).get('zoom')!=zoom: errors.append('choice geometry differs')
    return errors


def verify(folder: Path) -> list[str]:
    """Проверяет настоящие кадры, независимый HUD, границы поз и происхождение всех файлов."""
    from PIL import Image, ImageChops
    errors = capture_errors(read(folder/'capture.json'))
    source = read(folder/'source.json')
    names = {s+'-'+v+suffix+'.png' for s in SCENES for v in FIELDS for suffix in ['', '-world']}
    names |= {s+'-hud.png' for s in SCENES}|{'hero-'+v+'.png' for v in FIELDS}|{'capture.json','stdout.txt','engine.txt'}
    if set(source.get('artifacts',{}))!=names or set(source.get('sources',{}))!=set(SOURCES): errors.append('incomplete provenance')
    if not re.fullmatch('[0-9a-f]{40}',source.get('base_commit','')): errors.append('base commit')
    if source.get('runtime_patch')!='' or any(not re.fullmatch('[0-9a-f]{64}',v) for v in source.get('sources',{}).values()): errors.append('runtime source proof')
    for filename, sha in source.get('artifacts',{}).items():
        if filename not in names or not (folder/filename).is_file() or digest(folder/filename)!=sha: errors.append('artifact hash: '+filename)
    for scene in SCENES:
        hud = Image.open(folder/(scene+'-hud.png')).convert('RGBA')
        alpha = hud.getchannel('A'); opaque = alpha.point(lambda value:255 if value==255 else 0)
        clear = alpha.point(lambda value:255 if value==0 else 0)
        if hud.size!=(1152,648) or opaque.getbbox() is None: errors.append('HUD dimensions/alpha')
        for variant in FIELDS:
            image = Image.open(folder/(scene+'-'+variant+'.png')).convert('RGB')
            world = Image.open(folder/(scene+'-'+variant+'-world.png')).convert('RGB')
            if image.size!=(1152,648) or world.size!=(1152,648): errors.append('image dimensions'); continue
            for diff, mask, label in [(ImageChops.difference(image,hud.convert('RGB')),opaque,'HUD changed'),(ImageChops.difference(image,world),clear,'world changed between passes')]:
                if any(ImageChops.multiply(channel,mask).getbbox() for channel in diff.split()): errors.append(label+': '+scene+'-'+variant)
    for variant in FIELDS:
        hero = Image.open(folder/('hero-'+variant+'.png')).convert('RGBA')
        if hero.size!=(576,192): errors.append('hero sample dimensions')
        for value in silhouette(folder/('hero-'+variant+'.png')):
            box = value['bbox']
            if len(box)!=4 or box[0]<=0 or box[1]<=0 or box[2]>=192 or box[3]>=192: errors.append('hero clipped')
        if source.get('silhouettes',{}).get(variant)!=silhouette(folder/('hero-'+variant+'.png')): errors.append('silhouette metadata')
    if 'ERROR:' in (folder/'stdout.txt').read_text(): errors.append('engine errors')
    return errors


def capture(folder: Path) -> None:
    """Запускает отдельное окно Godot, сохраняя параметры и хеши до и после съёмки."""
    if folder.exists(): raise ValueError('Нужен новый каталог; прежние результаты не перезаписываются')
    folder.mkdir(parents=True)
    source = {'schema':1,'task':'VART-002','base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'runtime_patch':subprocess.check_output(['git','diff','--','scripts','assets','project.godot'],cwd=ROOT,text=True),
              'sources':{p:digest(ROOT/p) for p in SOURCES},'artifacts':{}}
    (folder/'source.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n')
    godot = os.environ.get('FARM_GODOT_BIN',str(ROOT/'tools/Godot.app/Contents/MacOS/Godot'))
    command = [godot,'--path',str(ROOT),'--windowed','--audio-driver','Dummy','--log-file',str(folder/'engine.txt'),
               '--script','res://tools/visual_scale_capture.gd','--','--output='+str(folder),'--profile=Codex-VART-002-'+uuid.uuid4().hex]
    with (folder/'stdout.txt').open('w') as log: result = subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=180)
    for path in folder.iterdir():
        if path.is_file() and path.name!='source.json': source['artifacts'][path.name]=digest(path)
    source['silhouettes'] = {v:silhouette(folder/('hero-'+v+'.png')) for v in FIELDS} if result.returncode==0 else {}
    (folder/'source.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n')
    if result.returncode: raise ValueError('Нативная съёмка отклонена; паспорт и кадры отказа сохранены')
    if any(digest(ROOT/path)!=sha for path,sha in source['sources'].items()): raise ValueError('Источник изменился во время съёмки')
    errors = verify(folder)
    if errors: raise ValueError(str(errors))
    print('VISUAL SCALE: six native scenes, fixed HUD, identical physics and source hashes valid')


def main() -> None:
    """Выбирает воспроизводимую съёмку либо проверку сохранённых кадров."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['capture','verify'])
    parser.add_argument('--output',type=Path,default=REPORT/'native')
    args = parser.parse_args()
    if args.command=='capture': capture(args.output.resolve())
    else:
        errors = verify(args.output.resolve())
        if args.output.resolve()==(REPORT/'native').resolve(): errors += decision_errors(read(REPORT/'review.json'),read(REPORT/'scale-profile.json'))
        if errors: raise SystemExit('\n'.join(errors))
        print('VISUAL SCALE: geometry, native pixels, fixed HUD and physics valid')


if __name__=='__main__': main()
