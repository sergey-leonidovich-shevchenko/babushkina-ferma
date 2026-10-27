#!/usr/bin/env python3
"""Сверяет палитры, измеренные области и неизменный мастер стенда VART-003."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
from PIL import Image

from common.paths import project_root

ROOT=project_root(__file__)
REPORT=ROOT/'docs/reports/visual-overhaul/vart-003'
MATERIALS={'grass','wood','stone','earth','water','metal'}
DATA_PATTERN=r'(<script type="application/json" id="palette-data">).*?(</script>)'


def read(path: Path) -> dict:
    """Загружает декларативный паспорт без выполнения содержимого."""
    return json.loads(path.read_text())


def sha(path: Path) -> str:
    """Привязывает мастер, промпт и эталон к точным исходным байтам."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def luminance(hex_color: str) -> float:
    """Измеряет линейную относительную яркость sRGB для диагностики шкал."""
    values=[int(hex_color[i:i+2],16)/255 for i in (1,3,5)]
    values=[v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in values]
    return sum(v*w for v,w in zip(values,[0.2126,0.7152,0.0722]))


def contract_errors(data: dict, image: Image.Image) -> list[str]:
    """Отклоняет неполные шкалы, неверный масштаб, скрытое принятие и обрезанные силуэты."""
    errors=[]
    if data.get('task')!='VART-003' or data.get('schema')!=1 or data.get('runtime_integration') is not False: errors.append('classification')
    state,selected=data.get('status'),data.get('selection')
    if state not in ['awaiting_user_choice','approved'] or (state=='approved' and selected not in ['a','b']) or (state=='awaiting_user_choice' and selected is not None): errors.append('unconfirmed decision')
    if state=='approved' and (not data.get('decision_source') or not re.fullmatch(r'\d{4}-\d{2}-\d{2}',data.get('decision_date',''))): errors.append('missing decision record')
    expected={'art_direction':'VART-001 A','output_size':[1152,648],'world_field':[960,540],'world_zoom':1.2,'camera_center':[480,270],'hero_feet':[480,270]}
    for key,value in expected.items():
        if data.get(key)!=value: errors.append('scale contract: '+key)
    if data.get('filter')!={'mode':'luminance_to_five_srgb_stops','positions':[0,0.25,0.5,0.75,1],'alpha':'unchanged'}: errors.append('filter contract')
    mats=data.get('materials',[])
    if len(mats)!=6 or {m.get('id') for m in mats}!=MATERIALS: errors.append('material coverage')
    for m in mats:
        rect=m.get('source_rect',[])
        if len(rect)!=4 or any(type(v)!=int for v in rect): errors.append('integer region'); continue
        x,y,w,h=rect
        if min(x,y)<0 or min(w,h)<=0 or x+w>image.width or y+h>image.height: errors.append('source region outside master'); continue
        bbox=image.getchannel('A').crop((x,y,x+w,y+h)).point(lambda v:255 if v>=26 else 0).getbbox()
        if not bbox or min(bbox[0],bbox[1],w-bbox[2],h-bbox[3])<4: errors.append('clipped region: '+m['id'])
        frame,center=m.get('world_frame',[]),m.get('center',[])
        if len(frame)!=2 or len(center)!=2 or any(type(v) not in [int,float] for v in frame+center) or any(v<=0 or v%24 for v in frame): errors.append('world frame'); continue
        if any(center[i]-frame[i]/2<0 or center[i]+frame[i]/2>[960,540][i] for i in [0,1]): errors.append('layout outside field')
        if not m.get('recognition'): errors.append('color-only recognition')
    variants=data.get('variants',{})
    if set(variants)!={'a','b'}: errors.append('variant coverage')
    for variant in variants.values():
        if set(variant.get('ramps',{}))!=MATERIALS: errors.append('ramp coverage')
        for periods in variant.get('ramps',{}).values():
            if set(periods)!={'day','evening'}: errors.append('time coverage')
            for ramp in periods.values():
                if len(ramp)!=5 or any(not isinstance(c,str) or not re.fullmatch('#[0-9a-f]{6}',c) for c in ramp): errors.append('invalid ramp'); continue
                ys=[luminance(c) for c in ramp]
                if any(b<=a for a,b in zip(ys,ys[1:])): errors.append('reversed ramp')
    return sorted(set(errors))


def measurements(data: dict, image: Image.Image) -> dict:
    """Сохраняет измеримые границы и яркость, не выдавая их за художественную приёмку."""
    result={'schema':1,'palette_sha256':sha(REPORT/'palette.json'),'alpha_threshold':26,'visible_regions':{},'mid_luminance':{}}
    for m in data['materials']:
        x,y,w,h=m['source_rect'];bbox=image.getchannel('A').crop((x,y,x+w,y+h)).point(lambda v:255 if v>=26 else 0).getbbox()
        result['visible_regions'][m['id']]=list(bbox) if bbox else []
    for v,variant in data['variants'].items():
        result['mid_luminance'][v]={period:{m:round(luminance(ramps[period][2]),6) for m,ramps in variant['ramps'].items()} for period in ['day','evening']}
    result['interpretation']='Яркости соседних материалов могут быть близки: узнаваемость проверяется формой и фактурой в режиме без цвета. Это не подтверждение цветовой доступности всей игры.'
    return result


