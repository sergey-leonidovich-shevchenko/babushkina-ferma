#!/usr/bin/env python3
"""Паспорт плотности VART-006: сравнимость мастеров, а не автоматическая оценка красоты."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'docs/reports/visual-overhaul/vart-006'
PATTERN=r'(<script type="application/json" id="density-data">).*?(</script>)'


def read(path):
    """Читает декларативный паспорт."""
    return json.loads(path.read_text())


def sha(path):
    """Связывает вывод с неизменёнными байтами источника."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contract_errors(data,images):
    """Отклоняет неподтверждённый выбор, другую камеру и потерю общего героя."""
    errors=[]
    expected={'schema':1,'task':'VART-006','runtime_integration':False,'output_size':[1152,648],
              'world_field':[960,540],'camera_center':[480,270],'world_zoom':1.2,
              'art_direction':'VART-001 A','palette':'VART-003 A','edge':'VART-005 A'}
    for key,value in expected.items():
        if data.get(key)!=value:errors.append('contract: '+key)
    if data.get('status')=='approved':
        if data.get('selection') not in ['a','b'] or not data.get('decision_quote') or data.get('decision_source')!='direct user reply in chat':errors.append('unconfirmed choice')
    elif data.get('status')!='awaiting_user_choice' or data.get('selection') is not None:errors.append('unconfirmed choice')
    if {v['master'] for v in data['variants'].values()}!={'density-a.png','density-b.png'}:errors.append('source assignment')
    if len(data.get('parts',[]))!=5 or {p['id'] for p in data['parts']}!={'hero','door','tree','table','grass'}:errors.append('five subjects')
    for image in images.values():
        if image.mode!='RGBA' or list(image.size)!=data['master_size']:errors.append('RGBA master')
    if errors:return errors
    for part in data['parts']:
        if part.get('source_policy')!=('a_only' if part['id']=='hero' else 'variant'):errors.append('common hero')
        rect=part['source_rect'];x,y,w,h=rect;k=part['world_scale'];fx,fy=part['feet']
        if len(rect)!=4 or any(type(v)!=int for v in rect) or min(x,y)<0 or min(w,h)<=0 or x+w>1536 or y+h>1024:errors.append('source region');continue
        if not 0<k<1 or fx-w*k/2<0 or fx+w*k/2>960 or fy-h*k<0 or fy>540:errors.append('world bounds')
        for image in images.values():
            bbox=image.getchannel('A').crop((x,y,x+w,y+h)).point(lambda a:255 if a>=26 else 0).getbbox()
            if not bbox or min(bbox[0],bbox[1],w-bbox[2],h-bbox[3])<4:errors.append('clipped subject')
    return sorted(set(errors))


def measurements(data,images):
    """Измеряет исходные области без создания, очистки или ресайза изображений."""
    result={'schema':1,'profile_sha256':sha(REPORT/'density-profile.json'),'visible_threshold':26,'parts':{}}
    for part in data['parts']:
        x,y,w,h=part['source_rect'];variants={};masks={}
        for v in ['a','b']:
            image=images['a' if part['source_policy']=='a_only' else v]
            alpha=image.getchannel('A').crop((x,y,x+w,y+h));mask=[a>=26 for a in alpha.getdata()];masks[v]=mask
            bbox=alpha.point(lambda a:255 if a>=26 else 0).getbbox()
            rx,ry,rw,rh=part['roi'];pixels=list(image.crop((rx,ry,rx+rw,ry+rh)).getdata());steps=[]
            for yy in range(rh-1):
                for xx in range(rw-1):
                    p=pixels[yy*rw+xx]
                    for q in [pixels[yy*rw+xx+1],pixels[(yy+1)*rw+xx]]:
                        if min(p[3],q[3])>=240:steps.append(abs(sum((p[i]-q[i])*c for i,c in enumerate([.2126,.7152,.0722]))))
            variants[v]={'source':data['variants']['a' if part['source_policy']=='a_only' else v]['master'],
                         'visible_bbox':list(bbox),'visible_size_output_px':[round((bbox[2]-bbox[0])*part['world_scale']*1.2,4),round((bbox[3]-bbox[1])*part['world_scale']*1.2,4)],
                         'roi_srgb_adjacent_luma_step':round(sum(steps)/len(steps),5),'roi_pairs':len(steps)}
        a,b=variants['a']['visible_bbox'],variants['b']['visible_bbox']
        result['parts'][part['id']]={'variants':variants,
            'bbox_max_edge_drift_output_px':round(max(abs(aa-bb) for aa,bb in zip(a,b))*part['world_scale']*1.2,4),
            'alpha26_intersection_over_union':round(sum(a and b for a,b in zip(masks['a'],masks['b']))/sum(a or b for a,b in zip(masks['a'],masks['b'])),6)}
    result['interpretation']='Соседние sRGB-пиксели измерены в одинаковых внутренних ROI исходников при alpha>=240. Это не экранная плотность, не линейная яркость, не стоимость рендера и не доказательство внимания человека. Незначительный дрейф генерации не нормализуется подгонкой. Герой в обоих вариантах из A.'
    return result


