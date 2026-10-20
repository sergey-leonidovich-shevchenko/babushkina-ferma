#!/usr/bin/env python3
"""Создаёт отдельную копию для настоящего export-pack и проверяет её содержимое без запуска игры."""
from __future__ import annotations
import configparser
import io
import json
from pathlib import Path
import re
import shutil
import zipfile
from PIL import Image,ImageChops
from asset_costs import sha,rgba_bytes
from migration_inventory import git_bytes,git_read


def preset_errors(text,policy):
    """Отклоняет широкое включение исходников, потерю барьеров и шифрование проверяемого пакета."""
    cfg=configparser.ConfigParser(interpolation=None);cfg.read_string(text);errors=[]
    values=cfg['preset.0'];excluded=json.loads(values['exclude_filter']).split(',')
    for folder in policy['non_runtime_roots']+['tools','tests']:
        if folder+'/*' not in excluded:errors.append('missing export exclusion: '+folder)
    if values.get('export_filter')!='"all_resources"' or values.get('encrypt_pck')!='false':errors.append('unexpected pack policy')
    if values.get('include_filter')!='"assets/game/*.json,assets/game/*.txt,level_designs/published/*.json"':errors.append('unsafe raw include filter')
    return errors


def create(root,target,data):
    """Копирует реальные production-байты и скрипты в новый внешний проект с отдельным профилем."""
    from asset_report import reader
    target=target.absolute()
    if target.exists() or target.resolve().is_relative_to(root.resolve()) or target.parent.is_symlink():raise ValueError('fixture requires new external directory')
    target.mkdir(parents=True);base=data['base_commit']
    files=git_read(root,'ls-tree','-r','--name-only',base,text=True).splitlines()
    selected=sorted(set(data['files'])|{p for p in files if p.startswith(('scripts/','level_designs/')) or p in ['main.tscn','project.godot']})
    copied={};read=reader(root,base)
    for name in selected:
        raw=read(name);destination=target/name;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(raw);copied[name]=sha(raw)
    project=(target/'project.godot').read_text().replace('config/name="Бабушкина ферма: Тайна Лунной долины"','config/name="VPIPELINE-010 export fixture"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Codex-VPIPELINE-010-fixture"')
    (target/'project.godot').write_text(project)
    shutil.copyfile(root/'export_presets.cfg',target/'export_presets.cfg')
    sentinels=[]
    policy=json.loads((root/'tools/visual_asset_policy.json').read_text())
    for folder in policy['non_runtime_roots']+['tools','tests']:
        destination=target/folder;destination.mkdir(parents=True,exist_ok=True);(destination/'.gdignore').touch()
        for suffix,raw in [('json',b'{"do_not_ship":true}'),('zip',b'non-runtime archive canary'),('png',(root/'assets/game/interiors/furniture_a/rustic_table_south.png').read_bytes())]:
            name=folder+'/DO_NOT_SHIP.'+suffix;(target/name).write_bytes(raw);sentinels.append(name)
    (target/'probe-input.json').write_text(json.dumps({'paths':[p for p in data['files'] if Path(p).suffix in ['.png','.res']], 'sentinels':sentinels}))
    return {'base_commit':base,'copied_files':copied,'project_sha256':sha((target/'project.godot').read_bytes()),'preset_sha256':sha((target/'export_presets.cfg').read_bytes()),'probe_input_sha256':sha((target/'probe-input.json').read_bytes()),'sentinels':sentinels}


def inspect_pack(path,expected,policy):
    """Проверяет ZIP Godot: настоящие remap-цепочки, payload всех production-ресурсов и отсутствие макетов."""
    errors=[];entries={};resources={}
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            name=info.filename
            if name in entries or name.startswith('/') or '..' in Path(name).parts:errors.append('unsafe/duplicate pack entry: '+name)
            raw=archive.read(info);entries[name]={'sha256':sha(raw),'bytes':len(raw)}
        for name in entries:
            if any(name==p or name.startswith(p+'/') for p in policy['non_runtime_roots']+['tools','tests']):errors.append('non-runtime file in pack: '+name)
            if name.startswith('assets/') and name not in expected and not any(name==p+suffix for suffix in ['.import','.remap'] for p in expected):errors.append('unreported asset in pack: '+name)
        for name,row in expected.items():
            if Path(name).suffix in ['.md','.uid','.import']:continue
            if name in entries:
                resources[name]={'direct':True,'payloads':[name]}
                if Path(name).suffix in ['.json','.txt','.res'] and entries[name]['sha256']!=row['sha256']:errors.append('raw exported bytes differ: '+name)
                continue
            remap=name+('.import' if Path(name).suffix in ['.png','.wav','.ttf'] else '.remap')
            if remap not in entries:errors.append('missing exported resource: '+name);continue
            references=re.findall(r'^path(?:\.[a-z0-9_]+)?="res://([^"]+)"',archive.read(remap).decode(),re.M)
            resources[name]={'direct':False,'remap':remap,'payloads':references}
            if not references:errors.append('missing payload remap: '+name)
            for target in references:
                if target not in entries:errors.append('missing exported payload: '+name+' -> '+target)
    return {'archive_sha256':sha(path.read_bytes()),'archive_bytes':path.stat().st_size,'entries':entries,'resources':resources,'errors':errors}


