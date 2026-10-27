#!/usr/bin/env python3
"""Проверяет стандарт трёх ракурсов и его связь с настоящими ресурсами Godot."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
from PIL import Image

from common.paths import project_root

ROOT=project_root(__file__)
REPORT=ROOT/'docs/reports/visual-overhaul/vart-004'
PATTERN=r'(<script type="application/json" id="perspective-data">).*?(</script>)'
KINDS={'workbench','rustic_table','wooden_wardrobe'}
SIDES={'south':0,'west':1,'east':3}
SOURCES={'AGENTS.md','scripts/systems/furniture_facing_system.gd','scripts/presentation/basement_visual_system.gd','scripts/presentation/house_furniture_visual_system.gd','scripts/presentation/world_workbench_visual_system.gd','scripts/systems/farm_life_visual_system.gd','scripts/systems/house_furniture_layout_system.gd','scripts/systems/basement_layout_system.gd','scripts/systems/basement_data.gd','tools/visual_perspective_export.gd','docs/reports/visual-overhaul/vart-002/scale-profile.json','docs/reports/visual-overhaul/vart-002/native/hero-current.png','docs/reports/visual-overhaul/vart-003/palette.json'}


def read(path: Path) -> dict:
    """Читает сохранённый паспорт без выполнения вложенных данных."""
    return json.loads(path.read_text())


def sha(path: Path) -> str:
    """Связывает отчёт с точными байтами исходника и контрольного кадра."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def near(left: list, right: list) -> bool:
    """Сравнивает экспортные размеры без сокрытия заметного изменения пропорций."""
    return len(left)==len(right) and all(abs(a-b)<0.001 for a,b in zip(left,right))


def contract_errors(data: dict, export: dict) -> list[str]:
    """Отклоняет лишние стороны, разный масштаб, скользящую опору и несогласованный экспорт."""
    errors=[]
    if data.get('status')!='accepted_existing_user_rule' or not data.get('approval',{}).get('source') or data.get('runtime_integration') is not False: errors.append('approval/classification')
    if len(data.get('landmark_acceptance',[]))!=3: errors.append('missing physical landmarks')
    for key,value in {'task':'VART-004','directions':[0,1,3],'legacy_up_alias':0,'world_field':[960,540],'output_size':[1152,648],'camera_center':[480,270],'hero_feet':[480,480],'world_zoom':1.2,'grid':24}.items():
        if data.get(key)!=value: errors.append('standard: '+key)
    if export.get('kind')!='headless-resource-metadata' or export.get('native_game_frame') is not False or export.get('selectable')!=[0,1,3]: errors.append('export classification')
    families=data.get('families',[]);native={f['kind']:f for f in export.get('families',[])}
    if len(families)!=3 or {f['id'] for f in families}!=KINDS or set(native)!=KINDS: errors.append('family coverage')
    for family in families:
        scale=family['source_scale'];views=family.get('views',[])
        if scale<=0 or len(views)!=3 or {v.get('side') for v in views}!=set(SIDES): errors.append('side coverage'); continue
        native_views={p['name']:p for p in native.get(family['id'],{}).get('poses',[])}
        for v in views:
            side=v['side'];p=native_views.get(side,{})
            if v.get('direction') not in [0,1,3]: errors.append('forbidden facing'); continue
            if v['direction']!=SIDES[side] or p.get('direction')!=v['direction'] or p.get('legacy_up_alias')!=0 or p.get('next')!={0:1,1:3,3:0}[v['direction']] or p.get('previous')!={0:3,1:0,3:1}[v['direction']]: errors.append('facing owner')
            source=v['source_rect'];w,h=v['footprint'];x,y=v['origin'];anchor=v['anchor']
            if len(source)!=4 or any(type(n)!=int for n in source) or min(source)<0 or min(source[2:])<=0: errors.append('integer source'); continue
            if source!=p.get('source_rect') or not near(v['runtime_visual_size'],p.get('runtime_visual_size',[])) or v['footprint']!=p.get('footprint'): errors.append('export drift')
            if not near(v['visual_size'],[source[2]*scale,source[3]*scale]): errors.append('nonuniform family scale')
            if any(n%24 for n in [x,y,w,h]) or min(w,h)<=0: errors.append('grid edges')
            if not near(anchor,[x+w/2,y+h]): errors.append('anchor drift')
            if x<0 or y<0 or x+w>960 or y+h>540: errors.append('field bounds')
            vector={0:[0,1],1:[-1,0],3:[1,0]}[v['direction']];center=[x+w/2,y+h/2];edge=[center[0]+vector[0]*w/2,center[1]+vector[1]*h/2]
            if not near(v['edge'],edge) or not near(v['work_tip'],[edge[i]+vector[i]*36 for i in [0,1]]): errors.append('working side')
            if abs(v['runtime_scale_ratio']-v['runtime_visual_size'][0]/v['visual_size'][0])>0.00001: errors.append('incorrect scale comparison')
    if {v.get('id') for v in data.get('rejected',[])}!={'diagonal','rear'}: errors.append('negative examples')
    return sorted(set(errors))


