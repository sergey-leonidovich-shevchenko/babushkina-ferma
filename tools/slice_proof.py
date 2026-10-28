#!/usr/bin/env python3
"""Проверяет исторические GPU-пары, исправленные границы и адресные отрицательные контроли."""
from pathlib import Path
from PIL import Image,ImageChops
from slice_audit import ROOT,REPORT,POLICY,read,digest
from slice_metrics import geometry
from tools.assets.contracts.source_paths import current_source
from tools.common.history import pinned_sha

LEGACY_CAPTURES = {
    'tools/slice_capture.gd': ('d609ab4fa6d82d6d013265183f018b8836abf7cc', 'a5784861a412f0842c9513ed751d3e99cf3fd0ea1f4d5a56ba3ab07f0b78611d'),
    'tools/slice_legacy_capture.gd': ('d609ab4fa6d82d6d013265183f018b8836abf7cc', '2e3df3edd52107d8a1d477109d4bec572f7d49e3a02db6c0933bd5e8c636d6ff'),
}


def capture_sha(root: Path, name: str) -> str:
    """История кода принадлежит checkout reader; изменённая текущая копия не проходит."""
    commit, expected = LEGACY_CAPTURES[name]
    if current_source(root, name).read_bytes() != current_source(ROOT, name).read_bytes():
        raise ValueError('native slice capture implementation differs')
    return pinned_sha(ROOT, name, commit, expected)

TARGETS=['ui/sunflower/160','ui/sword/160','characters/hero/bow/east/2','characters/hero/blade/east/2','characters/hero/spear/east/2','crops/sunflower/spring/4']


def comparisons(folder):
    """Считает изменения в области каждого примера, исключая изменяющийся заголовок стенда."""
    metadata=read(folder/'capture.json');result={}
    for background in ['dark','light']:
        images={name:Image.open(folder/(name+'-'+background+'.png')).convert('RGBA') for name in ['reference','game','clipped']}
        result[background]={}
        for row in metadata['targets']:
            x,y,w,h=map(int,row['roi']);box=(x,y,x+w,y+h)
            result[background][row['id']]={}
            for mode in ['game','clipped']:
                diff=ImageChops.difference(images['reference'].crop(box),images[mode].crop(box))
                result[background][row['id']][mode]=sum(any(pixel) for pixel in diff.getdata())
        for image in images.values():image.close()
    return result


