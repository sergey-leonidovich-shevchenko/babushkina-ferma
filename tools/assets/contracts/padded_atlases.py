#!/usr/bin/env python3
"""Детерминированно пакует отдельные уровни миниатюр с экструзией полного RGBA-края."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
from tools.common.paths import project_root
from PIL import Image
from PIL import ImageChops
from tools.assets.contracts.visual_resources import parse

ROOT=project_root(__file__)
FOLDER=Path('assets/game/items/ui/padded')
SOURCE=Path('assets/game/items/ui/thumbnails.png')
CATALOG=Path('assets/game/items/ui/catalog.json')
SIZE=64
PADDING=2
COLUMNS=16
LEVELS=4
REPORT=ROOT/'docs/reports/visual-overhaul/vpipeline-004'


def digest(file: Path) -> str:
    """Связывает каждый пакет с точными байтами подготовленного изображения."""
    return hashlib.sha256(file.read_bytes()).hexdigest()


def extrude(frame: Image.Image, padding: int) -> Image.Image:
    """Продолжает край и углы полного RGBA без изменения внутреннего рисунка."""
    w,h=frame.size; output=Image.new('RGBA',(w+2*padding,h+2*padding))
    output.paste(frame,(padding,padding))
    for y in range(-padding,h+padding):
        for x in range(-padding,w+padding):
            if x<0 or x>=w or y<0 or y>=h:
                output.putpixel((x+padding,y+padding),frame.getpixel((max(0,min(w-1,x)),max(0,min(h-1,y)))))
    return output


def pack(frames: dict[str,Image.Image], size: int, columns: int, padding: int) -> tuple[Image.Image,dict]:
    """Уменьшает каждый исходник отдельно, затем пакует непересекающиеся ячейки с собственными полями."""
    if not frames or size<1 or columns<1 or padding<2: raise ValueError('invalid packing parameters')
    stride=size+2*padding; rows=math.ceil(len(frames)/columns)
    page=Image.new('RGBA',(columns*stride,rows*stride)); entries={}
    for index,(kind,source) in enumerate(sorted(frames.items())):
        frame=source.convert('RGBA')
        if frame.size!=(size,size): frame=frame.resize((size,size),Image.Resampling.LANCZOS)
        x=(index%columns)*stride; y=(index//columns)*stride
        page.paste(extrude(frame,padding),(x,y)); entries[kind]=[x+padding,y+padding,size,size]
    return page,entries


def source_frames(root: Path) -> dict[str,Image.Image]:
    """Читает проверенные экранные 64px, сохраняя исходные PNG предметов и окраску отдельно."""
    data=parse((root/CATALOG).read_text())
    with Image.open(root/SOURCE) as image:
        image=image.convert('RGBA')
        frames={}; occupied=set()
        for kind,row in data['entries'].items():
            cell=row['cell']
            if not isinstance(cell,list) or len(cell)!=2 or any(type(x)!=int for x in cell): raise ValueError('invalid source cell')
            x,y=cell
            if min(x,y)<0 or x+SIZE>image.width or y+SIZE>image.height or (x,y) in occupied: raise ValueError('overlapping or outside source cell')
            frame=image.crop((x,y,x+SIZE,y+SIZE))
            if frame.getchannel('A').getbbox() is None: raise ValueError('empty source frame: '+kind)
            occupied.add((x,y)); frames[kind]=frame
        return frames


def write(root: Path) -> None:
    """Пересоздаёт только собственные четыре страницы и паспорт; профили импорта остаются явными файлами проекта."""
    frames=source_frames(root); folder=root/FOLDER; folder.mkdir(parents=True,exist_ok=True)
    data={'schema_version':1,'id':'ui.items','family':'painted_atlas','source':{'file':SOURCE.as_posix(),'sha256':digest(root/SOURCE),'catalog':CATALOG.as_posix(),'catalog_sha256':digest(root/CATALOG)},
          'base_size':SIZE,'padding':PADDING,'columns':COLUMNS,'mip_strategy':'independent_pages','levels':[]}
    for level in range(LEVELS):
        size=SIZE>>level; image,entries=pack(frames,size,COLUMNS,PADDING)
        file=folder/f'level-{level}.png'; image.save(file)
        data['levels'].append({'level':level,'frame_size':size,'file':'res://'+file.relative_to(root).as_posix(),'pixels':list(image.size),'sha256':digest(file),'entries':entries})
    (folder/'catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')


def validate(root: Path) -> list[str]:
    """Проверяет все внутренние пиксели, поля и уменьшенные уровни по независимым исходным кадрам."""
    errors=[]
    try:
        data=parse((root/FOLDER/'catalog.json').read_text()); source=data['source']
        if data.get('schema_version')!=1 or data.get('id')!='ui.items' or data.get('family')!='painted_atlas' or data.get('mip_strategy')!='independent_pages': errors.append('invalid atlas contract')
        if data.get('base_size')!=SIZE or data.get('padding')!=PADDING or data.get('columns')!=COLUMNS: errors.append('invalid sampling geometry')
        if source['file']!=SOURCE.as_posix() or source['sha256']!=digest(root/SOURCE) or source['catalog']!=CATALOG.as_posix() or source['catalog_sha256']!=digest(root/CATALOG): errors.append('stale source fingerprints')
        frames=source_frames(root)
        if len(data['levels'])!=LEVELS or [r['level'] for r in data['levels']]!=list(range(LEVELS)): errors.append('incomplete independent mip levels')
        for row in data['levels']:
            level=row['level']; size=SIZE>>level
            stride=size+2*PADDING; expected_size=(COLUMNS*stride,math.ceil(len(frames)/COLUMNS)*stride)
            entries={kind:[(i%COLUMNS)*stride+PADDING,(i//COLUMNS)*stride+PADDING,size,size] for i,kind in enumerate(sorted(frames))}
            name=row['file']; file=(root/name[6:]).resolve()
            if not name.startswith('res://'+FOLDER.as_posix()+'/') or not file.is_relative_to((root/FOLDER).resolve()): errors.append('unsafe page path'); continue
            if digest(file)!=row['sha256']: errors.append('page SHA256 mismatch')
            with Image.open(file) as image:
                if image.mode!='RGBA' or image.format!='PNG' or image.size!=expected_size or list(image.size)!=row['pixels']: errors.append('invalid page image')
                image=image.convert('RGBA')
                for kind,(x,y,w,h) in entries.items():
                    frame=frames[kind] if size==SIZE else frames[kind].resize((size,size),Image.Resampling.LANCZOS)
                    if image.crop((x,y,x+w,y+h)).tobytes()!=frame.tobytes(): errors.append('frame/gutter/mip pixel mismatch: '+kind)
                    # Полосы и углы сверяются независимо от функции экспортёра extrude.
                    for yy in range(-PADDING,h+PADDING):
                        for xx in (range(-PADDING,w+PADDING) if yy<0 or yy>=h else list(range(-PADDING,0))+list(range(w,w+PADDING))):
                            if image.getpixel((x+xx,y+yy))!=frame.getpixel((max(0,min(w-1,xx)),max(0,min(h-1,yy)))):
                                errors.append('frame/gutter/mip pixel mismatch: '+kind); break
                        else: continue
                        break
            if row['frame_size']!=size or row['entries']!=entries: errors.append('frame rectangles differ from packing')
            settings=Path(str(file)+'.import').read_text()
            for option in ['compress/mode=0','mipmaps/generate=false','process/fix_alpha_border=false','process/premult_alpha=false']:
                if '\n'+option+'\n' not in settings: errors.append('unsafe import: '+option)
            if 'source_file="'+name+'"' not in settings: errors.append('wrong import source')
    except (OSError,ValueError,KeyError,TypeError) as exc: errors.append('invalid padded atlas: '+str(exc))
    return errors


def main() -> None:
    """По умолчанию проверяет пакет; запись требует явного --write и не меняет художественные источники."""
    parser=argparse.ArgumentParser(); parser.add_argument('--write',action='store_true'); parser.add_argument('--fixtures',type=Path); args=parser.parse_args()
    if args.fixtures:
        fixtures(args.fixtures); return
    if args.write: write(ROOT); print('PADDED ATLAS: pages written; import before validation'); return
    errors=validate(ROOT)
    if errors: raise SystemExit('\n'.join(errors))
    verify_capture(REPORT)
    print('PADDED ATLAS: all frames, RGBA gutters, independent levels and imports valid')


def fixtures(folder: Path) -> None:
    """Готовит отдельные контрастные тестовые кадры, не подменяя ими игровые рисунки."""
    if folder.exists(): raise ValueError('fixture output must be new')
    folder.mkdir(parents=True)
    frames={key:Image.new('RGBA',(64,64),color) for key,color in [('a',(235,25,35,255)),('b',(25,215,55,255)),('c',(35,55,235,255))]}
    tight=Image.new('RGBA',(192,64))
    for index,frame in enumerate(frames.values()): tight.paste(frame,(index*64,0))
    tight.save(folder/'tight.png'); data=[]
    for level in range(4):
        image,entries=pack(frames,64>>level,3,2); image.save(folder/f'level-{level}.png')
        data.append(entries['b'])
    (folder/'fixture.json').write_text(json.dumps(data)+'\n')


def same(a: Image.Image,b: Image.Image) -> bool:
    """Сравнивает все каналы нативного readback, включая альфу."""
    return a.size==b.size and all(channel.getbbox() is None for channel in ImageChops.difference(a,b).split())


def verify_capture(folder: Path) -> None:
    """Проверяет настоящий негативный контроль, изолированный эталон и сохранность остальной комнаты."""
    proof=parse((folder/'native-comparison.json').read_text()); data=parse((folder/'native/capture.json').read_text())
    if proof.get('base_commit')!='4c930d1266bed5083f2b24b376f5df82f002d65d' or data.get('errors') or data.get('performance_eligible') is not False: raise ValueError('invalid capture provenance')
    if data.get('framebuffer')!=[1152,648] or data.get('sizes')!=[64,40,32,16,8,4] or len(data.get('source_sha256',{}))!=6: raise ValueError('incomplete capture configuration')
    expected={'room','cabinet'}|{bg+'-'+mode for bg in ['light','dark'] for mode in ['unsafe','padded','isolated']}
    if set(proof.get('frames',{}))!=expected: raise ValueError('incomplete native matrix')
    images={}
    for name,sha in proof['frames'].items():
        file=folder/'native'/str(name+'.png')
        if digest(file)!=sha: raise ValueError('native SHA256 mismatch')
        with Image.open(file) as image:
            if image.format!='PNG' or image.size!=(1152,648): raise ValueError('wrong native framebuffer')
            images[name]=image.convert('RGBA')
    log=(folder/'native/engine.txt').read_text()
    if 'ERROR:' in log or 'FAIL:' in log or 'Compatibility' not in log: raise ValueError('native engine errors')
    for bg in ['light','dark']:
        clean=images[bg+'-padded']; reference=images[bg+'-isolated']; unsafe=images[bg+'-unsafe']
        if not same(clean,reference): raise ValueError('padded atlas differs from isolated frames')
        for index,size in enumerate(data['sizes']):
            x=70+170*index; box=(x,156,x+size,156+size)
            if set(clean.crop(box).getdata())!={(25,215,55,255)}: raise ValueError('neighbor color entered padded frame')
            if index>0:
                diff=ImageChops.difference(unsafe.crop(box),clean.crop(box))
                if max(channel.getextrema()[1] for channel in diff.split())<20: raise ValueError('negative mip control did not expose neighbor bleed')
                if unsafe.getpixel((x+size//2,156+size//2))!=(25,215,55,255): raise ValueError('negative control changed the entire material')
    before=folder/'before/room.png'
    if digest(before)!=proof.get('before_room_sha256'): raise ValueError('wrong room baseline')
    original=Image.open(before).convert('RGBA'); current=images['room'].copy()
    for box in [(310,580,842,640),(688,392,752,432)]:
        original.paste((0,0,0,0),box); current.paste((0,0,0,0),box)
    if not same(original,current): raise ValueError('unrelated room pixels changed')
    point=data.get('room_configuration',{})
    if point.get('camera')!=[0,6] or point.get('player')!=[576,500] or point.get('seed')!=20261015 or point.get('minutes')!=720: raise ValueError('room configuration changed')


if __name__=='__main__': main()
