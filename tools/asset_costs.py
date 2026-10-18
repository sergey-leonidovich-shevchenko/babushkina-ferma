#!/usr/bin/env python3
"""Измеряет файлы и связывает происхождение с доказательствами, не выдавая догадки за лицензию."""
from __future__ import annotations
import fnmatch
import hashlib
import io
import json
from pathlib import Path
import re
import wave
from PIL import Image
from visual_pipeline import ignored

RASTER={'.png','.webp','.jpg','.jpeg'}


def sha(raw):
    """Фиксирует точные байты файла или доказательства."""
    return hashlib.sha256(raw).hexdigest()


def names(files, policy):
    """Учитывает все production-файлы, включая звук, шрифт и метаданные, за пределами барьеров."""
    barriers=[str(Path(n).parent) for n in files if Path(n).name=='.gdignore']
    return sorted(n for n in files if (n.startswith('assets/game/') or n in ['assets/app_icon.png','assets/app_icon.png.import','assets/title_art_rpg.png','assets/title_art_rpg.png.import']) and not ignored(n,policy) and not any(n.startswith(b+'/') for b in barriers) and Path(n).name!='.gdignore')


def parameter(text,key,default=None):
    """Читает одно явное значение импорта, отклоняя неоднозначный дубликат."""
    values=re.findall('^'+re.escape(key)+'=(.+)$',text,re.M)
    if len(values)>1:raise ValueError('duplicate import parameter: '+key)
    return json.loads(values[0]) if values else default


def rgba_bytes(width,height,mips=False,limit=-1):
    """Считает RGBA8 по целым mip-уровням, включая последнюю полосу прямоугольной текстуры."""
    if width<1 or height<1:raise ValueError('invalid image dimensions')
    result=width*height*4;levels=1
    while mips and (width>1 or height>1) and (limit<0 or levels<=limit):
        width=max(1,width//2);height=max(1,height//2);result+=width*height*4;levels+=1
    return result


def measure(name,raw,import_raw=b''):
    """Отделяет сжатый файл, условную RGBA8-оценку и данные без фиксированной текстурной памяти."""
    suffix=Path(name).suffix.lower()
    row={'sha256':sha(raw),'disk_bytes':len(raw),'pixels':None,'texture_rgba8_bytes':0,'memory_note':'not a raster allocation; serialized bytes are not resident memory'}
    if suffix in RASTER:
        with Image.open(io.BytesIO(raw)) as image:image.verify()
        with Image.open(io.BytesIO(raw)) as image:
            width,height=image.size
            alpha=image.convert('RGBA').getchannel('A')
            row.update(pixels=[width,height],mode=image.mode,alpha_bounds=list(alpha.getbbox()) if alpha.getbbox() else None,alpha_extrema=list(alpha.getextrema()))
        text=import_raw.decode()
        mips=parameter(text,'mipmaps/generate',False);limit=parameter(text,'mipmaps/limit',-1)
        row['import']={key:parameter(text,key) for key in ['compress/mode','mipmaps/generate','mipmaps/limit','process/size_limit','process/fix_alpha_border','process/premult_alpha']}
        row['import_sha256']=sha(import_raw)
        size_limit=parameter(text,'process/size_limit',0)
        # Не угадываем алгоритм масштабирования/аппаратный формат при нетипичном импорте.
        row['texture_rgba8_bytes']=rgba_bytes(width,height,mips,limit) if not size_limit else None
        row['memory_note']='nominal decoded RGBA8 including declared mips; not measured VRAM, residency, driver overhead or CPU copies'
    elif suffix=='.wav':
        with wave.open(io.BytesIO(raw)) as sound:
            row['audio']={'frames':sound.getnframes(),'channels':sound.getnchannels(),'sample_width':sound.getsampwidth(),'rate':sound.getframerate()}
            row['pcm_bytes']=sound.getnframes()*sound.getnchannels()*sound.getsampwidth()
        row['memory_note']='PCM payload only; stream buffers and playback residency not measured'
    elif suffix=='.ttf':row['memory_note']='font outline file; glyph atlas memory depends on live sizes/languages and cannot be inferred from disk size'
    elif suffix=='.tres':
        text=raw.decode();row['resource_type']=re.search(r'\[gd_resource type="([^"]+)"',text)[1]
        row['references']=sorted(set(re.findall(r'path="(res://[^"]+)"',text)))
        row['memory_note']='resource descriptor; shared backing textures counted at raster paths, not again per AtlasTexture'
    return row


def evidence(path,reader):
    """Связывает утверждение с проверяемыми байтами документа без подмены его содержания."""
    return {'path':path,'sha256':sha(reader(path))}


def origin(name,raw,rules,reader):
    """Применяет адресные задокументированные утверждения; отсутствие сведений остаётся явным долгом."""
    matches=[r for r in rules['rules'] if any(fnmatch.fnmatchcase(name,p) for p in r['paths'])]
    if len(matches)>1:raise ValueError('overlapping provenance rules: '+name)
    if matches:
        rule=matches[0]
        if rule.get('asset_sha256',{}).get(name)!=sha(raw):raise ValueError('provenance claim needs reviewed bytes: '+name)
        return {'kind':rule['kind'],'claim':rule['claim'],'license_status':rule['license_status'],'rule':rule['id'],'evidence':[evidence(p,reader) for p in rule['evidence']],'upstream':rule.get('upstream',[]),'release_clearance':False}
    if name in rules.get('local_matches',{}):
        receipt=rules['local_matches'][name]
        if receipt['sha256']!=sha(raw):raise ValueError('local source receipt differs: '+name)
        return {'kind':'external-local-byte-match','claim':'Exact bytes match local inbox candidates recorded during audit; download/authorship not independently certified','license_status':'reference-only-review','evidence':[],'local_receipt':receipt,'release_clearance':False}
    if Path(name).suffix in ['.import','.uid']:
        return {'kind':'engine-metadata','claim':'Godot metadata; rights follow the linked resource','license_status':'inherits-resource','sources':[name.rsplit('.',1)[0]],'evidence':[],'release_clearance':False}
    if Path(name).suffix in ['.json','.gd','.tres','.res','.md','.txt']:
        return {'kind':'repository-record','claim':'Tracked project metadata or notice; snapshot is evidence of presence, not independent authorship','license_status':'review-record','evidence':[],'release_clearance':False}
    return {'kind':'unresolved','claim':'Only repository snapshot available; original author, input and permission have not been established','license_status':'unresolved','evidence':[],'release_clearance':False}


def summarize(records):
    """Не суммирует виртуальные кадры повторно и не называет общий потенциал живой памятью."""
    raster={p:r for p,r in records.items() if r['pixels'] is not None}
    unique={}
    for r in raster.values():unique[r['sha256']]=r['texture_rgba8_bytes'] or 0
    counts={}
    for r in records.values():
        key=r['origin']['kind'];counts[key]=counts.get(key,0)+1
    return {'files':len(records),'rasters':len(raster),'disk_bytes':sum(r['disk_bytes'] for r in records.values()),'nominal_rgba8_path_sum':sum(r['texture_rgba8_bytes'] or 0 for r in raster.values()),'identical_file_hash_sum':sum(unique.values()),'unknown_size_estimates':sum(r['texture_rgba8_bytes'] is None for r in raster.values()),'provenance_counts':counts,'unresolved_media':[p for p,r in records.items() if r['origin']['kind']=='unresolved'],'largest_rasters':sorted(raster,key=lambda p:raster[p]['texture_rgba8_bytes'] or 0,reverse=True)[:20],'residency_measured':False,'release_clearance':False}
