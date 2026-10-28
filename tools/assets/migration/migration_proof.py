#!/usr/bin/env python3
"""Проверяет настоящий rename-only стенд, откат, UID, F12 и отрицательные контроли."""
from __future__ import annotations
import json
from pathlib import Path
import re
import subprocess
from PIL import Image,ImageChops
from tools.assets.migration.migration_inventory import sha, git_bytes
from tools.assets.contracts.source_paths import current_source

REPORT='docs/reports/visual-overhaul/vpipeline-009'
PHASES=['baseline','dual','unadapted','retired','rollback']
SIDES=['south','west','east']


def read(path):
    """Читает только локальные данные конкретного пакета доказательств."""
    return json.loads(path.read_text())


def wiki_contract(catalog):
    """Сравнивает все игровые статьи с их связями и кадрами, разрешая добавление редакционных руководств."""
    entries=sorted((entry for entry in catalog['entries'] if entry['category']!='guides'),key=lambda row:(row['category'],row['id']))
    return {'keys':[entry['category']+'/'+entry['id'] for entry in entries],'entries_sha256':sha(json.dumps(entries,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()),'count':len(entries)}


def comparisons(report):
    """Измеряет весь target и отдельные ряды: новый каталог сверху, старый черновик снизу."""
    values={}
    for phase in PHASES:
        values[phase]={}
        for background in ['dark','light']:
            with Image.open(report/'native/baseline'/(background+'.png')) as first,Image.open(report/'native'/phase/(background+'.png')) as current:
                delta=ImageChops.difference(first,current).convert('RGB')
                values[phase][background]={name:sum(any(pixel) for pixel in delta.crop(box).getdata()) for name,box in [('catalog',(0,0,1152,320)),('saved_draft',(0,320,1152,648))]}
    return values


def fixture_bytes(root: Path, base: str, name: str, digest: str) -> bytes:
    """Читает точные байты из checkout, Git или сохранённого неотслеживаемого import-компаньона."""
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()) or not re.fullmatch(r"[a-f0-9]{64}", digest):
        raise ValueError("unsafe fixture source")
    raw = path.read_bytes() if path.is_file() else b""
    if sha(raw) == digest:
        return raw
    try:
        raw = git_bytes(root, base, name)
    except subprocess.CalledProcessError as exc:
        # Только исходный import, совпадающий с уже закреплённым SHA; PNG и код не подменяются.
        if path.suffix != ".import":
            raise ValueError("fixture source unavailable: " + name) from exc
        archive = root / REPORT / "historical-inputs" / (digest + ".import")
        if not archive.resolve().is_relative_to((root / REPORT).resolve()):
            raise ValueError("unsafe archived fixture source")
        raw = archive.read_bytes()
    if sha(raw) != digest:
        raise ValueError("fixture source differs: " + name)
    return raw