def browser_errors(proof: dict, data: dict) -> list[str]:
    """Проверяет все реальные браузерные варианты и отсутствие плоского вращения рисунков."""
    errors=[];cases=proof.get('cases',[]);families={f['id']:f for f in data['families']}
    if proof.get('kind')!='browser-svg-reference' or proof.get('native_game_frame') is not False: errors.append('browser classification')
    expected={(k,m,b) for k in KINDS for m in ['reference','runtime'] for b in ['light','dark','grass']}
    if len(cases)!=18 or {(c['family'],c['mode'],c['background']) for c in cases}!=expected: errors.append('browser coverage')
    for case in cases:
        if case.get('family') not in families or case.get('mode') not in ['reference','runtime']: errors.append('unknown browser mode'); continue
        if case.get('size')!=[1152,648] or case.get('viewBox')!='0 0 960 540': errors.append('browser projection')
        rows=case.get('views',[])
        if len(rows)!=3: errors.append('browser side coverage'); continue
        for got,v in zip(rows,families[case['family']]['views']):
            size=v['visual_size'] if case['mode']=='reference' else v['runtime_visual_size'];ax,ay=v['anchor']
            expected_rect=[ax-size[0]/2,ay-size[1],*size]
            if not near(got['rect'],expected_rect) or got['clip']!=' '.join(map(str,v['source_rect'])) or got['side']!=v['side'] or got['file']!=v['file']: errors.append('browser geometry/source')
            if got.get('transform') is not None or got.get('css_transform')!='none': errors.append('flat rotation')
        views=families[case['family']]['views']
        if case.get('bases')!=[v['origin']+v['footprint'] for v in views]: errors.append('browser footprint')
        for got,v in zip(case.get('arrows',[]),views):
            if not near(got,v['edge']+v['work_tip']): errors.append('browser working side')
        if len(case.get('arrows',[]))!=3 or len(case.get('pivots',[]))!=3 or case.get('hero')!=[384,320,192,192]: errors.append('browser anchors/hero')
        for got,v in zip(case.get('pivots',[]),views):
            x,y=v['anchor'];expected=f'M {x-5:g} {y:g} H {x+5:g} M {x:g} {y-5:g} V {y+5:g}'
            if got!=expected: errors.append('browser pivot position')
    return sorted(set(errors))


def verify() -> list[str]:
    """Сверяет сохранённый экспорт, оригинальные копии и автономные данные страницы."""
    data=read(REPORT/'standard.json');source=read(REPORT/'source.json');export=read(REPORT/'runtime-export.json');errors=contract_errors(data,export)
    expected={v['file'] for f in data['families'] for v in f['views']}|{v['file'] for v in data['rejected']}
    if set(source['files'])!=expected: errors.append('source coverage')
    if set(source.get('sources',{}))!=SOURCES or any(not re.fullmatch('[0-9a-f]{64}',v) for v in source.get('sources',{}).values()): errors.append('source code proof')
    if sha(REPORT/'runtime-export.json')!=source['runtime_export_sha256'] or source.get('runtime_patch')!='' or not re.fullmatch('[0-9a-f]{40}',source.get('base_commit','')): errors.append('export/base provenance')
    for file,meta in source['files'].items():
        path=REPORT/file
        if not path.is_file() or sha(path)!=meta['sha256']: errors.append('master provenance: '+file); continue
        with Image.open(path) as image:
            if list(image.size)!=meta['size']: errors.append('master size: '+file)
    for f in data['families']:
        for v in f['views']:
            x,y,w,h=v['source_rect'];width,height=source['files'][v['file']]['size']
            if x<0 or y<0 or x+w>width or y+h>height: errors.append('source outside image')
            p=next(p for n in export['families'] if n['kind']==f['id'] for p in n['poses'] if p['name']==v['side'])
            if source['files'][v['file']]['original']!=p['file']: errors.append('wrong resource owner')
    match=re.search(PATTERN,(REPORT/'index.html').read_text(),re.S)
    if not match or json.loads(match.group(0).split('>',1)[1].rsplit('<',1)[0])!=data: errors.append('stale viewer')
    errors+=browser_errors(read(REPORT/'browser-check.json'),data)
    artifacts=read(REPORT/'browser-artifacts.json')
    expected={'workbench-reference.png','workbench-runtime.png','rustic_table-reference.png','wooden_wardrobe-reference.png','wooden_wardrobe-dark.png','rustic_table-grass.png','review-browser.jpg','browser-check.json'}
    if set(artifacts)!=expected: errors.append('browser artifact coverage')
    for file,digest in artifacts.items():
        if not (REPORT/file).is_file() or sha(REPORT/file)!=digest: errors.append('browser artifact hash: '+file)
    proof=read(REPORT/'export-check.json');expected=source['runtime_export_sha256']
    if proof.get('native_game_frame') is not False or proof.get('overwrite_exit_code')!=2 or any(proof.get(k)!=expected for k in ['first_sha256','repeat_sha256','after_refusal_sha256']): errors.append('export repeat/refusal')
    if sha(REPORT/'overwrite-refused.txt')!=proof.get('refusal_log_sha256'): errors.append('refusal log hash')
    return sorted(set(errors))


def main() -> None:
    """Синхронизирует встроенные данные или проверяет неизменный эталон ракурсов."""
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',action='store_true');args=parser.parse_args()
    if args.write:
        data=read(REPORT/'standard.json');path=REPORT/'index.html';encoded=json.dumps(data,ensure_ascii=False,separators=(',',':'))
        path.write_text(re.sub(PATTERN,lambda m:m[1]+encoded+m[2],path.read_text(),flags=re.S))
    errors=verify()
    if errors: raise SystemExit('\n'.join(errors))
    print('VISUAL PERSPECTIVE: three sides, nine sources, uniform reference scale, grid, anchors and browser proof valid')


if __name__=='__main__': main()