def validate(root:Path):
    """Сверяет реальные пиксели, все двадцать правок и неизменность современной графики до/после."""
    report=root/REPORT;errors=[]
    try:
        proof=read(report/'proof.json');before=read(report/'inventory.json');after=read(report/'after/inventory.json')
        policy=read(current_source(root, POLICY));base=read(report/'legacy-slices.json')
        required={'inventory.json','measurements.json','legacy-slices.json','export.log','after/inventory.json','after/measurements.json','after/export.log','profile.log','before-native.log','after-native.log','legacy-native.log','before-native/capture.json','after-native/capture.json','legacy-native/capture.json'}
        required.update(phase+'/'+mode+'-'+background+'.png' for phase in ['before-native','after-native'] for mode in ['reference','game','clipped'] for background in ['dark','light'])
        required.update('legacy-native/'+page+'-'+background+'.png' for page in ['pirate','potion'] for background in ['dark','light'])
        if set(proof['files'])!=required or proof.get('schema_version')!=1 or proof.get('performance_eligible') is not False:errors.append('incomplete slice proof inventory')
        if proof['baseline_commit']!=base['baseline_commit'] or base['baseline_commit']!=policy['baseline_commit']:errors.append('slice baseline commit differs')
        for file,sha in proof['files'].items():
            path=(report/file).resolve()
            if not path.is_relative_to(report.resolve()) or digest(path.read_bytes())!=sha:errors.append('slice proof file changed: '+file)
        initial=[]
        for id,frame in before['frames'].items():
            initial.extend(id+': '+error for error in geometry(frame,before['textures'][frame['image']]['pixels']))
        if sorted(initial)!=sorted(policy['initial_geometry_issues']) or sorted(initial)!=sorted(base['geometry_issues']) or len(initial)!=20:errors.append('initial fractional controls differ')
        if set(before['frames'])!=set(after['frames']):errors.append('frame coverage changed during grid correction')
        changed=[]
        for id,frame in after['frames'].items():
            errors.extend(id+': '+e for e in geometry(frame,after['textures'][frame['image']]['pixels']))
            if frame['rect']!=before['frames'][id]['rect']:changed.append(id)
            old_texture=before['textures'][before['frames'][id]['image']];new_texture=after['textures'][frame['image']]
            if old_texture['rgba_sha256']!=new_texture['rgba_sha256']:errors.append('effective source pixels changed: '+id)
        if sorted(changed)!=proof['changed_regions'] or len(changed)!=20:errors.append('integer grid correction coverage differs')
        for phase in ['before-native','after-native']:
            folder=report/phase;data=read(folder/'capture.json')
            if data['source_sha256']!=capture_sha(root, 'tools/slice_capture.gd'):errors.append('native slice capture implementation differs')
            if data['framebuffer']!=[1152,648] or data['target']!='fixed_gpu_subviewport' or data['performance_eligible'] is not False or data['method']!='gl_compatibility' or data['driver']!='opengl3':errors.append('native slice configuration differs')
            if set(data['frames'])!={mode+'-'+bg for mode in ['reference','game','clipped'] for bg in ['dark','light']}:errors.append('incomplete native slice matrix')
            if [row['id'] for row in data['targets']]!=TARGETS:errors.append('native target set differs')
            source=before if phase=='before-native' else after
            for index,row in enumerate(data['targets']):
                frame=source['frames'][row['id']]
                if row['rgba_sha256']!=source['textures'][frame['image']]['rgba_sha256'] or row['source']!=frame['rect'] or row['pivot']!=frame['pivot']:errors.append('native target provenance differs: '+row['id'])
                if row['roi']!=[index%3*384,65+index//3*300,384,270]:errors.append('native comparison ROI differs')
                x,y,w,h=row['source'];cx,cy,cw,ch=row['cut']
                if min(cw,ch)<=0 or cx<x or cy<y or cx+cw>x+w or cy+ch>y+h or row['source']==row['cut']:errors.append('invalid negative crop control')
            for name,sha in data['frames'].items():
                path=folder/(name+'.png')
                with Image.open(path) as image:
                    if image.size!=(1152,648) or image.mode!='RGBA' or digest(path.read_bytes())!=sha:errors.append('native slice image differs: '+name)
            values=comparisons(folder)
            if values!=proof['comparisons'][phase]:errors.append('native slice measurements differ')
            for rows in values.values():
                for row in rows.values():
                    if row['game']!=0 or row['clipped']<100:errors.append('whole-frame equality or negative control failed')
            if 'ERROR:' in (report/(phase+'.log')).read_text():errors.append('native engine errors')
        first=read(report/'before-native/capture.json');last=read(report/'after-native/capture.json')
        if first['targets']!=last['targets']:errors.append('modern target geometry changed')
        for name in first['frames']:
            with Image.open(report/'before-native'/(name+'.png')) as a,Image.open(report/'after-native'/(name+'.png')) as b:
                if ImageChops.difference(a,b).getbbox(alpha_only=False):errors.append('modern pixels changed after source grid fix: '+name)
        legacy=read(report/'legacy-native/capture.json')
        if legacy['source_sha256']!=capture_sha(root, 'tools/slice_legacy_capture.gd') or legacy['framebuffer']!=[1152,648] or legacy['performance_eligible'] is not False:errors.append('legacy replay configuration differs')
        if sorted(p['id'] for p in legacy['pairs'])!=sorted(changed):errors.append('legacy replay missed a corrected region')
        if set(legacy['frames'])!={page+'-'+background for page in ['pirate','potion'] for background in ['dark','light']}:errors.append('incomplete legacy replay matrix')
        for name,sha in legacy['frames'].items():
            path=report/'legacy-native'/(name+'.png')
            with Image.open(path) as image:
                if image.size!=(1152,648) or image.mode!='RGBA' or digest(path.read_bytes())!=sha:errors.append('legacy replay image differs')
        for pair in legacy['pairs']:
            if pair['before']!=before['frames'][pair['id']]['rect'] or pair['after']!=after['frames'][pair['id']]['rect']:errors.append('legacy replay geometry differs')
            texture=after['textures'][after['frames'][pair['id']]['image']]
            if not any(row.get('path')==pair['path'] and row.get('sha256')==pair['sha256'] for row in texture['chain']):errors.append('legacy source PNG provenance differs')
        if 'ERROR:' in (report/'legacy-native.log').read_text():errors.append('legacy replay engine errors')
        if 'SLICE REVIEW: 440 passed, 0 failed' not in (report/'profile.log').read_text() or 'ERROR:' in (report/'profile.log').read_text():errors.append('slice geometry profile failed')
    except (OSError,ValueError,TypeError,KeyError,IndexError) as exc:errors.append('invalid slice proof: '+str(exc))
    return errors
