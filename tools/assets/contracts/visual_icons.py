#!/usr/bin/env python3
"""VART-010: происхождение, два экранных размера и честная отдельная художественная приёмка."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from PIL import Image
from tools.common.paths import project_root

from tools.qa.art.visual_reuse import baseline_bytes
from tools.common.history import pinned_sha

ROOT=project_root(__file__)
CAPTURE_SOURCE = ('tools/visual_icons_capture.gd',
    'd609ab4fa6d82d6d013265183f018b8836abf7cc',
    'bd0449587db04950b8dae2713cab832ac7a8dc9c16d7c3e41b16ac488c5359f2')
REPORT=ROOT/'docs/reports/visual-overhaul/vart-010'
IDS={'bread','iron_ore','herbs','healing_potion','axe','travel_boots'}


def read(path):
    """Читает паспорт без доступа к игровому состоянию."""
    return json.loads(path.read_text())


def sha(path):
    """Связывает приёмку с точными байтами файла."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contract_errors(data,review,capture):
    """Отклоняет пропущенную категорию, ложный выбор, масштабирование UI и неполное доказательство."""
    errors=[]
    if data.get('task')!='VART-010' or data.get('status')!='study_ready' or data.get('runtime_integration') is not False:errors.append('study scope')
    if len(data.get('items',[]))!=6 or {i['id'] for i in data['items']}!=IDS or {i['category'] for i in data['items']}!={'food','ore','herb','flask','tool','clothing'}:errors.append('item coverage')
    expected={v+'-'+i for v in ['a','b'] for i in IDS}
    if len(data.get('entries',[]))!=12 or {e['id'] for e in data['entries']}!=expected:errors.append('variant coverage')
    if data.get('sizes')!=[64,160] or data.get('padding')!={'64':3,'160':8} or data.get('ui_scale')!=1.0:errors.append('screen sizes')
    if any(data.get('claims',{}).values()):errors.append('unsupported claims')
    if review.get('runtime_integration') is not False:errors.append('runtime approval')
    if review.get('status')=='awaiting_selection':
        if review.get('selection') is not None or review.get('source') is not None or review.get('quote') is not None:errors.append('invented choice')
    elif review.get('status')=='approved':
        if review.get('selection') not in ['a','b'] or review.get('source')!='direct user reply in chat' or not review.get('quote'):errors.append('unconfirmed choice')
    else:errors.append('review status')
    if capture.get('kind')!='native-icon-study' or capture.get('native_gameplay') is not False or capture.get('performance_eligible') is not False:errors.append('native classification')
    if capture.get('target')!=[1152,648] or capture.get('ui_scale')!=1.0 or capture.get('projection')!=[[1,0],[0,1],[0,0]]:errors.append('native scale')
    if capture.get('display_server') in [None,'headless'] or not capture.get('profile','').startswith('Codex-VART-010-'):errors.append('native profile')
    if capture.get('loads_inside_draw')!=0 or capture.get('masters_used_for_ui') is not False:errors.append('texture preparation')
    pairs={(e['id'],e['size']) for e in capture.get('exports',[])}
    if len(capture.get('exports',[]))!=24 or pairs!={(i,n) for i in expected for n in [64,160]}:errors.append('export coverage')
    if len(capture.get('old',[]))!=12 or {(e['id'],e['size']) for e in capture['old']}!={(i,n) for i in IDS for n in [64,160]}:errors.append('baseline coverage')
    frames={f'catalog-{v}-{bg}' for v in ['a','b'] for bg in ['light','dark','game']}|{f'focus-{i}-{bg}' for i in IDS for bg in ['light','dark','game']}
    if len(capture.get('frames',[]))!=24 or {f['id'] for f in capture['frames']}!=frames:errors.append('frame coverage')
    if any(f.get('size')!=[1152,648] or f.get('repeat_equal') is not True for f in capture.get('frames',[])):errors.append('readback')
    return sorted(set(errors))


def page_data():
    """Встраивает все условия в автономный HTML, не требуя сети."""
    return {'study':read(REPORT/'icons.json'),'review':read(REPORT/'review.json')}


