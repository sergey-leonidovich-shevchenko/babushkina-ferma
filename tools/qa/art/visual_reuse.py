#!/usr/bin/env python3
"""VART-009: полнота решений, происхождение файлов и доказательства нативного сравнения."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import io
import subprocess
from PIL import Image

from tools.common.paths import project_root
from tools.common.git import git_environment
from tools.common.history import pinned_sha

ROOT=project_root(__file__)
CAPTURE_SOURCE = ('tools/visual_reuse_capture.gd',
    'd609ab4fa6d82d6d013265183f018b8836abf7cc',
    '7f40d05788c223c92f30b299c5cb10e5dac16290035b2df3ddfc8a01ded511ba')
ADAPTER_SOURCE = ('tools/visual_reuse_sources.gd',
    'd609ab4fa6d82d6d013265183f018b8836abf7cc',
    '868c354fef37aa46f0678c32f7e99607c8e8cee0e03cf50596bf157f08d3f4ab')
REPORT=ROOT/'docs/reports/visual-overhaul/vart-009'
LABELS={'reuse':'Сохранить','adapt':'Адаптировать','redraw':'Перерисовать'}


def read(path):
    """Читает декларативный паспорт без доступа к игровому состоянию."""
    return json.loads(path.read_text())


def sha(path):
    """Связывает доказательство с точными байтами файла."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def baseline_bytes(path,expected,commit):
    """Проверяет исторический аудит по его commit, не блокируя последующую согласованную замену ассетов."""
    path=path.resolve();relative=path.relative_to(ROOT)
    current=path.read_bytes() if path.is_file() else b''
    if hashlib.sha256(current).hexdigest()==expected:return current
    result=subprocess.run(['git','show',commit+':'+relative.as_posix()],cwd=ROOT,env=git_environment(),capture_output=True,check=True)
    if hashlib.sha256(result.stdout).hexdigest()!=expected:raise ValueError('baseline hash mismatch: '+str(relative))
    return result.stdout


def contract_errors(plan,inventory,capture,manifest,epics):
    """Отклоняет пропущенное семейство, пустое решение, подмену назначения и ложную приёмку."""
    errors=[];expected={e['id'] for e in manifest['entries']};rows=plan.get('families',[])
    if len(rows)!=29 or {r['id'] for r in rows}!=expected:errors.append('family coverage')
    if plan.get('task')!='VART-009' or plan.get('status')!='audit_complete' or plan.get('runtime_integration') is not False or plan.get('deletion_authorized') is not False:errors.append('audit scope')
    by_id={e['id']:e for e in manifest['entries']}
    for row in rows:
        if row['decision'] not in LABELS:errors.append('decision enum')
        if any(len(row.get(k,''))<20 for k in ['reason','preserve','work','caveat']):errors.append('decision rationale')
        if not row.get('owner_epics') or set(row['owner_epics'])-set(epics):errors.append('work owner')
        if row.get('runtime_state')!='unchanged' or row.get('new_art_approved') is not False:errors.append('production approval')
        if row['id'] in by_id and row['asset_paths']!=[a['path'] for a in by_id[row['id']]['assets']]:errors.append('family asset coverage')
    paths={a['path'] for e in manifest['entries'] for a in e['assets']}
    files=inventory.get('files',[])
    if len(files)!=len(paths) or {f['path'] for f in files}!=paths or inventory.get('unique_assets')!=len(paths):errors.append('inventory coverage')
    if inventory.get('declared_assets')!=sum(len(e['assets']) for e in manifest['entries']):errors.append('inventory declarations')
    samples=capture.get('samples',[])
    if len(samples)!=29 or {s['id'] for s in samples}!=expected:errors.append('sample coverage')
    if capture.get('native_gameplay') is not False or capture.get('performance_eligible') is not False or capture.get('kind')!='native-reuse-audit':errors.append('native classification')
    if capture.get('display_server') in [None,'headless'] or not capture.get('profile','').startswith('Codex-VART-009-'):errors.append('native profile')
    if capture.get('target')!=[1152,648] or capture.get('field')!=[960,540]:errors.append('native camera')
    matrix=capture.get('projection',[])
    if len(matrix)!=3 or any(len(r)!=2 for r in matrix) or any(abs(a-b)>1e-6 for row,ref in zip(matrix,[[1.2,0],[0,1.2],[0,0]]) for a,b in zip(row,ref)):errors.append('native projection')
    frame_ids={id+'-'+bg for id in expected for bg in ['light','dark']}
    frame_ids|={'sources-%02d'%i for i in range(1,math.ceil(len(paths)/20)+1)}
    frames=capture.get('frames',[])
    if len(frames)!=len(frame_ids) or {f['id'] for f in frames}!=frame_ids:errors.append('frame coverage')
    for f in frames:
        if f.get('size')!=[1152,648] or f.get('repeat_equal') is not True:errors.append('readback')
        expected_kind='source-overview' if f['id'].startswith('sources-') else ('archive-overview' if f['id'].startswith('WS-001-') else 'world-comparison')
        if f.get('kind')!=expected_kind:errors.append('frame classification')
    if capture.get('overview_paths')!=sorted(paths):errors.append('source overview coverage')
    return sorted(set(errors))


def page_data():
    """Даёт странице проверенные факты без HTTP и скрытого состояния браузера."""
    return {'decisions':read(REPORT/'decisions.json'),'inventory':read(REPORT/'inventory.json'),'capture':read(REPORT/'native/capture.json')}


