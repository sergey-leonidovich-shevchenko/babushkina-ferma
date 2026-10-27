#!/usr/bin/env python3
"""Проверяет реальные мастера и нарезку VART-008; не принимает художественный вкус за пользователя."""
import hashlib
import json
from pathlib import Path
import re
from PIL import Image

from common.paths import project_root
from common.history import pinned_sha

ROOT=project_root(__file__)
CAPTURE_SOURCE = ('tools/visual_modules_capture.gd',
    'd609ab4fa6d82d6d013265183f018b8836abf7cc',
    'f2bc0bf2af0f96c78e15101ca23685600d1752c5bda15e0fbd383ca22e6d5b5b')
REPORT=ROOT/'docs/reports/visual-overhaul/vart-008'


def sha(path):
    """Связывает нарезку и протокол с исходными байтами."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    """Читает декларативные условия без обращения к игре."""
    return json.loads(path.read_text())


def contract_errors(data,measure,capture):
    """Отклоняет потерю покрытия, обрезку, диагональный поворот и ложные нативные доказательства."""
    errors=[]
    for key,value in {'schema':1,'task':'VART-008','status':'approved','selection':'both','runtime_integration':False,
                      'target':[1152,648],'field':[960,540],'zoom':1.2,'grid':24,'light':'VART-007 A',
                      'direction':'VART-001 A','palette':'VART-003 A','density':'VART-006 B','edge':'VART-005 A'}.items():
        if data.get(key)!=value:errors.append('contract: '+key)
    if not data.get('decision_quote') or data.get('decision_source')!='direct user reply in chat':errors.append('unconfirmed choice')
    counts={kind:sum(p['kind']==kind for p in data['parts']) for kind in ['clump','bush','tree','material','road','bank','bridge','facade']}
    if counts!={'clump':8,'bush':2,'tree':1,'material':3,'road':4,'bank':4,'bridge':4,'facade':2}:errors.append('module coverage')
    ids={p['id'] for p in data['parts']}
    if len(ids)!=28 or {e['id'] for e in capture.get('exports',[])}!=ids:errors.append('export coverage')
    for p in data['parts']:
        x,y,w,h=p['rect'];px,py=p['pivot'];box=measure['parts'].get(p['id'],{}).get('visible_bbox',[])
        if len(box)!=4 or min(x,y)<0 or min(w,h)<=0 or not 0<=px<=w or not 0<=py<=h:errors.append('region/pivot');continue
        if p['kind']!='material' and min(box[0],box[1],w-box[2],h-box[3])<3:errors.append('clipped silhouette')
        if p.get('rotation')!=0 or (p['kind'] in ['facade','bridge'] and p.get('facing')!='down'):errors.append('prop direction')
        if p.get('footprint') and any(v%24 for v in p['footprint']):errors.append('grid footprint')
    for kind in ['clump','bush','road','bank','bridge','facade']:
        if len({p['scale'] for p in data['parts'] if p['kind']==kind})!=1:errors.append('family density')
    if data.get('hero_reference',{}).get('visible_height_output')!=97.2:errors.append('hero scale')
    if data.get('hero_reference',{}).get('scale')!=1 or data['hero_reference']['visible_source_bbox']!=[76,78,117,159]:errors.append('hero measurement')
    if any(data['constraints'][key] for key in ['seamless_autotile_approved','water_animation_approved']):errors.append('unsupported claim')
    for key,value in {'kind':'native-module-study','native_gameplay':False,'performance_eligible':False,'target':[1152,648],
                      'field':[960,540],'texture_loads_inside_draw':0,'texture_filter':'linear_with_mipmaps'}.items():
        if capture.get(key)!=value:errors.append('native: '+key)
    if capture.get('display_server') in [None,'headless'] or not capture.get('profile','').startswith('Codex-VART-008-'):errors.append('native profile')
    matrix=capture.get('projection',[])
    if len(matrix)!=3 or any(len(row)!=2 for row in matrix) or any(abs(a-b)>1e-6 for row,expected in zip(matrix,[[1.2,0],[0,1.2],[0,0]]) for a,b in zip(row,expected)):
        errors.append('native projection')
    expected={page+'-'+bg for page in ['foliage','terrain','structures'] for bg in ['light','dark','grass']}
    expected|={'pilot-'+v+'-'+mode for v in ['a','b'] for mode in ['front','back','bridge','grid','hud']}
    frames=capture.get('frames',[])
    if len(frames)!=19 or {f['id'] for f in frames}!=expected:errors.append('frame coverage')
    if any(f.get('size')!=[1152,648] or f.get('repeat_equal') is not True for f in frames):errors.append('readback')
    return sorted(set(errors))


def verify():
    """Сравнивает каждый экспорт с точным регионом мастера и сверяет нативные PNG."""
    data=read(REPORT/'modules.json');measure=read(REPORT/'measurements.json');capture=read(REPORT/'native/capture.json')
    source=read(REPORT/'source.json');browser=read(REPORT/'browser.json')
    errors=contract_errors(data,measure,capture)
    digest=sha(REPORT/'modules.json')
    if capture['profile_sha256']!=digest or measure['profile_sha256']!=digest:errors.append('profile hash')
    if capture['script_sha256']!=pinned_sha(ROOT, *CAPTURE_SOURCE):errors.append('script hash')
    for path,digest in {**data['source_hashes'],**data['prompt_hashes'],**data['revision_reference_hashes'],**capture['sources']}.items():
        if sha(REPORT/path)!=digest:errors.append('source hash: '+path)
    for path,digest in source['contracts'].items():
        if sha(REPORT/path)!=digest:errors.append('reference contract: '+path)
    for master in source['masters'].values():
        if sha(REPORT/master['master'])!=master['sha256']:errors.append('master provenance')
    cases=browser.get('cases',[])
    if browser.get('native_game_frame') is not False or browser.get('css_stage')!=[1152,648] or browser.get('catalog_links')!=28:errors.append('browser classification')
    if len(cases)!=19 or {c['src'] for c in cases}!={'native/'+f['file'] for f in capture['frames']}:errors.append('browser coverage')
    if any(c.get('loaded') is not True or c.get('size')!=[1152,648] for c in cases):errors.append('browser images')
    for p in data['parts']:
        x,y,w,h=p['rect'];entry=next(e for e in capture['exports'] if e['id']==p['id']);path=REPORT/'native'/entry['file']
        with Image.open(REPORT/p['source']) as master, Image.open(path) as export:
            if x+w>master.width or y+h>master.height:errors.append('source bounds');continue
            crop=master.crop((x,y,x+w,y+h))
            if export.size!=(w,h) or crop.mode!=export.mode or crop.tobytes()!=export.tobytes():errors.append('changed crop: '+p['id'])
            alpha=crop.getchannel('A') if crop.mode=='RGBA' else Image.new('L',crop.size,255)
            bbox=list(alpha.point(lambda v:255 if v>=26 else 0).getbbox())
            if bbox!=measure['parts'][p['id']]['visible_bbox']:errors.append('measured bbox')
            if p['kind']!='material' and alpha.getextrema()[0]!=0:errors.append('opaque backdrop')
        if sha(path)!=entry['sha256'] or entry['rect']!=p['rect'] or entry['source']!=p['source']:errors.append('export provenance')
    for f in capture['frames']:
        path=REPORT/'native'/f['file']
        with Image.open(path) as image:
            if image.size!=(1152,648) or sha(path)!=f['sha256']:errors.append('native PNG')
    for v in ['a','b']:
        hashes={sha(REPORT/'native'/('pilot-'+v+'-'+mode+'.png')) for mode in ['front','back','bridge','grid','hud']}
        if len(hashes)!=5:errors.append('collapsed views')
    page=(REPORT/'index.html').read_text();match=re.search(r'<script type="application/json" id="module-data">(.*?)</script>',page,re.S)
    if not match or json.loads(match[1])!=data:errors.append('HTML data')
    return sorted(set(errors))


if __name__=='__main__':
    errors=verify()
    if errors:raise SystemExit('\n'.join(errors))
    print('VART-008: both facades approved, 28 exact crops, 19 native frames, camera and sources valid')