def browser_errors(proof: dict, data: dict) -> list[str]:
    """Сверяет измеренные DOM-области и канальные таблицы всех четырёх просмотров."""
    errors=[];cases=proof.get('cases',[])
    if proof.get('kind')!='browser-svg-preview' or proof.get('native_game_frame') is not False: errors.append('browser classification')
    if len(cases)!=4 or {(c.get('palette'),c.get('time')) for c in cases}!={(v,t) for v in ['a','b'] for t in ['day','evening']}: errors.append('browser coverage')
    for case in cases:
        if case.get('size')!=[1152,648] or case.get('viewBox')!='0 0 960 540' or case.get('layout_scale')!=[1.2,1.2] or case.get('cards')!=12: errors.append('browser scale/cards')
        motifs=case.get('motifs',[])
        if len(motifs)!=7: errors.append('browser motifs'); continue
        for motif,m in zip(motifs,data['materials']):
            w,h=m['world_frame'];x,y=m['center']
            values=[float(motif.get(k,-999)) for k in ['x','y','width','height']]
            if values!=[x-w/2,y-h/2,w,h] or motif.get('clip')!=' '.join(map(str,m['source_rect'])): errors.append('browser geometry')
            if motif.get('href')!='material-master.png' or motif.get('filter')!=f"url(#ramp-{case['palette']}-{case['time']}-{m['id']})": errors.append('browser source/filter')
        hero=motifs[-1]
        if [float(hero.get(k,-999)) for k in ['x','y','width','height']]!=[384,110,192,192] or hero.get('clip')!='0 0 192 192' or hero.get('href')!='../vart-002/native/hero-current.png' or hero.get('filter') is not None: errors.append('browser hero')
    filters={f['id']:f for f in proof.get('filters',[])}
    expected={f'ramp-{v}-{t}-{m}' for v in ['a','b'] for t in ['day','evening'] for m in MATERIALS}
    if len(proof.get('filters',[]))!=24 or set(filters)!=expected: errors.append('browser filter coverage')
    for v in ['a','b']:
        for t in ['day','evening']:
            for m in data['materials']:
                f=filters.get(f"ramp-{v}-{t}-{m['id']}",{});ramp=data['variants'][v]['ramps'][m['id']][t]
                tables=[[round(int(c[1+i*2:3+i*2],16)/255,6) for c in ramp] for i in range(3)]
                if f.get('tables')!=tables or f.get('alpha')!='identity' or f.get('space')!='sRGB' or f.get('rect')!=m['source_rect']: errors.append('browser filter contract')
                if f.get('matrix')!='0.2126 0.7152 0.0722 0 0 0.2126 0.7152 0.0722 0 0 0.2126 0.7152 0.0722 0 0 0 0 0 1 0': errors.append('browser luminance contract')
    return sorted(set(errors))


def verify() -> list[str]:
    """Проверяет источник, все двадцать четыре шкалы и синхронность автономного просмотра."""
    data=read(REPORT/'palette.json');source=read(REPORT/'source.json');image=Image.open(REPORT/'material-master.png')
    errors=contract_errors(data,image)
    if image.mode!='RGBA' or list(image.size)!=source['master']['size'] or sha(REPORT/'material-master.png')!=source['master']['sha256']: errors.append('master provenance')
    if sha(REPORT/'prompt-material-master.txt')!=source['prompt_sha256']: errors.append('prompt provenance')
    for key in ['hero_reference','style_reference']:
        ref=source[key]
        if sha(REPORT/ref['path'])!=ref['sha256']: errors.append('reference provenance: '+key)
    profile=read(REPORT/data['scale_profile'])
    if sha(REPORT/data['scale_profile'])!=source['scale_profile_sha256'] or profile['world_zoom']!=data['world_zoom'] or profile['world_field']!=data['world_field']: errors.append('approved scale drift')
    if source.get('runtime_patch')!='' or not re.fullmatch('[0-9a-f]{40}',source.get('base_commit','')): errors.append('runtime/base proof')
    match=re.search(DATA_PATTERN,(REPORT/'index.html').read_text(),re.S)
    if not match or json.loads(match.group(0).split('>',1)[1].rsplit('<',1)[0])!=data: errors.append('stale viewer data')
    if not errors and read(REPORT/'measurements.json')!=measurements(data,image): errors.append('stale measurements')
    errors+=browser_errors(read(REPORT/'browser-check.json'),data)
    artifacts=read(REPORT/'browser-artifacts.json')
    expected={f'{v}-{t}-browser.png' for v in ['a','b'] for t in ['day','evening']}|{'grayscale-browser.png','materials-dark-browser.jpg','review-browser.jpg','browser-check.json'}
    if set(artifacts)!=expected: errors.append('browser artifact coverage')
    for name in expected:
        if not (REPORT/name).is_file() or sha(REPORT/name)!=artifacts.get(name): errors.append('browser artifact hash: '+name)
    return errors


def main() -> None:
    """Обновляет только встроенные данные просмотра либо проверяет сохранённый отчёт."""
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',action='store_true');args=parser.parse_args()
    if args.write:
        data=read(REPORT/'palette.json');image=Image.open(REPORT/'material-master.png');errors=contract_errors(data,image)
        if errors: raise SystemExit('\n'.join(errors))
        path=REPORT/'index.html';encoded=json.dumps(data,ensure_ascii=False,separators=(',',':'))
        path.write_text(re.sub(DATA_PATTERN,lambda m:m[1]+encoded+m[2],path.read_text(),flags=re.S))
        (REPORT/'measurements.json').write_text(json.dumps(measurements(data,image),ensure_ascii=False,indent=2)+'\n')
    errors=verify()
    if errors: raise SystemExit('\n'.join(errors))
    print('VISUAL PALETTE: six motifs, 24 ramps, alpha bounds, source hashes and scale valid; choice '+read(REPORT/'palette.json')['status'])


if __name__=='__main__': main()
