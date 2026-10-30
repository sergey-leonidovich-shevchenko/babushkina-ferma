#!/usr/bin/env python3
"""Выгружает реальные игровые кадры и проверяет их геометрию до публикации."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from PIL import Image
from tools.assets.slicing.slice_metrics import geometry, chain_errors, measure
from tools.common.paths import project_root

from tools.assets.contracts.visual_resources import parse
from tools.assets.contracts.source_paths import current_source
from tools.common.git import git_environment
from tools.common.history import pinned_sha

ROOT=project_root(__file__)
REPORT='docs/reports/visual-overhaul/vpipeline-008'
POLICY='tools/slice_policy.json'
PACKAGED_EXPORTERS = {
    'tools/slice_export.gd': 'tools/assets/slicing/slice_export.gd',
    'tools/slice_catalogs.gd': 'tools/assets/slicing/slice_catalogs.gd',
}
LEGACY_EXPORTERS = {
    'tools/slice_export.gd': ('d609ab4fa6d82d6d013265183f018b8836abf7cc', 'f4c1bbd6ed24392b35483297d3f93f4badc575bbf3a7f1542422880879023dd0'),
    'tools/slice_catalogs.gd': ('d609ab4fa6d82d6d013265183f018b8836abf7cc', '4953f2b4dd14887826fc06f7e6ae946676a7cde9887fae13678ce70dc04dcfc8'),
}


def legacy_exporter_sha(root, name):
    """Текущий input остаётся привязанным к коду, исторические байты читает только собственный Git."""
    if current_source(root, name).read_bytes() != current_source(ROOT, name).read_bytes():
        raise ValueError('slice exporter implementation differs')
    return pinned_sha(ROOT, name, *LEGACY_EXPORTERS[name])


def read(path):
    """Читает JSON с запретом скрытой потери повторных ключей."""
    return parse(Path(path).read_text())


def digest(value):
    """Привязывает вывод к точным пикселям и геометрии, а не имени файла или времени изменения."""
    return hashlib.sha256(value).hexdigest()


def signature(frame, texture):
    """Оставляет одинаковый ключ при другой нумерации временных ресурсов между операционными системами."""
    return digest(json.dumps({'frame':{k:v for k,v in frame.items() if k!='image'},'texture':{k:v for k,v in texture.items() if k not in ['file','png_sha256']}},sort_keys=True).encode())


def inputs(root, *, historical=False, source_paths=None):
    """Связывает выгрузку с кодом поставщиков и игровыми данными; старый каталог не подменяет свежий прогон."""
    if source_paths is not None and source_paths != PACKAGED_EXPORTERS:
        raise ValueError('unknown slice exporter paths')
    files={}
    for directory in ['scripts','wiki/scripts','assets/game']:
        for path in (root/directory).rglob('*'):
            if not path.is_file() or path.suffix not in ['.gd','.json','.tres','.png'] and path.name!='.gdignore':continue
            if path.name!='.gdignore' and any((p/'.gdignore').exists() for p in path.parents if p.is_relative_to(root)):continue
            files[path.relative_to(root).as_posix()]=digest(path.read_bytes())
    for name in ['slice_export.gd','slice_catalogs.gd']:
        logical='tools/'+name
        tool=current_source(root, source_paths[logical]) if source_paths is not None else current_source(root, logical)
        if tool.is_file():files[logical]=legacy_exporter_sha(root, logical) if historical else digest(tool.read_bytes())
    return digest(json.dumps(files,sort_keys=True).encode())


def input_errors(root, inventory):
    """Legacy использует ровно прежний exporter, свежий режим — полную известную physical map."""
    paths = inventory.get('tool_source_paths', {})
    if not isinstance(paths, dict) or paths not in ({}, PACKAGED_EXPORTERS):
        return ['unknown slice exporter paths']
    errors = []
    if inventory.get('inputs_sha256') != inputs(root, historical=not bool(paths), source_paths=paths or None):
        errors.append('stale slice export: code or runtime source changed')
    name = 'tools/slice_export.gd'
    tool = current_source(root, paths[name]) if paths else current_source(root, name)
    if tool.is_file():
        expected = digest(tool.read_bytes()) if paths else legacy_exporter_sha(root, name)
        if inventory.get('source_sha256') != expected:
            errors.append('slice exporter source SHA256 differs')
    return errors


def evaluate(folder):
    """Проверяет импортированные пиксели и все области, сохраняя результаты отдельно от исходников."""
    data=read(folder/'inventory.json');errors=[];images={};cache={};rows={}
    for key,texture in data['textures'].items():
        file=(folder/texture['file']).resolve()
        if not file.is_relative_to(folder.resolve()):raise ValueError('texture escaped diagnostic directory')
        if texture['file'] not in images:
            raw=file.read_bytes()
            with Image.open(file) as source:
                rgba=source.convert('RGBA')
            if list(rgba.size)!=texture['pixels'] or digest(rgba.tobytes())!=texture['rgba_sha256'] or digest(raw)!=texture['png_sha256']:errors.append('texture bytes/dimensions differ: '+key)
            images[texture['file']]=rgba.getchannel('A')
        errors.extend(key+': '+e for e in chain_errors(texture['chain']))
    for id,frame in data['frames'].items():
        texture=data['textures'].get(frame.get('image'))
        if texture is None:errors.append('missing texture: '+id);continue
        problems=geometry(frame,texture['pixels'])
        if problems:errors.extend(id+': '+p for p in problems);continue
        lookup=(texture['file'],tuple(frame['rect']))
        if lookup not in cache:cache[lookup]=measure(images[texture['file']],frame['rect'])
        metrics=cache[lookup];warnings=[]
        margins=metrics['alpha26']['margins']
        protected=id.startswith('ui/') and id.rsplit('/',1)[-1] in ['8','16','32','64']
        if protected:
            chain=texture['chain']
            if not chain or chain[0]['class']!='AtlasTexture' or chain[0].get('filter_clip') is not True or not any('/items/ui/padded/' in r.get('path','') for r in chain):errors.append('unprotected UI level: '+id)
        if margins is None:warnings.append('empty_dense_alpha')
        elif min(margins)<2 and not protected:warnings.append('less_than_two_pixels')
        if metrics['boundary_connections'] and not protected:warnings.append('alpha_continues_outside_frame')
        if id.startswith('ui/') and id.endswith('/160') and (not metrics['alpha1']['margins'] or min(metrics['alpha1']['margins'])<8):errors.append('preview clips its required 8px margin: '+id)
        rows[id]={'signature':signature(frame,texture),'source_rect':frame['rect'],'pivot':frame['pivot'],'metrics':metrics,'warnings':warnings}
    return {'frames':rows,'errors':errors,'summary':{'frames':len(data['frames']),'textures':len(data['textures']),'atlas_resources':len(data['atlas_resources']),'warning_frames':sum(bool(r['warnings']) for r in rows.values())}}


def check(root, folder, result):
    """Блокирует новые риски, потерю охвата и неподдержанные места нарезки; старый долг не исправляет автоматически."""
    policy=read(current_source(root, POLICY));base=read(root/REPORT/'legacy-slices.json');errors=list(result['errors'])
    known=base['warnings'];reviews=policy.get('reviews',{})
    if policy.get('schema_version')!=1 or not isinstance(reviews,dict) or base.get('baseline_commit')!=policy.get('baseline_commit'):return ['invalid slice policy/baseline']
    for id,row in result['frames'].items():
        if not row['warnings']:continue
        if known.get(id,{}).get('signature')==row['signature'] and known[id].get('warnings')==row['warnings']:continue
        review=reviews.get(id,{})
        if not isinstance(review,dict) or review.get('signature')!=row['signature'] or not isinstance(review.get('reason'),str) or not review['reason'].strip() or not review.get('evidence'):errors.append('new slice risk requires review: '+id)
    for id,review in reviews.items():
        if not isinstance(review,dict) or not isinstance(review.get('evidence'),list) or not review['evidence']:errors.append('invalid slice review: '+id);continue
        if id not in result['frames'] or result['frames'][id]['signature']!=review.get('signature'):errors.append('stale slice review: '+id)
        for proof in review.get('evidence',[]):
            if not isinstance(proof,dict) or not isinstance(proof.get('file'),str):errors.append('invalid slice review evidence: '+id);continue
            file=(root/proof.get('file','')).resolve()
            if not file.is_relative_to(root.resolve()) or not file.is_file() or digest(file.read_bytes())!=proof.get('sha256'):errors.append('invalid slice review evidence: '+id)
    sites={str(p.relative_to(root)):len(re.findall(r'\bdraw_texture_rect_region\s*\(',p.read_text())) for p in (root/'scripts').rglob('*.gd') if 'draw_texture_rect_region' in p.read_text()}
    if sites!={path:row['calls'] for path,row in policy['call_sites'].items()}:errors.append('slice call-site coverage changed: add a provider or explain bounded procedural input')
    inventory=read(folder/'inventory.json')
    errors.extend(input_errors(root, inventory))
    expected=inventory.get('expected_characters')
    if not isinstance(expected,list) or not expected:errors.append('missing independent character coverage')
    for id in expected if isinstance(expected,list) else []:
        if not any(key.startswith('characters/'+id+'/') for key in result['frames']):errors.append('missing live character: '+id)
    for id,frame in inventory['frames'].items():
        if frame.get('resource_only',False)!=(id.startswith('atlas/')):errors.append('resource-only marker used outside resource index: '+id)
    atlas_paths=[]
    for path in (root/'assets/game').rglob('*.tres'):
        if any((p/'.gdignore').exists() for p in path.parents if p.is_relative_to(root)):continue
        if '[gd_resource type="AtlasTexture"' in path.read_text():atlas_paths.append('res://'+path.relative_to(root).as_posix())
    if set(atlas_paths)!=set(inventory['atlas_resources']):errors.append('atlas resource coverage differs')
    # Количество берётся из реестров, а не из ожидаемого числа старого снимка.
    levels=read(root/'assets/game/items/ui/padded/catalog.json')['levels']
    ui=levels[0]['entries']
    for kind in ui:
        for size in [8,16,32,64,160]:
            if 'ui/'+kind+'/'+str(size) not in result['frames']:errors.append('missing item level: '+kind+'/'+str(size))
        for level in levels:
            id='ui/'+kind+'/'+str(level['frame_size']);frame=inventory['frames'].get(id,{})
            chain=inventory['textures'].get(frame.get('image'),{}).get('chain',[])
            if not chain or chain[0].get('region')!=level['entries'][kind] or not any(r.get('path')==level['file'] for r in chain) or frame.get('rect')!=[0,0,level['frame_size'],level['frame_size']]:errors.append('prepared frame differs from packing: '+id)
    manifest=root/'assets/game/world_sprite_manifest.json'
    if manifest.exists():
        for family in read(manifest)['entries']:
            for entry in family['assets']:
                file=(root/entry['path']).resolve()
                if not file.is_relative_to(root.resolve()):errors.append('world manifest path escaped project');continue
                with Image.open(file) as source:
                    if list(source.size)!=[entry['width'],entry['height']]:errors.append('world source dimensions differ: '+entry['path'])
    return errors


def export(root, destination):
    """Запускает изолированный Godot без изменения игровых слотов и требует успешного журнала движка."""
    binary=os.environ.get('FARM_GODOT_BIN',str(root/'tools/Godot.app/Contents/MacOS/Godot'))
    if not Path(binary).is_file():binary='godot'
    env={**os.environ,'VSLICE_OUTPUT':str(destination),'VSLICE_PROFILE':'Codex-VPIPELINE-008-'+os.urandom(8).hex()}
    before=inputs(root, source_paths=PACKAGED_EXPORTERS)
    process=subprocess.run([binary,'--headless','--path',str(root),'--script','res://tools/assets/slicing/slice_export.gd'],env=env,text=True,capture_output=True,timeout=240)
    log=process.stdout+process.stderr
    if process.returncode or any(s in log for s in ['ERROR:','SCRIPT ERROR','Parse Error']):raise ValueError('slice export failed: '+log[-4000:])
    if before!=inputs(root, source_paths=PACKAGED_EXPORTERS):raise ValueError('slice source changed during export')
    inventory=read(destination/'inventory.json')
    if inventory.get('tool_source_paths')!=PACKAGED_EXPORTERS:raise ValueError('slice exporter paths differ')
    inventory['inputs_sha256']=before
    (destination/'inventory.json').write_text(json.dumps(inventory,separators=(',',':'))+'\n')
    (destination/'export.log').write_text(log)


def main():
    """По умолчанию проверяет свежую выгрузку; запись снимка требует исходного commit и неизменных runtime-файлов."""
    parser=argparse.ArgumentParser();parser.add_argument('--folder',type=Path);parser.add_argument('--record',action='store_true');parser.add_argument('--report',type=Path);args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='farm-slices-') as temporary:
        folder=args.folder
        if folder is None:folder=Path(temporary)/'export';export(ROOT,folder)
        result=evaluate(folder)
        if args.report:
            target=args.report.resolve()
            if target.is_relative_to((ROOT/'assets').resolve()) or target.exists():raise SystemExit('report requires a new directory outside assets')
            target.mkdir(parents=True)
            for name,value in [('inventory.json',read(folder/'inventory.json')),('measurements.json',result)]:
                (target/name).write_text(json.dumps(value,separators=(',',':'))+'\n')
            shutil.copyfile(folder/'export.log',target/'export.log')
        if args.record:
            policy=read(current_source(ROOT, POLICY))
            if subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,env=git_environment(),text=True).strip()!=policy['baseline_commit']:raise SystemExit('initial slice snapshot requires exact base commit')
            if subprocess.check_output(['git','diff','HEAD','--name-only','--','assets/game','scripts','wiki/scripts'],cwd=ROOT,env=git_environment(),text=True).strip():raise SystemExit('changed runtime cannot enter legacy slice debt')
            if subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','assets/game','scripts','wiki/scripts'],cwd=ROOT,env=git_environment(),text=True).strip():raise SystemExit('untracked runtime cannot enter legacy slice debt')
            if read(folder/'inventory.json').get('inputs_sha256')!=inputs(ROOT):raise SystemExit('legacy snapshot requires a fresh source-bound export')
            if sorted(result['errors'])!=sorted(policy.get('initial_geometry_issues',[])):raise SystemExit('unexpected initial geometry issues:\n'+'\n'.join(result['errors']))
            destination=ROOT/REPORT;destination.mkdir(parents=True,exist_ok=True)
            payload={'baseline_commit':policy['baseline_commit'],'summary':result['summary'],'geometry_issues':result['errors'],'warnings':{id:row for id,row in result['frames'].items() if row['warnings']}}
            with (destination/'legacy-slices.json').open('x') as file:json.dump(payload,file,ensure_ascii=False,indent=2);file.write('\n')
            with (destination/'inventory.json').open('x') as file:json.dump(read(folder/'inventory.json'),file,ensure_ascii=False,separators=(',',':'));file.write('\n')
            with (destination/'measurements.json').open('x') as file:json.dump(result,file,ensure_ascii=False,separators=(',',':'));file.write('\n')
            shutil.copyfile(folder/'export.log',destination/'export.log')
        else:
            errors=check(ROOT,folder,result)
            from tools.assets.slicing.slice_proof import validate
            errors.extend(validate(ROOT))
            proof=read(ROOT/REPORT/'proof.json')
            tracked=set(subprocess.check_output(['git','-C',str(ROOT),'ls-files','-z'],cwd=ROOT,env=git_environment()).decode().split('\0'))
            for name in set(proof['files'])|{'proof.json'}:
                if REPORT+'/'+name not in tracked:errors.append('slice proof input missing from Git index: '+name)
            if errors:raise SystemExit('\n'.join(errors))
        print('SLICE AUDIT:',json.dumps(result['summary']),'; recorded blocking geometry issues: '+str(len(result['errors'])) if args.record and result['errors'] else '; geometry valid; existing tight frames remain explicit debt')


if __name__=='__main__':main()