def verify():
    """Проверяет мастера, размерные экспорты и настоящий readback; вкус пользователя не подменяет числом."""
    data=read(REPORT/'icons.json');review=read(REPORT/'review.json');capture=read(REPORT/'native/capture.json');errors=contract_errors(data,review,capture)
    source=read(REPORT/'source.json')
    if source['generator']!='built-in image_gen' or source['master_catalog']!='icons.json':errors.append('generator provenance')
    for attempt in source['discarded']:
        if sha(REPORT/attempt['file'])!=attempt['sha256'] or sha(REPORT/attempt['prompt'])!=attempt['prompt_sha256']:errors.append('discarded provenance')
    if capture['script_sha256']!=pinned_sha(ROOT, *CAPTURE_SOURCE) or capture['profile_sha256']!=sha(REPORT/'icons.json'):errors.append('capture code/profile')
    for path,digest in data['contracts'].items():
        if sha(REPORT/path)!=digest:errors.append('art contract')
    catalog=data['old_catalog'];baseline_bytes(ROOT/catalog['path'],catalog['sha256'],data['base_commit'])
    for path,digest in {**capture['sources'],**capture['owners']}.items():baseline_bytes(ROOT/path.removeprefix('res://'),digest,data['base_commit'])
    for entry in data['entries']:
        if sha(REPORT/entry['master'])!=entry['sha256'] or sha(REPORT/entry['prompt'])!=entry['prompt_sha256']:errors.append('master provenance')
        for path,digest in entry['references'].items():
            if sha(REPORT/path)!=digest:errors.append('style reference')
        with Image.open(REPORT/entry['master']) as image:
            if image.mode!='RGBA' or list(image.size)!=entry['size'] or min(image.size)<512:errors.append('master size')
            alpha=image.getchannel('A');box=alpha.point(lambda v:255 if v>=26 else 0).getbbox();x,y,w,h=entry['source_rect']
            expected=(box[0]-8,box[1]-8,box[2]+8,box[3]+8)
            if expected!=(x,y,x+w,y+h) or min(x,y,image.width-x-w,image.height-y-h)<2:errors.append('source crop')
            if list(box)!=entry['strong_bbox']:errors.append('measured alpha')
    for export in capture['exports']:
        with Image.open(REPORT/'native'/export['file']) as image:
            n=export['size'];padding=data['padding'][str(n)]
            if image.size!=(n,n) or image.mode!='RGBA' or sha(REPORT/'native'/export['file'])!=export['sha256']:errors.append('export PNG')
            alpha=image.getchannel('A');box=alpha.getbbox()
            if box is None or min(box[0],box[1],n-box[2],n-box[3])<padding:errors.append('clipped export')
            if box is not None and [box[0],box[1],box[2]-box[0],box[3]-box[1]]!=export['used_rect']:errors.append('export bounds')
            entry=next(e for e in data['entries'] if e['id']==export['id']);w,h=entry['source_rect'][2:];factor=(n-padding*2)/max(w,h)
            if box is not None and (abs((box[2]-box[0])-w*factor)>2 or abs((box[3]-box[1])-h*factor)>2):errors.append('stretched export')
    for export in capture['old']:
        with Image.open(REPORT/'native'/export['file']) as image:
            if image.size!=(export['size'],export['size']) or sha(REPORT/'native'/export['file'])!=export['sha256']:errors.append('old PNG')
    for frame in capture['frames']:
        with Image.open(REPORT/'native'/frame['file']) as image:
            if image.size!=(1152,648) or sha(REPORT/'native'/frame['file'])!=frame['sha256']:errors.append('native PNG')
    browser=read(REPORT/'browser.json');cases=browser.get('cases',[])
    if len(cases)!=24 or {c['src'] for c in cases}!={'native/'+f['file'] for f in capture['frames']} or any(c['size']!=[1152,648] or c['complete'] is not True for c in cases):errors.append('browser frames')
    if browser.get('fixed')!=[1152,648] or browser.get('catalog_links')!=24 or browser.get('asset_sizes')!=[64,160]:errors.append('browser controls')
    html=(REPORT/'index.html').read_text();match=re.search(r'<script type="application/json" id="icon-data">(.*?)</script>',html,re.S)
    if not match or json.loads(match[1])!=page_data():errors.append('HTML sync')
    return sorted(set(errors))


def write():
    """Обновляет только встроенные условия; выбор и доказательства не создаёт."""
    path=REPORT/'index.html';path.write_text(re.sub(r'(<script type="application/json" id="icon-data">).*?(</script>)',lambda m:m[1]+json.dumps(page_data(),ensure_ascii=False)+m[2],path.read_text(),flags=re.S))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');args=parser.parse_args()
    if args.write:write()
    errors=verify()
    if errors:raise SystemExit('\n'.join(errors))
    print('VART-010: 12 masters, 24 independent exports, 24 native frames and browser states valid; '+read(REPORT/'review.json')['status'])