def browser_errors(proof,data):
    """Сверяет 12 просмотров: A/B × три фона × цвет/серая шкала."""
    errors=[];cases=proof.get('cases',[])
    expected={(v,b,m) for v in ['a','b'] for b in data['backgrounds'] for m in [False,True]}
    if proof.get('kind')!='browser-svg-preview' or proof.get('native_game_frame') is not False:errors.append('browser classification')
    if len(cases)!=12 or {(c['variant'],c['background'],c['mono']) for c in cases}!=expected:errors.append('browser coverage')
    for case in cases:
        if any(abs(a-b)>.02 for a,b in zip(case['size'],[1152,648])) or case['viewBox']!='0 0 960 540' or case['labels'] is not False:errors.append('browser camera')
        if case.get('stage_filter')!=('grayscale(1)' if case['mono'] else 'none'):errors.append('full scene grayscale')
        if len(case['parts'])!=5 or len(case['samples'])!=10:errors.append('browser subjects');continue
        for actual,part in zip(case['parts'],data['parts']):
            v='a' if part['source_policy']=='a_only' else case['variant'];_,_,sw,sh=part['source_rect'];w,h=sw*part['world_scale'],sh*part['world_scale'];fx,fy=part['feet']
            if actual['id']!=part['id'] or actual['source']!=data['variants'][v]['master'] or actual['clip']!=' '.join(map(str,part['source_rect'])):errors.append('browser source')
            expected_position=[fx-w/2,fy-h];position=list(map(float,re.findall(r'[-+]?\d*\.?\d+(?:e[-+]?\d+)?',actual['transform'])))
            if len(position)!=2 or any(abs(a-b)>1e-8 for a,b in zip(position,expected_position)):errors.append('browser placement')
            if abs(float(actual['scale'])-part['world_scale'])>1e-12 or any(abs(a-b)>.02 for a,b in zip(actual['projected_size'],[w*1.2,h*1.2])) or actual['overflow']!='hidden':errors.append('browser projection')
            if actual['filter']!='none' or actual['attribute_filter'] is not None:errors.append('browser paint filter')
        for i,actual in enumerate(case['samples']):
            part=data['parts'][i//2];v='a' if part['source_policy']=='a_only' or i%2==0 else 'b';sw,sh=part['source_rect'][2:]
            if actual['id']!=part['id'] or actual['source']!=data['variants'][v]['master'] or actual['clip']!=' '.join(map(str,part['source_rect'])):errors.append('sample source')
            if actual.get('sample_filter')!=('grayscale(1)' if case['mono'] else 'none'):errors.append('full sample grayscale')
            if any(abs(a-b)>.02 for a,b in zip(actual['projected_size'],[sw*part['world_scale']*1.2,sh*part['world_scale']*1.2])) or actual['overflow']!='hidden':errors.append('sample projection')
    return sorted(set(errors))


def native_errors(proof,data):
    """Проверяет настоящие размеры GPU-readback, источники и наличие всех пяти рисунков."""
    errors=[]
    expected={'kind':'native-density-study','native_gameplay':False,'performance_eligible':False,'field':[960,540],'target':[1152,648],'texture_filter':'linear_with_mipmaps','hero_source':'a'}
    for key,value in expected.items():
        if proof.get(key)!=value:errors.append('native: '+key)
    if proof.get('capture_script_sha256')!=sha(ROOT/'tools/visual_density_capture.gd') or proof.get('profile_sha256')!=sha(REPORT/'density-profile.json'):errors.append('native configuration')
    if proof.get('display_server') in ['headless','',None]:errors.append('native graphics')
    if proof.get('source_sha256')!={v:sha(REPORT/x['master']) for v,x in data['variants'].items()}:errors.append('native sources')
    frames=proof.get('frames',[])
    if len(frames)!=6 or {(f['variant'],f['background']) for f in frames}!={(v,b) for v in ['a','b'] for b in data['backgrounds']}:errors.append('native coverage')
    for frame in frames:
        if frame['size']!=[1152,648] or frame['repeat_equal'] is not True:errors.append('native target/repeat')
        matrix=frame['projection'];expected_matrix=[[1.2,0],[0,1.2],[0,0]]
        if len(matrix)!=3 or any(len(row)!=2 for row in matrix) or any(abs(a-b)>1e-6 for row,want in zip(matrix,expected_matrix) for a,b in zip(row,want)):errors.append('native projection')
        path=REPORT/'native'/frame['file']
        if sha(path)!=frame['sha256']:errors.append('native PNG hash')
        with Image.open(path) as image:
            if image.size!=(1152,648) or image.format!='PNG':errors.append('native PNG dimensions')
            bg=image.getpixel((0,0))[:3]
            for part in data['parts']:
                sw,sh=part['source_rect'][2:];k=part['world_scale'];fx,fy=part['feet'];x,y=(fx-sw*k/2)*1.2,(fy-sh*k)*1.2
                crop=image.crop((int(x),int(y),int(x+sw*k*1.2),int(y+sh*k*1.2)))
                if sum(max(abs(int(p[i])-bg[i]) for i in range(3))>16 for p in crop.getdata())<500:errors.append('native subject absent')
    board=proof.get('comparison_board',{})
    if board.get('size')!=[1152,960] or board.get('field')!=[960,800] or board.get('repeat_equal') is not True:errors.append('comparison board')
    path=REPORT/'native'/board.get('file','pairs.png')
    if sha(path)!=board.get('sha256'):errors.append('comparison board hash')
    with Image.open(path) as image:
        if image.size!=(1152,960):errors.append('comparison board dimensions')
    return sorted(set(errors))


def verify():
    """Проверяет сохранённые доказательства и источники, не создавая приёмку."""
    data=read(REPORT/'density-profile.json');source=read(REPORT/'source.json');images={v:Image.open(REPORT/x['master']) for v,x in data['variants'].items()}
    errors=contract_errors(data,images)
    for record in source['masters'].values():
        if sha(REPORT/record['path'])!=record['sha256']:errors.append('master hash')
    if len({r['sha256'] for r in source['masters'].values()})!=2:errors.append('same master twice')
    for path,digest in {**source['prompts'],**source['references']}.items():
        if sha(REPORT/path)!=digest:errors.append('reference/prompt hash')
    if read(REPORT/data['scale_profile'])['world_zoom']!=data['world_zoom'] or source.get('runtime_patch')!='':errors.append('scope/scale')
    match=re.search(PATTERN,(REPORT/'index.html').read_text(),re.S)
    if not match or json.loads(match[0].split('>',1)[1].rsplit('<',1)[0])!=data:errors.append('stale viewer')
    if read(REPORT/'measurements.json')!=measurements(data,images):errors.append('stale measurements')
    for image in images.values():image.close()
    errors+=browser_errors(read(REPORT/'browser-check.json'),data)
    errors+=native_errors(read(REPORT/'native/capture.json'),data)
    artifacts=read(REPORT/'browser-artifacts.json');expected={'browser-check.json'}
    if set(artifacts)!=expected:errors.append('browser artifacts')
    for name,digest in artifacts.items():
        if sha(REPORT/name)!=digest:errors.append('browser hash')
    return sorted(set(errors))


def main():
    """Обновляет только числовой анализ и встроенный профиль либо проверяет результат."""
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',action='store_true');args=parser.parse_args()
    if args.write:
        data=read(REPORT/'density-profile.json');images={v:Image.open(REPORT/x['master']) for v,x in data['variants'].items()};errors=contract_errors(data,images)
        if errors:raise SystemExit('\n'.join(errors))
        p=REPORT/'index.html';p.write_text(re.sub(PATTERN,lambda m:m[1]+json.dumps(data,ensure_ascii=False,separators=(',',':'))+m[2],p.read_text(),flags=re.S))
        (REPORT/'measurements.json').write_text(json.dumps(measurements(data,images),ensure_ascii=False,indent=2)+'\n')
        for image in images.values():image.close()
    errors=verify()
    if errors:raise SystemExit('\n'.join(errors))
    print('VISUAL DENSITY: five subjects, common hero, 12 browser cases, scale and source provenance valid')


if __name__=='__main__':main()
