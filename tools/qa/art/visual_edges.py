#!/usr/bin/env python3
"""Проверяет происхождение и сравнимость макетов VART-005, не принимает графику автоматически."""
import argparse
from collections import Counter, deque
import hashlib
import json
from pathlib import Path
import re
from PIL import Image

from tools.common.paths import project_root

ROOT=project_root(__file__)
REPORT=ROOT/'docs/reports/visual-overhaul/vart-005'
PATTERN=r'(<script type="application/json" id="edge-data">).*?(</script>)'


def read(path):
    """Читает декларативные данные без исполнения содержимого."""
    return json.loads(path.read_text())


def sha(path):
    """Связывает проверку с конкретными байтами источника."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contract_errors(data,image):
    """Отклоняет скрытое принятие, смену масштаба и обрезание измеренного силуэта."""
    errors=[]
    expected={'schema':1,'task':'VART-005','runtime_integration':False,'output_size':[1152,648],
              'world_field':[960,540],'camera_center':[480,270],'world_zoom':1.2,'hero_feet':[480,430]}
    for key,value in expected.items():
        if data.get(key)!=value: errors.append('contract: '+key)
    if image.mode!='RGBA' or list(image.size)!=data.get('master_size'): errors.append('RGBA source')
    state=data.get('status')
    if state=='approved':
        if data.get('selection') not in ['a','b'] or not data.get('decision_quote') or data.get('decision_source')!='direct user reply in chat': errors.append('unconfirmed choice')
        if not re.fullmatch(r'\d{4}-\d{2}-\d{2}',data.get('decision_date','')): errors.append('missing decision date')
    elif state!='awaiting_user_choice' or data.get('selection') is not None: errors.append('unconfirmed choice')
    if data.get('outline')!={'radius_world':0.75,'opacity':0.65,'mask_exponent':4,'source_graphic':'unchanged','blur':False}: errors.append('outline experiment')
    parts=data.get('parts',[])
    if len(parts)!=6 or {p['id'] for p in parts}!={'tree','bench','reeds','grass','path','shore'}: errors.append('part coverage')
    if image.mode!='RGBA': return errors
    for part in parts:
        rect=part.get('source_rect',[])
        if len(rect)!=4 or any(type(v)!=int for v in rect): errors.append('integer region'); continue
        x,y,w,h=rect
        if min(x,y)<0 or min(w,h)<=0 or x+w>image.width or y+h>image.height: errors.append('region outside master'); continue
        alpha=image.getchannel('A').crop((x,y,x+w,y+h))
        bbox=alpha.point(lambda a:255 if a>=26 else 0).getbbox()
        if not bbox or min(bbox[0],bbox[1],w-bbox[2],h-bbox[3])<4: errors.append('clipped silhouette')
        k=part['world_scale'];fx,fy=part['feet']
        if not 0<k<=1 or fx-w*k/2<0 or fx+w*k/2>960 or fy-h*k<0 or fy>540: errors.append('world geometry')
    return sorted(set(errors))


def measurements(data,image):
    """Измеряет альфу и расстояние полупрозрачного края до плотного тела; PNG не меняет."""
    result={'schema':1,'profile_sha256':sha(REPORT/'edge-profile.json'),'visible_threshold':26,'core_threshold':240,'parts':{}}
    for part in data['parts']:
        x,y,w,h=part['source_rect'];alpha=image.getchannel('A').crop((x,y,x+w,y+h));values=list(alpha.getdata());counts=Counter(values)
        # Расстояние Чебышёва до плотного тела, ограничено 12 исходными px.
        # Это диагностический показатель, не толщина обводки и не критерий художественного выбора.
        distances=[-1]*len(values);queue=deque()
        for i,a in enumerate(values):
            if a>=240: distances[i]=0;queue.append(i)
        while queue:
            i=queue.popleft();dist=distances[i]+1
            if dist>12: continue
            px,py=i%w,i//w
            for yy in range(max(0,py-1),min(h,py+2)):
                for xx in range(max(0,px-1),min(w,px+2)):
                    j=yy*w+xx
                    if distances[j]<0: distances[j]=dist;queue.append(j)
        soft=[distances[i] if distances[i]>=0 else 13 for i,a in enumerate(values) if 26<=a<240];soft.sort()
        p95=soft[min(len(soft)-1,int(len(soft)*.95))] if soft else 0
        result['parts'][part['id']]={'visible_bbox':list(alpha.point(lambda a:255 if a>=26 else 0).getbbox()),
            'alpha_zero':counts[0],'alpha_1_25':sum(counts[a] for a in range(1,26)),
            'alpha_26_239':len(soft),'alpha_240_255':sum(counts[a] for a in range(240,256)),
            'edge_distance_p95_source_px':p95,'edge_distance_p95_output_px':round(p95*part['world_scale']*1.2,4),
            'soft_pixels_farther_than_12_source_px':sum(v==13 for v in soft)}
    result['interpretation']='RGB при alpha=0 не виден при композиции. Расстояние не доказывает отсутствие matte; кайма и читаемость проверены вручную на четырёх фонах. Почти непрозрачное тело 252–253/255 не считается размытой кромкой.'
    return result


def browser_errors(proof,data):
    """Сверяет реальную DOM-геометрию восьми просмотров и схему фильтра B."""
    errors=[];cases=proof.get('cases',[])
    if proof.get('kind')!='browser-svg-preview' or proof.get('native_game_frame') is not False: errors.append('browser classification')
    if len(cases)!=8 or {(c['variant'],c['background']) for c in cases}!={(v,b) for v in ['a','b'] for b in data['backgrounds']}: errors.append('browser coverage')
    for case in cases:
        if case.get('size')!=[1152,648] or case.get('viewBox')!='0 0 960 540': errors.append('browser scale')
        bg=data['backgrounds'][case['background']]['color'];rgb='rgb('+', '.join(str(int(bg[i:i+2],16)) for i in (1,3,5))+')'
        if case.get('background_color')!=rgb: errors.append('browser background')
        if len(case.get('parts',[]))!=6: errors.append('browser parts');continue
        for actual,part in zip(case['parts'],data['parts']):
            _,_,sw,sh=part['source_rect'];w,h=sw*part['world_scale'],sh*part['world_scale'];x,y=part['feet']
            if actual['id']!=part['id'] or actual['source']!=' '.join(map(str,part['source_rect'])) or actual['clip']!=actual['source'] or actual['href']!=data['master']: errors.append('browser source')
            if any(abs(a-b)>1e-9 for a,b in zip(map(float,actual['size'].split()),[w,h])) or actual['feet']!=' '.join(map(str,part['feet'])): errors.append('browser dimensions')
            numbers=list(map(float,re.findall(r'[-+]?\d*\.?\d+(?:e[-+]?\d+)?',actual['transform'])))
            if len(numbers)!=2 or abs(numbers[0]-(x-w/2))>1e-9 or abs(numbers[1]-(y-h))>1e-9: errors.append('browser position')
            nodes=actual['filter_nodes']
            if case['variant']=='a':
                if actual['filter'] is not None or nodes: errors.append('A has added filter')
            else:
                if actual['filter']!=f"url(#stage-{part['id']}-b)" or [n['tag'] for n in nodes]!=['feComponentTransfer','feMorphology','feFlood','feComposite','feMerge']: errors.append('B filter schema');continue
                if nodes[0]['attrs']!={'in':'SourceAlpha','result':'mask'} or nodes[0]['children']!=[{'tag':'feFuncA','attrs':{'type':'gamma','amplitude':'1','exponent':'4','offset':'0'}}]: errors.append('B mask')
                if nodes[1]['attrs']!={'in':'mask','operator':'dilate','radius':'0.75','result':'expanded'} or nodes[2]['attrs']!={'flood-color':part['contour'],'flood-opacity':'0.65','result':'ink'}: errors.append('B contour')
                if nodes[3]['attrs']!={'in':'ink','in2':'expanded','operator':'in','result':'line'} or nodes[4]['children']!=[{'tag':'feMergeNode','attrs':{'in':'line'}},{'tag':'feMergeNode','attrs':{'in':'SourceGraphic'}}]: errors.append('B source changed')
        hero=case['hero']
        if any(hero.get(k)!=v for k,v in {'x':'384','y':'270','width':'192','height':'192','viewBox':'0 0 192 192','overflow':'hidden'}.items()): errors.append('browser hero')
        if case.get('hero_image')!=data['hero']: errors.append('browser hero source')
        if len(case['magnifiers'])!=6 or any(m['size']!=[480,190] for m in case['magnifiers']): errors.append('diagnostic magnifier')
    return sorted(set(errors))


def verify():
    """Проверяет сохранённые файлы, не перегенерируя доказательства принятия."""
    data=read(REPORT/'edge-profile.json');source=read(REPORT/'source.json');image=Image.open(REPORT/data['master']);errors=contract_errors(data,image)
    for record in [source['master'],source['prompt']]:
        if sha(REPORT/record['path'])!=record['sha256']: errors.append('source hash')
    for path,digest in source['references'].items():
        if sha(REPORT/path)!=digest: errors.append('reference hash')
    scale=read(REPORT/data['scale_profile']);palette=read(REPORT/'../vart-003/palette.json')
    if scale['world_zoom']!=data['world_zoom'] or scale['world_field']!=data['world_field'] or palette['selection']!='a': errors.append('approved reference')
    if source.get('runtime_patch')!='': errors.append('runtime scope')
    match=re.search(PATTERN,(REPORT/'index.html').read_text(),re.S)
    if not match or json.loads(match[0].split('>',1)[1].rsplit('<',1)[0])!=data: errors.append('stale viewer')
    if read(REPORT/'measurements.json')!=measurements(data,image): errors.append('stale alpha measurements')
    errors+=browser_errors(read(REPORT/'browser-check.json'),data)
    artifacts=read(REPORT/'browser-artifacts.json')
    expected={f'{v}-{b}-browser.jpg' for v in ['a','b'] for b in data['backgrounds']}|{'review-browser.jpg','details-dark-browser.jpg','browser-check.json'}
    if set(artifacts)!=expected: errors.append('browser artifact coverage')
    for name,digest in artifacts.items():
        if sha(REPORT/name)!=digest: errors.append('browser artifact hash')
        if name.endswith('-browser.jpg'):
            with Image.open(REPORT/name) as frame:
                if frame.format!='JPEG': errors.append('browser codec')
                if name not in ['review-browser.jpg','details-dark-browser.jpg'] and list(frame.size)!=[1152,648]: errors.append('browser frame size')
    return errors


def main():
    """Обновляет только данные просмотра/измерений либо проверяет паспорт."""
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',action='store_true');args=parser.parse_args()
    if args.write:
        data=read(REPORT/'edge-profile.json');image=Image.open(REPORT/data['master']);errors=contract_errors(data,image)
        if errors: raise SystemExit('\n'.join(errors))
        path=REPORT/'index.html';encoded=json.dumps(data,ensure_ascii=False,separators=(',',':'));path.write_text(re.sub(PATTERN,lambda m:m[1]+encoded+m[2],path.read_text(),flags=re.S))
        (REPORT/'measurements.json').write_text(json.dumps(measurements(data,image),ensure_ascii=False,indent=2)+'\n')
    errors=verify()
    if errors: raise SystemExit('\n'.join(errors))
    print('VISUAL EDGES: six regions, 8 browser cases, alpha, sources and explicit choice valid')


if __name__=='__main__': main()