def validate(root:Path):
    """Не принимает потерянный ракурс, новый UID старому файлу, изменённый документ или фиктивный GPU-контроль."""
    report=root/REPORT;errors=[]
    try:
        proof=read(report/'proof.json');inventory=read(report/'inventory.json')
        required={phase+'/'+name for phase in PHASES for name in ['capture.json','dark.png','light.png']}
        required={'native/'+name for name in required}|{'native/'+phase+suffix for phase in PHASES for suffix in ['.log','-import.log']}
        required|={'fixture-sources.json','production-unchanged.json','wiki-contract.json','plan.json','inventory.json','catalog-before.json'}
        if set(proof['files'])!=required or proof.get('schema_version')!=1 or proof.get('performance_eligible') is not False:errors.append('migration proof coverage/scope differs')
        for name,digest in proof['files'].items():
            path=(report/name).resolve()
            if not path.is_relative_to(report.resolve()) or sha(path.read_bytes())!=digest:errors.append('migration proof file changed: '+name)
        if proof['base_commit']!=inventory['base_commit']:errors.append('migration proof baseline differs')
        captures={phase:read(report/'native'/phase/'capture.json') for phase in PHASES}
        baseline=captures['baseline'];dual=captures['dual']
        catalog=read(report/'catalog-before.json')
        old_paths=[catalog['textures']['oak_table_'+side]['file'] for side in SIDES]
        old_uids=[row['uid'] for row in baseline['rows']]
        if len(set(old_uids))!=3 or any(not re.fullmatch(r'uid://[a-z0-9]+',uid) for uid in old_uids):errors.append('baseline UID set invalid')
        stable=['side','id','pixels','source','pivot','logical_size','footprint','rgba_sha256','png_sha256']
        for phase,data in captures.items():
            expected_missing=3 if phase=='retired' else 0;expected_unadapted=3 if phase=='unadapted' else 0
            if data.get('phase')!=phase or data.get('errors') or data.get('missing_old_paths')!=expected_missing or data.get('unadapted_old_paths')!=expected_unadapted or data.get('prototype_adapter')!=(phase in ['dual','retired']):errors.append('migration phase/control differs: '+phase)
            if data.get('framebuffer')!=[1152,648] or data.get('target')!='fixed_gpu_subviewport' or data.get('display_server') in [None,'headless'] or data.get('method')!='gl_compatibility' or data.get('driver')!='opengl3' or data.get('performance_eligible') is not False or not data.get('profile','').startswith('Codex-VPIPELINE-009-'):errors.append('migration GPU configuration differs: '+phase)
            if data.get('source_sha256')!=sha((current_source(root, 'tools/migration_capture.gd')).read_bytes()) or data.get('draft_sha256')!=baseline['draft_sha256']:errors.append('migration instrument/draft source differs: '+phase)
            if len(data['rows'])!=3 or [row['side'] for row in data['rows']]!=SIDES:errors.append('migration view coverage differs: '+phase);continue
            if {k:v for k,v in data['document'].items() if k!='validation'}!={k:v for k,v in baseline['document'].items() if k!='validation'}:errors.append('saved F12 document changed: '+phase)
            if data['document'].get('version')!=6 or bool(data['document']['validation']['valid'])!=(expected_missing==0):errors.append('saved draft validation differs: '+phase)
            for index,row in enumerate(data['rows']):
                original=baseline['rows'][index];side=SIDES[index];texture=catalog['textures']['oak_table_'+side];view=catalog['resources']['prop.rustic_table']['views'][side]
                expected_path=old_paths[index] if phase in ['baseline','rollback'] else 'res://assets/game/interiors/migration_pilot/rustic_table_'+side+'.png'
                if any(row[key]!=original[key] for key in stable) or row['id']!='prop.rustic_table' or row['pixels']!=texture['pixels'] or row['source']!=view['variants']['standard']['source_rect'] or row['pivot']!=view['pivot'] or row['logical_size']!=view['logical_size'] or row['footprint']!=view['footprint_size']:errors.append('migration ID/pixels/geometry changed: '+phase+'/'+side)
                if row['png_sha256']!=inventory['files'][old_paths[index].removeprefix('res://')]['sha256']:errors.append('migration original PNG differs')
                if row['path']!=expected_path or row['old_path']!=old_paths[index] or row['old_exists']!=(expected_missing==0):errors.append('migration paths differ: '+phase+'/'+side)
                if row['new_profile_id']!='prop.rustic_table' or row['old_profile_id']!=('' if expected_unadapted else 'prop.rustic_table'):errors.append('migration metadata adapter differs')
                if row['old_uid']!=('' if expected_missing else old_uids[index]):errors.append('original UID changed: '+phase+'/'+side)
                if phase in ['baseline','rollback'] and row['uid']!=old_uids[index]:errors.append('rollback UID differs')
                if phase in ['dual','unadapted','retired'] and (row['uid'] in old_uids or row['uid']!=dual['rows'][index]['uid']):errors.append('new UID duplicates old source or changes between controls')
            if len({row['uid'] for row in data['rows']})!=3:errors.append('duplicate migration UID')
            if set(data['frames'])!={'dark','light'}:errors.append('migration background coverage differs')
            for background,digest in data['frames'].items():
                path=report/'native'/phase/(background+'.png')
                with Image.open(path) as image:
                    if image.size!=(1152,648) or image.mode!='RGBA' or image.getchannel('A').getextrema()!=(255,255) or sha(path.read_bytes())!=digest:errors.append('migration native image differs')
            for suffix in ['.log','-import.log']:
                log=(report/'native'/(phase+suffix)).read_text()
                if any(marker in log for marker in ['ERROR:','SCRIPT ERROR','Parse Error']):errors.append('migration engine error: '+phase+suffix)
        values=comparisons(report)
        if values!=proof['comparisons']:errors.append('migration measurements differ')
        for phase,rows in values.items():
            for row in rows.values():
                if row['catalog']!=0 or (row['saved_draft']<100 if phase in ['unadapted','retired'] else row['saved_draft']!=0):errors.append('migration equality/negative control failed: '+phase)
        sources=read(report/'fixture-sources.json')
        if sha((report/'catalog-before.json').read_bytes())!=sources['files'].get('assets/game/visual_resources.json'):errors.append('fixture catalog source differs')
        if sources['base_commit']!=inventory['base_commit'] or len(sources['files'])<100:errors.append('fixture dependency inventory missing')
        for name,digest in sources['files'].items():
            path=(root/name).resolve()
            if not path.is_relative_to(root.resolve()):errors.append('unsafe fixture source');continue
            fixture_bytes(root, inventory['base_commit'], name, digest)
        unchanged=read(report/'production-unchanged.json')
        if unchanged.get('runtime_changed') or unchanged.get('runtime_file_changes')!=[] or unchanged.get('reader_source_changes')!=[] or unchanged.get('runtime_files')!=len(inventory['files']) or unchanged.get('reader_sources')!=len(inventory['sources']):errors.append('production unchanged evidence differs')
        wiki=read(report/'wiki-contract.json')
        if wiki.get('before')!=wiki.get('after') or wiki['before']['count']!=len(wiki['before']['keys']) or len(set(wiki['before']['keys']))!=wiki['before']['count'] or wiki['before']['count']<900:errors.append('Wiki game article contract changed')
    except (OSError,ValueError,KeyError,TypeError,IndexError) as exc:errors.append('invalid migration proof: '+str(exc))
    return errors
