#!/usr/bin/env python3
"""Проверяет адресные профили фильтрации и сохранённое нативное сравнение."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops
from tools.assets.contracts.visual_resources import ROOT, MANIFEST, parse, validate as validate_resources

POLICY = 'assets/game/visual_sampling.json'
REPORT = ROOT / 'docs/reports/visual-overhaul/vpipeline-003'
CONFIG = ['id','location','player','camera','facing','day','minutes','seed','season','weather','framebuffer','engine','physics_processing']
PROTECTED = [(24,480,724,624),(1020,490,1125,630)]


def validate(root: Path, policy: dict, resources: dict) -> list[str]:
    """Сверяет семейства, паспорт и реальные изображения без определения режима по имени PNG."""
    errors = validate_resources(root, resources)
    families = policy.get('families',{})
    if policy.get('schema_version')!=1 or not isinstance(families,dict): return errors+['invalid sampling schema']
    for name, row in families.items():
        if not isinstance(row,dict) or set(row)!={'filter','repeat','layouts'}:
            errors.append(name+': invalid profile'); continue
        if row['filter'] not in ['nearest','linear']: errors.append(name+': filter must be explicit nearest/linear')
        if row['repeat']!='disabled': errors.append(name+': standalone repeat must be disabled')
        layouts=row['layouts']
        if not isinstance(layouts,list) or not layouts or any(not isinstance(x,str) for x in layouts) or len(set(layouts))!=len(layouts) or set(layouts)-{'standalone','atlas','padded_atlas'}:
            errors.append(name+': invalid layouts'); continue
        if row['filter']=='linear' and 'atlas' in layouts: errors.append(name+': linear atlas requires VPIPELINE-004 padding')
    for name, mode in [('legacy_world','nearest'),('legacy_ui','nearest'),('painted_world','linear'),('painted_ui','linear'),('painted_atlas','linear')]:
        if families.get(name,{}).get('filter')!=mode: errors.append(name+': missing or unsafe family mode')
    if families.get('painted_atlas',{}).get('layouts')!=['padded_atlas']: errors.append('painted_atlas: requires validated padded pages')
    for id, row in resources.get('resources',{}).items():
        family=row.get('sampling_family')
        profile=families.get(family,{}) if isinstance(family,str) else {}
        if not profile: errors.append(id+': unknown sampling family'); continue
        if row.get('filter')!=profile.get('filter'): errors.append(id+': passport filter conflicts with family')
        for view in row.get('views',{}).values():
            for variant in view.get('variants',{}).values():
                texture=resources.get('textures',{}).get(variant.get('texture'),{})
                if texture.get('layout') not in profile.get('layouts',[]): errors.append(id+': family rejects texture layout')
    return errors


def same(a: Image.Image, b: Image.Image) -> bool:
    """Сравнивает все каналы декодированных пикселей, включая прозрачность."""
    return a.size==b.size and all(channel.getbbox() is None for channel in ImageChops.difference(a,b).split())


def verify_capture(folder: Path) -> None:
    """Проверяет исторический readback, защищённые области и адресность, не замораживая будущие игровые PNG."""
    proof=parse((folder/'native-comparison.json').read_text())
    before=parse((folder/'native/before/capture.json').read_text())
    after=parse((folder/'native/after/capture.json').read_text())
    if proof.get('base_commit')!='1cac1d36810a4f0d6bcd20aea11e6ba6ac67ca76': raise ValueError('wrong baseline commit')
    if any(before.get(k)!=after.get(k) for k in CONFIG): raise ValueError('native configuration mismatch')
    if before.get('errors') or after.get('errors') or after.get('performance_eligible') is not False: raise ValueError('invalid native run')
    if after.get('scene_policy')!={'legacy_canvas':1,'table':2,'clock':2}: raise ValueError('unexpected actual scene sampling')
    if len(after.get('implementation_sha256',{}))!=9 or any(len(x)!=64 for x in after['implementation_sha256'].values()): raise ValueError('missing captured implementation hashes')
    expected={('room',mode,None,None) for mode in [0,1]}|{('samples',mode,scale,family) for mode in [0,1] for scale in [0.75,1.0,1.2] for family in ['legacy_world','painted_world']}
    rows=after.get('frames',[])
    if len(rows)!=14 or {(r.get('kind'),r.get('default_filter'),r.get('scale'),r.get('family')) for r in rows}!=expected: raise ValueError('incomplete comparison matrix')
    expected_files={'native/before/room.png'}|{'native/after/'+r['file'] for r in rows}
    if set(proof.get('images',{}))!=expected_files: raise ValueError('incomplete image inventory')
    images={}
    for name, sha in proof['images'].items():
        path=(folder/name).resolve()
        if not path.is_relative_to(folder.resolve()) or hashlib.sha256(path.read_bytes()).hexdigest()!=sha: raise ValueError('native SHA256 mismatch: '+name)
        with Image.open(path) as source:
            if source.size!=(1152,648) or source.format!='PNG': raise ValueError('invalid framebuffer')
            images[name]=source.convert('RGBA')
    for filename in ['native/before/engine.txt','native/after/engine.txt']:
        log=(folder/filename).read_text()
        if 'ERROR:' in log or 'FAIL:' in log or 'Compatibility' not in log: raise ValueError('invalid native engine log')
    baseline=images['native/before/room.png']
    if after.get('changed_region')!=[660.0,386.0,756.0,450.0]: raise ValueError('unexpected world footprint/camera')
    room=images['native/after/room-default-0.png']
    if same(baseline,room): raise ValueError('painted table did not actually change filtering')
    old,new=baseline.copy(),room.copy()
    old.paste((0,0,0,0),tuple(map(int,after['changed_region']))); new.paste((0,0,0,0),tuple(map(int,after['changed_region'])))
    if not same(old,new): raise ValueError('filter changed an unrelated room region')
    if not same(room,images['native/after/room-default-1.png']): raise ValueError('project filter changed room pixels')
    by={(r['default_filter'],r['scale'],r['family']):images['native/after/'+r['file']] for r in rows if r['kind']=='samples'}
    control=next(iter(by.values()))
    for image in by.values():
        for box in PROTECTED:
            if not same(control.crop(box),image.crop(box)): raise ValueError('protected font/atlas/clock changed')
    for scale in [0.75,1.0,1.2]:
        for family in ['legacy_world','painted_world']:
            if not same(by[0,scale,family],by[1,scale,family]): raise ValueError('project filter leaked into addressed sampling')
        a,b=by[0,scale,'legacy_world'],by[0,scale,'painted_world']
        if same(a,b): raise ValueError('comparison did not actually change filtering')
        for box in [(0,0,1152,95),(0,440,1152,480),(0,480,780,648),(950,480,1152,648)]:
            if not same(a.crop(box),b.crop(box)): raise ValueError('filter changed an unrelated region')


def main() -> None:
    """Отклоняет ошибку политики или доказательства до публикации, не обновляя эталон автоматически."""
    errors=validate(ROOT,parse((ROOT/POLICY).read_text()),parse((ROOT/MANIFEST).read_text()))
    if errors: raise SystemExit('\n'.join(errors))
    verify_capture(REPORT)
    print('VISUAL SAMPLING: families, real PNG/imports, native matrix and protected UI valid')


if __name__=='__main__': main()
