#!/usr/bin/env python3
"""Проверяет два размера UI и воспроизводимую нативную загрузку шкафа."""
from __future__ import annotations
import hashlib
import json
import re
import subprocess
from pathlib import Path
from PIL import Image, ImageChops
from visual_resources import parse

ROOT=Path(__file__).resolve().parents[1]
CATALOG='assets/game/items/ui/catalog.json'
FOLDER='assets/game/items/ui'
REPORT='docs/reports/visual-overhaul/vpipeline-006'
FRAMES=['room','cabinet-first','cabinet-stable','cabinet-reopen']
PREVIEW_RECT=(454,262,558,366)


def read(path: Path) -> dict:
    """Отклоняет повторные JSON-ключи вместо скрытого выбора последнего значения."""
    return parse(path.read_text())


def digest(path: Path) -> str:
    """Фиксирует конкретные байты нативного доказательства или исходного файла."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(root: Path) -> list[str]:
    """Сверяет живой каталог, реальные PNG, поля прозрачности, области и импорты двух размеров."""
    errors=[]
    try:
        data=read(root/CATALOG)
        if (data.get('schema'),data.get('small'),data.get('large'),data.get('columns'))!=(1,64,160,16): errors.append('expected canonical schema1 and 64/160 sizes, 16 columns')
        literal=(root/FOLDER/'catalog.gd').read_text().split('const DATA := ',1)[1]
        if parse(literal)!=data: errors.append('JSON and Godot catalogues differ')
        with Image.open(root/FOLDER/'thumbnails.png') as image:
            if image.mode!='RGBA' or image.size!=(1024,64*((len(data['entries'])+15)//16)): errors.append('invalid 64px atlas dimensions/format')
            alpha=image.getchannel('A')
            for index,(kind,entry) in enumerate(sorted(data['entries'].items())):
                if not re.fullmatch('[a-z][a-z0-9_]*',kind): errors.append('invalid item ID: '+kind); continue
                x,y=entry.get('cell',[None,None]); expected=[index%16*64,index//16*64]
                if [x,y]!=expected: errors.append('invalid or overlapping source rect: '+kind); continue
                bounds=alpha.crop((x,y,x+64,y+64)).getbbox()
                if not bounds or bounds[0]<3 or bounds[1]<3 or bounds[2]>61 or bounds[3]>61: errors.append('clipped or empty thumbnail alpha: '+kind)
                if not re.fullmatch('[a-f0-9]{64}',entry.get('sourceHash','')): errors.append('missing canonical fingerprint: '+kind)
                if entry.get('provider') not in ['catalog','override','alchemy','workshop','research','furnace'] or not re.fullmatch('[a-f0-9]{6}',entry.get('tint','')): errors.append('invalid provider/tint: '+kind)
                preview=root/FOLDER/'preview'/(kind+'.png')
                with Image.open(preview) as large:
                    large.verify()
                with Image.open(preview) as large:
                    if large.mode!='RGBA' or large.size!=(160,160): errors.append('preview must be independent 160px RGBA: '+kind); continue
                    large_bounds=large.getchannel('A').getbbox()
                    if not large_bounds or large_bounds[0]<8 or large_bounds[1]<8 or large_bounds[2]>152 or large_bounds[3]>152: errors.append('clipped or empty preview alpha: '+kind)
                errors+=import_errors(preview)
        errors+=import_errors(root/FOLDER/'thumbnails.png')
    except (OSError,ValueError,KeyError,TypeError,IndexError) as exc: errors.append('invalid UI sizes: '+str(exc))
    return errors


def import_errors(path: Path) -> list[str]:
    """Запрещает потерю качества, аппаратный mip и premultiply у подготовленных цветовых PNG."""
    source=Path(str(path)+'.import').read_text(); errors=[]
    for key,value in {'compress/mode':'0','mipmaps/generate':'false','process/fix_alpha_border':'true','process/premult_alpha':'false'}.items():
        if re.findall('^'+re.escape(key)+'=(.+)$',source,re.M)!=[value]:errors.append('wrong import '+path.name+': '+key)
    return errors


def expected_state(before: dict) -> dict:
    """Учитывает только два прежних флага первого посещения шкафа, сохраняя весь остальной снимок."""
    result=json.loads(json.dumps(before))
    result['tutorial']['events']['dev_cabinet']=True
    result['estate']['expansion']['first_chapter']['events']['dev_cabinet']=True
    return result


def native_errors(folder: Path, updated: bool) -> list[str]:
    """Проверяет холодный запрос и повтор, фактические ссылки загрузчика и полный снимок состояния."""
    data=read(folder/'capture.json'); errors=[]
    if data['errors'] or data['framebuffer']!=[1152,648] or data['performance_eligible'] is not False: errors.append('invalid capture configuration/errors')
    if len(data['inventory_ids'])!=len(set(data['inventory_ids'])): errors.append('duplicate native item IDs')
    if data['serialized_after']!=expected_state(data['serialized_before']) or not data['only_cabinet_visit_recorded']: errors.append('unexpected serialized state change')
    stages=['room','open_before_draw','first_frame','stable','reopened']
    base=data['room']; first=data['first_frame']
    if base['preview_ids_cached'] or data['open_before_draw']['preview_ids_cached']:errors.append('previews were prewarmed before first draw')
    if len(first['preview_ids_cached'])!=1:errors.append('first draw must load only selected preview')
    for name in stages:
        stage=data[name]
        if stage['master_ids_cached']!=base['master_ids_cached'] or stage['sources']['loaded_paths']!=0 or stage['sources']['loaded_total']!=base['sources']['loaded_total']:errors.append('original source loads during cabinet: '+name)
        if stage['prepared']['large']>(0 if name in stages[:2] else 1):errors.append('unexpected retained previews: '+name)
        if name in ['stable','reopened'] and stage['preview_ids_cached']!=first['preview_ids_cached']:errors.append('preview churn: '+name)
    if updated:
        for name in stages:
            if data[name]['prepared']['preview_load_requests']!=(0 if name in stages[:2] else 1):errors.append('additional preview load request: '+name)
        if data['reopened']['prepared']['preview_hits']<=data['first_frame']['prepared']['preview_hits']:errors.append('reopen did not reuse cached preview')
    for name in FRAMES:
        path=folder/(name+'.png')
        if digest(path)!=data['frames'][name]:errors.append('native hash mismatch: '+name)
        with Image.open(path) as image:
            if image.size!=(1152,648) or image.mode!='RGBA':errors.append('invalid whole framebuffer: '+name)
    with Image.open(folder/'cabinet-first.png') as a,Image.open(folder/'cabinet-stable.png') as b,Image.open(folder/'cabinet-reopen.png') as c:
        if ImageChops.difference(a,b).getbbox(alpha_only=False) or ImageChops.difference(b,c).getbbox(alpha_only=False):errors.append('first frame or reopen differs from stable cabinet')
    return errors


def proof_errors(root: Path) -> list[str]:
    """Сверяет историческую пару и область выбранного превью без запрета будущих согласованных рисунков."""
    errors=[]; report=root/REPORT
    try:
        proof=read(report/'proof.json')
        for relative,expected in proof['files'].items():
            if digest(report/relative)!=expected:errors.append('proof file changed: '+relative)
        before=read(report/'before/capture.json');after=read(report/'after/capture.json')
        errors+=native_errors(report/'before',False)+native_errors(report/'after',True)
        for key in ['configuration','framebuffer','inventory_ids','serialized_before','serialized_after']:
            if before[key]!=after[key]:errors.append('baseline and new configuration/state differ: '+key)
        if before['source_sha256']['tools/item_sizes_capture.gd']!=after['source_sha256']['tools/item_sizes_capture.gd']: errors.append('capture scripts differ')
        for phase in ['before','after']:
            if 'ERROR:' in (report/(phase+'.log')).read_text(): errors.append('engine error: '+phase)
        changed={}
        for name in FRAMES:
            with Image.open(report/'before'/(name+'.png')) as a,Image.open(report/'after'/(name+'.png')) as b:
                diff=ImageChops.difference(a,b); changed[name]=sum(p!=(0,0,0,0) for p in diff.getdata())
                if name=='room':
                    if diff.getbbox(alpha_only=False):errors.append('room pixels changed')
                else:
                    diff.paste((0,0,0,0),PREVIEW_RECT)
                    if diff.getbbox(alpha_only=False):errors.append('pixels changed outside selected preview: '+name)
        if not changed['cabinet-stable'] or changed!=proof['changed_pixels']:errors.append('preview comparison/control mismatch')
    except (OSError,ValueError,KeyError,TypeError,IndexError) as exc:errors.append('invalid native size proof: '+str(exc))
    return errors


def main() -> None:
    """Запускает текущие проверки ассетов и полноту исторического пакета в Git index."""
    errors=validate(ROOT)+proof_errors(ROOT)
    tracked=set(subprocess.check_output(['git','-C',str(ROOT),'ls-files','-z']).decode().split('\0'))
    for name in read(ROOT/REPORT/'proof.json')['files']:
        if REPORT+'/'+name not in tracked:errors.append('proof input missing from Git index: '+name)
    if errors:raise SystemExit('\n'.join(errors))
    print('ITEM SIZES: canonical 64/160 PNGs, imports, cold cabinet and LRU proof valid')


if __name__=='__main__':main()