def proof_errors(root,data):
    """Сверяет весь нативный пакет, оценки бинарных текстур и неизменность изображения при одной камере."""
    from asset_report import REPORT
    folder=root/REPORT;errors=[]
    try:
        proof=json.loads((folder/'proof.json').read_text())
        for name,digest in proof['artifacts'].items():
            path=folder/name
            if Path(name).is_absolute() or '..' in Path(name).parts or path.is_symlink() or not path.resolve().is_relative_to(folder.resolve()):raise ValueError('unsafe proof path')
            if sha(path.read_bytes())!=digest:errors.append('export proof artifact differs: '+name)
        if proof['base_commit']!=data['base_commit'] or proof['production_changed'] is not False or proof['release_clearance'] is not False:errors.append('invalid export proof scope')
        if sha((root/'tools/asset_pack_probe.gd').read_bytes())!=proof['probe_sha256']:errors.append('probe code changed')
        source=json.loads((folder/'native/source/capture.json').read_text());packed=json.loads((folder/'native/pack/capture.json').read_text())
        paths={p for p in data['files'] if Path(p).suffix in ['.png','.res']}
        for stage,name in [(source,'source'),(packed,'pack')]:
            if stage['errors'] or stage['framebuffer']!=[1152,648] or stage['display_server']=='headless' or stage['method']!='gl_compatibility' or stage['performance_eligible'] is not False:errors.append('invalid native export stage: '+name)
            if set(stage['textures'])!=paths:errors.append('native texture coverage differs: '+name)
            if not stage['profile'].startswith('Codex-VPIPELINE-010-') or stage['probe_sha256']!=proof['probe_sha256']:errors.append('native profile/probe differs')
            if name=='pack' and stage['visible_sentinels']:errors.append('non-runtime sentinel visible from pack')
            if bool(stage['physical_project_present'])!=(name=='source'):errors.append('pack can fall back to a physical source project')
            for path,info in stage['textures'].items():
                row=data['files'][path]
                if info['pixels']!=row['pixels'] or info['nominal_rgba8_bytes']!=row['texture_rgba8_bytes']:errors.append('native size/memory differs: '+path)
                if row.get('prepared_rgba_sha256') and row['prepared_rgba_sha256']!=info['rgba_sha256']:errors.append('prepared binary RGBA differs: '+path)
        if source['textures']!=packed['textures']:errors.append('imported source/pack pixels or formats differ')
        if source['engine']!=packed['engine'] or source['method']!=packed['method'] or source['driver']!=packed['driver']:errors.append('source/pack renderer configuration differs')
        if source['camera']!=packed['camera'] or source['camera']!={'position':[0,0],'zoom':1,'framebuffer':[1152,648]}:errors.append('native camera differs')
        for background in ['light','dark']:
            with Image.open(folder/'native/source'/(background+'.png')) as before,Image.open(folder/'native/pack'/(background+'.png')) as after:
                if before.size!=(1152,648) or after.size!=before.size or before.mode!='RGBA' or after.mode!='RGBA' or ImageChops.difference(before,after).getbbox(alpha_only=False):errors.append('source/pack GPU frame differs: '+background)
        pack=json.loads((folder/'pack.json').read_text());policy=json.loads((root/'tools/visual_asset_policy.json').read_text())
        if pack['errors'] or pack['archive_bytes']<=0:errors.append('invalid pack evidence')
        for name in pack['entries']:
            if any(name.startswith(p+'/') for p in policy['non_runtime_roots']+['tools','tests']):errors.append('non-runtime pack evidence entry: '+name)
        expected={p for p in data['files'] if Path(p).suffix not in ['.md','.uid','.import']}
        if set(pack['resources'])!=expected:errors.append('exported resource coverage differs')
        for name,row in pack['resources'].items():
            if not row['payloads'] or any(p not in pack['entries'] for p in row['payloads']):errors.append('pack proof missing payload: '+name)
            if not row['direct'] and row['remap'] not in pack['entries']:errors.append('pack proof missing remap: '+name)
            if row['direct'] and Path(name).suffix in ['.json','.txt','.res'] and pack['entries'][name]['sha256']!=data['files'][name]['sha256']:errors.append('pack proof raw source differs: '+name)
        fixture=json.loads((folder/'fixture.json').read_text())
        if fixture['base_commit']!=data['base_commit'] or any(fixture['copied_files'].get(p)!=r['sha256'] for p,r in data['files'].items()):errors.append('fixture production inputs differ')
        if fixture['preset_sha256']!=sha((root/'export_presets.cfg').read_bytes()):errors.append('fixture preset differs')
        if set(source['visible_sentinels'])!=set(fixture['sentinels']) or len(fixture['sentinels'])<20:errors.append('source canaries were not exercised')
        negative=json.loads((folder/'negative-pack.json').read_text());failure=json.loads((folder/'native/negative/capture.json').read_text())
        missing='assets/game/interiors/furniture_a/rustic_table_south.png'
        if not any('non-runtime file in pack' in e for e in negative['errors']) or not any('missing exported payload' in e for e in negative['errors']):errors.append('missing pack negative controls')
        if failure['physical_project_present'] or failure['errors']!=['missing texture: '+missing] or set(failure['textures'])!=paths-{missing}:errors.append('broken pack did not fail in isolated native loader')
        lost=pack['resources'][missing]['payloads'][0]
        if set(negative['entries'])!=(set(pack['entries'])-{lost})|{'docs/DO_NOT_SHIP.zip'} or negative['resources']!=pack['resources']:errors.append('negative archive mutation differs')
        if any(negative['entries'][p]!=v for p,v in pack['entries'].items() if p!=lost and p in negative['entries']):errors.append('negative archive changed unrelated payload')
        game_source=json.loads((folder/'native/game-source/capture.json').read_text());game_pack=json.loads((folder/'native/game-pack/capture.json').read_text())
        points_digest=sha(git_bytes(root,data['base_commit'],'tools/visual_camera_points.gd'))
        registry_digest=sha(git_bytes(root,data['base_commit'],'docs/reports/visual-overhaul/vbase-003/camera-points.json'))
        if sha((root/'tools/asset_game_probe.gd').read_bytes())!=proof['game_probe_sha256']:errors.append('game probe changed')
        for game,label in [(game_source,'source'),(game_pack,'pack')]:
            if game['errors'] or game['framebuffer']!=[1152,648] or game['display_server']=='headless' or game['performance_eligible'] is not False or game['probe_sha256']!=proof['game_probe_sha256']:errors.append('invalid native game stage: '+label)
            if bool(game['physical_project_present'])!=(label=='source') or not game['profile'].startswith('Codex-VPIPELINE-010-'):errors.append('native game isolation differs')
            if set(game['scenes'])!={'overworld','cottage_interior'}:errors.append('incomplete native game scenes')
            if game['points_sha256']!=points_digest or game['registry_sha256']!=registry_digest:errors.append('historical camera instrument/registry differs')
        if game_source['scenes']!=game_pack['scenes']:errors.append('exported game camera or serialized state differs')
        for location in ['overworld','cottage_interior']:
            if not game_source['scenes'][location]['state_unchanged']:errors.append('native draw changed state')
            with Image.open(folder/'native/game-source'/(location+'.png')) as a,Image.open(folder/'native/game-pack'/(location+'.png')) as b:
                if a.size!=(1152,648) or b.size!=a.size or a.mode!='RGBA' or b.mode!='RGBA' or ImageChops.difference(a,b).getbbox(alpha_only=False):errors.append('exported native game image differs: '+location)
        required={'native/source/capture.json','native/pack/capture.json','native/source/light.png','native/source/dark.png','native/pack/light.png','native/pack/dark.png','fixture.json','pack.json','negative-pack.json','native/negative/capture.json','native/game-source/capture.json','native/game-pack/capture.json'}
        required|={'native/game-'+stage+'/'+location+'.png' for stage in ['source','pack'] for location in ['overworld','cottage_interior']}
        required|={'wiki-review.json','wiki-review.jpg'}
        if not required<=set(proof['artifacts']):errors.append('incomplete export proof artifacts')
        if 'boot.log' not in proof['artifacts'] or proof['pack_boot']['exit_code']!=0 or proof['pack_boot']['physical_cwd_empty'] is not True or re.search(r'ERROR:|SCRIPT ERROR|Parse Error',(folder/'boot.log').read_text()):errors.append('exported main scene failed to boot')
        wiki=json.loads((folder/'wiki-review.json').read_text())
        if wiki['csv_rows']!=data['summary']['files'] or wiki['csv_download_sha256']!=sha((folder/'inventory.csv').read_bytes()) or wiki['game_entries_unchanged'] is not True or wiki['game_entry_count']!=921:errors.append('Wiki download/game-entry proof differs')
        downloads={row['download']:row['href'] for row in wiki['dom']['downloads']}
        for name in ['inventory.csv','inventory.json','pack.json']:
            if downloads.get(name)!='generated/attachments/'+sha((folder/name).read_bytes())+Path(name).suffix:errors.append('Wiki download href differs: '+name)
    except Exception as exc:errors.append('invalid export proof: '+str(exc))
    return errors


def main():
    """Создаёт новый стенд или записывает проверку внешнего ZIP без изменения рабочих ресурсов."""
    import argparse
    from asset_report import ROOT,REPORT,json_bytes,current_inventory
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['fixture','inspect']);parser.add_argument('path',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    if args.output.exists():raise SystemExit('receipt output must be new')
    data=json.loads((ROOT/REPORT/'inventory.json').read_text())
    result=create(ROOT,args.path,data) if args.action=='fixture' else inspect_pack(args.path,current_inventory(ROOT)['files'],json.loads((ROOT/'tools/visual_asset_policy.json').read_text()))
    args.output.write_bytes(json_bytes(result));print('ASSET PACK:',args.action,'errors=',result.get('errors',[]))
    if result.get('errors'):raise SystemExit(1)


if __name__=='__main__':main()