def decision_markdown(plan):
    """Строит читаемую таблицу из единственного источника решений."""
    lines=['# VART-009 — сохранить, адаптировать или перерисовать','',
           'Аудит от 17 октября 2026. Это рекомендации миграции; новые рисунки и runtime отдельно. Один общий вывод семейства не отменяет явно перечисленные исключения.','',
           '| ID | Семейство | Решение | Причина | Владельцы | Приоритет |','|---|---|---|---|---|---|']
    for f in plan['families']:lines.append('| '+' | '.join([f['id'],f['family'],LABELS[f['decision']],f['reason'],', '.join(f['owner_epics']),f['priority']])+' |')
    for f in plan['families']:
        lines+=['','## '+f['id']+' — '+f['family'],'','**Сохранить:** '+f['preserve'],'','**Работа:** '+f['work'],'','**Оговорка:** '+f['caveat'],'',
                '[Светлый кадр](native/'+f['id']+'-light.png) · [Тёмный кадр](native/'+f['id']+'-dark.png)']
    return '\n'.join(lines)+'\n'


def verify():
    """Сверяет все файлы и код владельцев; отсутствие literal reference не считается неиспользованием."""
    data=page_data();plan=data['decisions'];inv=data['inventory'];capture=data['capture'];commit=plan['base_commit']
    manifest=json.loads(baseline_bytes(ROOT/'assets/game/world_sprite_manifest.json',plan['manifest_sha256'],commit));backlog=read(ROOT/'docs/epics/visual-overhaul-2026-10/backlog.json')
    errors=contract_errors(plan,inv,capture,manifest,[e['id'] for e in backlog['epics']])
    digest=plan['manifest_sha256']
    if any(doc['manifest_sha256']!=digest for doc in [plan,inv,capture]):errors.append('manifest hash')
    if capture['script_sha256']!=pinned_sha(ROOT, *CAPTURE_SOURCE) or capture['adapter_sha256']!=pinned_sha(ROOT, *ADAPTER_SOURCE):errors.append('capture code hash')
    if capture['view_profile_sha256']!=sha(REPORT/'view-profile.json'):errors.append('view profile hash')
    for p,digest in {**plan['evidence_hashes'],**capture['sources'],**capture['owners']}.items():
        path=ROOT/(p.removeprefix('res://'))
        baseline_bytes(path,digest,commit)
    for asset in inv['files']:
        path=ROOT/asset['path']
        blob=baseline_bytes(path,asset['sha256'],commit)
        with Image.open(io.BytesIO(blob)) as image:
            if list(image.size)!=asset['size'] or asset['size']!=asset['declared_size'] or image.mode!=asset['mode']:errors.append('inventory dimensions')
        if len(blob)!=asset['bytes']:errors.append('asset bytes')
    for s in capture['samples']:
        path=ROOT/s['master'].removeprefix('res://')
        blob=baseline_bytes(path,s['master_sha256'],commit)
        if sha(REPORT/'native'/s['file'])!=s['sha256']:errors.append('sample PNG hash')
        with Image.open(io.BytesIO(blob)) as image:
            x,y,w,h=s['region']
            if min(x,y)<0 or min(w,h)<=0 or x+w>image.width+.01 or y+h>image.height+.01:errors.append('sample region')
    for f in capture['frames']:
        path=REPORT/'native'/f['file']
        with Image.open(path) as image:
            if image.size!=(1152,648) or sha(path)!=f['sha256']:errors.append('native PNG')
    browser=read(REPORT/'browser.json');views=browser['frames']
    expected={'native/'+f['file'] for f in capture['frames'] if f['id'].startswith('WS-')}
    if len(views)!=58 or {v['src'] for v in views}!=expected or any(v['size']!=[1152,648] or v['complete'] is not True for v in views):errors.append('browser frames')
    expected_counts={key:sum(f['decision']==key for f in plan['families']) for key in LABELS};expected_counts['all']=29
    if {v['filter']:v['count'] for v in browser['filters']}!=expected_counts or browser['noResult'] is not True or browser['overviewLinks']!=12 or browser['fixed']!={'cssSize':[1152,648],'naturalSize':[1152,648]}:errors.append('browser controls')
    if browser['search']['query']!='свинья' or len(browser['search']['rows'])!=1 or not browser['search']['rows'][0].startswith('WS-017'):errors.append('browser search')
    html=(REPORT/'index.html').read_text();match=re.search(r'<script type="application/json" id="audit-data">(.*?)</script>',html,re.S)
    if not match or json.loads(match[1])!=data:errors.append('HTML sync')
    if (REPORT/'DECISIONS.md').read_text()!=decision_markdown(plan):errors.append('Markdown sync')
    return sorted(set(errors))


def write():
    """Обновляет только производные документы, не меняя оценки, картинки и доказательства."""
    data=page_data();p=REPORT/'index.html';p.write_text(re.sub(r'(<script type="application/json" id="audit-data">).*?(</script>)',lambda m:m[1]+json.dumps(data,ensure_ascii=False)+m[2],p.read_text(),flags=re.S))
    (REPORT/'DECISIONS.md').write_text(decision_markdown(data['decisions']))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');args=parser.parse_args()
    if args.write:write()
    errors=verify()
    if errors:raise SystemExit('\n'.join(errors))
    print('VART-009: 29 decisions, 238 declarations / 236 files, 58 comparisons + 12 overviews valid; runtime unchanged')
