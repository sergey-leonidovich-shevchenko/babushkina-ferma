#!/usr/bin/env python3
"""VPIPELINE-010: воспроизводимый аудит стоимости/происхождения и состава настоящего экспорта."""
from __future__ import annotations
import argparse
import csv
from functools import lru_cache
import io
import json
import os
from pathlib import Path
import re
import sys
import subprocess
from asset_costs import names,measure,origin,summarize,sha,rgba_bytes
from migration_inventory import git_bytes,git_read

ROOT=Path(__file__).resolve().parents[1]
REPORT='docs/reports/visual-overhaul/vpipeline-010'
BASE='6ade4a2c8a2fac640109d3365c69bd4b6ccadfc4'


def json_bytes(value):
    """Сохраняет детерминированный UTF-8 с читаемыми исходными именами."""
    return (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()


def reader(root,base):
    """Читает неизменённый текущий файл либо точные исторические байты без переключения checkout."""
    available=git_read(root,'ls-tree','-r','--name-only',base,text=True).splitlines()
    selected=[n for n in available if n.startswith(('assets/game/','scripts/','level_designs/')) or n.startswith('tools/') and n.endswith('.py') or n in ['project.godot','main.tscn','tools/visual_asset_policy.json','assets/app_icon.png','assets/app_icon.png.import','assets/title_art_rpg.png','assets/title_art_rpg.png.import']]
    env={k:v for k,v in os.environ.items() if not k.startswith('GIT_')}
    result=subprocess.run(['git','-C',str(root),'cat-file','--batch'],input=''.join(base+':'+n+'\n' for n in selected).encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,check=True).stdout
    blobs={};offset=0
    for name in selected:
        end=result.index(b'\n',offset);header=result[offset:end].split()
        if len(header)!=3 or header[1]!=b'blob':raise ValueError('invalid historical blob: '+name)
        length=int(header[2]);blobs[name]=result[end+1:end+1+length];offset=end+length+2
    @lru_cache(maxsize=None)
    def read(name):
        if not isinstance(name,str) or Path(name).is_absolute() or '..' in Path(name).parts:raise ValueError('unsafe source: '+str(name))
        path=root/name
        if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):raise ValueError('symlink source: '+name)
        # Исторический аудит всегда читает Git; новый artwork не переписывает свидетельства прошлого.
        return blobs[name] if name in blobs else git_bytes(root,base,name)
    return read


def build(files,read,rules,base):
    """Проверяет все production-файлы, готовые бинарные изображения и адресные производные UI."""
    policy=json.loads(read('tools/visual_asset_policy.json'))
    paths=names(files,policy);records={}
    for name in paths:
        raw=read(name);imported=read(name+'.import') if name+'.import' in paths else b''
        if Path(name).suffix=='.png' and not imported:raise ValueError('missing import: '+name)
        row=measure(name,raw,imported);row['origin']=origin(name,raw,rules,read);records[name]=row
    prepared=json.loads(read('assets/game/prepared_pixels/catalog.gd').decode().split('const ENTRIES := ',1)[1])
    for key,entry in prepared.items():
        name=entry['resource'].removeprefix('res://');source=key.split('|',1)[1].removeprefix('res://')
        if name==source:continue
        row=records[name]
        if source not in records or not re.fullmatch('[0-9a-f]{64}',entry['output_sha256']):raise ValueError('prepared source contract invalid: '+name)
        row.update(pixels=[entry['width'],entry['height']],texture_rgba8_bytes=rgba_bytes(entry['width'],entry['height']),memory_note='embedded prepared ImageTexture; dimensions from hash-bound catalog, independently checked by native export probe')
        row['prepared_rgba_sha256']=entry['output_sha256']
        row['origin']={'kind':'prepared-derived','claim':'Prepared pixels; permission follows original source, not a new original work','license_status':'inherits-source-review','sources':[source],'evidence':[{'path':'assets/game/prepared_pixels/catalog.gd','sha256':sha(read('assets/game/prepared_pixels/catalog.gd'))}],'release_clearance':False}
    catalog_path='assets/game/items/ui/catalog.json';catalog=json.loads(read(catalog_path))
    ui={}
    for kind,entry in catalog['entries'].items():ui['assets/game/items/ui/preview/'+kind+'.png']=[entry['path'].removeprefix('res://')] if entry['path'] else []
    ui['assets/game/items/ui/thumbnails.png']=sorted({e['path'].removeprefix('res://') for e in catalog['entries'].values() if e['path']})
    padded=json.loads(read('assets/game/items/ui/padded/catalog.json'))
    for level in padded['levels']:ui[level['file'].removeprefix('res://')]=['assets/game/items/ui/thumbnails.png']
    for name,sources in ui.items():
        if any(s not in records for s in sources):raise ValueError('missing UI source: '+name)
        records[name]['origin']={'kind':'prepared-derived','claim':'UI derivative; upstream permissions remain subject to source review','license_status':'inherits-source-review','sources':sources,'evidence':[{'path':catalog_path,'sha256':sha(read(catalog_path))}],'release_clearance':False}
        if '/preview/' in name:
            entry=catalog['entries'][Path(name).stem]
            records[name]['origin'].update(provider=entry['provider'],source_fingerprint=entry['sourceHash'],computed_source_unresolved=not bool(entry['path']))
    return {'schema':1,'task':'VPIPELINE-010','base_commit':base,'scope':'tracked production files including imported metadata, app/title and embedded textures; not live residency','rules':rules,'files':records,'summary':summarize(records)}


def csv_bytes(data):
    """Даёт компактный адресный список для сортировки и внешнего просмотра без потери неизвестных значений."""
    out=io.StringIO();writer=csv.writer(out);writer.writerow(['path','sha256','disk_bytes','width','height','nominal_rgba8_bytes','origin','license_status'])
    for name,row in data['files'].items():writer.writerow([name,row['sha256'],row['disk_bytes'],*(row['pixels'] or ['','']),row['texture_rgba8_bytes'],row['origin']['kind'],row['origin']['license_status']])
    return out.getvalue().encode()


def working_reader(root, rules=None):
    """Читает живые ресурсы; только явно объявленные свидетельства генераторов берёт из точной истории."""
    root = root.resolve()
    rules = {} if rules is None else rules
    if not isinstance(rules, dict) or not isinstance(rules.get('evidence_history', {}), dict):
        raise ValueError('invalid evidence history')
    declared = set()
    declarations = rules.get('rules', [])
    if not isinstance(declarations, list) or any(not isinstance(rule, dict) for rule in declarations):
        raise ValueError('invalid provenance rules')
    for rule in declarations:
        evidence = rule.get('evidence', [])
        if not isinstance(evidence, list) or any(not isinstance(name, str) for name in evidence):
            raise ValueError('invalid evidence paths')
        declared.update(evidence)
    pins = {}
    for name, entry in rules.get('evidence_history', {}).items():
        if (not isinstance(name, str) or Path(name).parent != Path('tools')
                or Path(name).as_posix() != name or name not in declared
                or Path(name).suffix not in {'.py', '.gd', '.sh', '.mjs', '.swift', '.gdshader'}
                or not isinstance(entry, dict) or set(entry) != {'commit', 'sha256'}
                or not isinstance(entry['commit'], str) or not re.fullmatch('[0-9a-f]{40}', entry['commit'])
                or not isinstance(entry['sha256'], str) or not re.fullmatch('[0-9a-f]{64}', entry['sha256'])):
            raise ValueError('invalid historical evidence pin: ' + str(name))
        pins[name] = (entry['commit'], entry['sha256'])
    if pins:
        try:
            repository = Path(git_read(root, 'rev-parse', '--show-toplevel', text=True).strip()).resolve()
        except subprocess.CalledProcessError as error:
            raise ValueError('historical evidence requires its repository root') from error
        if repository != root:
            raise ValueError('historical evidence cannot borrow a parent repository')

    @lru_cache(maxsize=None)
    def historical(name):
        """Кэширует только неизменный Git blob; текущие PNG и политика не попадают в этот кэш."""
        commit, expected = pins[name]
        try:
            raw = git_bytes(root, commit, name)
        except subprocess.CalledProcessError as error:
            raise ValueError('historical evidence unavailable: ' + name) from error
        if sha(raw) != expected:
            raise ValueError('historical evidence SHA256 mismatch: ' + name)
        return raw

    def read(name):
        """Сохраняет прежнюю защиту traversal/symlink и отказывает без общего historical fallback."""
        if not isinstance(name, str):
            raise ValueError('unsafe current input')
        path = root / name
        if (Path(name).is_absolute() or '..' in Path(name).parts or path.is_symlink()
                or not path.resolve().is_relative_to(root)):
            raise ValueError('unsafe current input')
        if name in pins:
            return historical(name)
        return path.read_bytes()
    return read


def current_inventory(root):
    """Собирает актуальный каталог, не замораживая будущие согласованные рисунки историческим снимком."""
    files=git_read(root,'ls-files','--cached','--others','--exclude-standard',text=True).splitlines()
    read=working_reader(root)
    rules=json.loads(read('tools/asset_provenance.json'))
    return build(sorted(set(files)),working_reader(root,rules),rules,'working-tree')


def current_errors(baseline,current):
    """Сохраняет адресный прежний долг, но требует происхождение у нового и изменённого неизвестного медиа."""
    return ['new or changed media requires documented origin: '+name for name,row in current['files'].items() if row['origin']['kind']=='unresolved' and (name not in baseline['files'] or row['sha256']!=baseline['files'][name]['sha256'])]


def verify(root):
    """Заново вычисляет исторический отчёт, отдельно не позволяя новым неизвестным медиа пройти незаметно."""
    folder=root/REPORT;errors=[]
    try:
        data=json.loads((folder/'inventory.json').read_text());base=data['base_commit']
        files=git_read(root,'ls-tree','-r','--name-only',base,text=True).splitlines()
        expected=build(files,reader(root,base),data['rules'],base)
        if data!=expected:errors.append('historical asset report differs from actual Git sources, sizes, origin or memory')
        if (folder/'inventory.csv').read_bytes()!=csv_bytes(expected):errors.append('CSV differs from inventory')
        current=current_inventory(root);policy=json.loads((root/'tools/visual_asset_policy.json').read_text())
        errors+=current_errors(data,current)
        from asset_pack import proof_errors,preset_errors
        errors+=preset_errors((root/'export_presets.cfg').read_text(),policy)
        errors+=proof_errors(root,data)
        proof=json.loads((folder/'proof.json').read_text())
        tracked=set(git_read(root,'ls-files',text=True).splitlines())
        for name in ['inventory.json','inventory.csv','proof.json',*proof['artifacts']]:
            if REPORT+'/'+name not in tracked:errors.append('export evidence must be in Git index: '+name)
    except Exception as exc:errors.append('invalid asset report: '+str(exc))
    return errors


def main():
    """Записывает первичный снимок только на согласованной базе либо выполняет read-only проверку."""
    parser=argparse.ArgumentParser();parser.add_argument('--record',action='store_true');parser.add_argument('--current-output',type=Path);args=parser.parse_args()
    if args.current_output:
        if args.current_output.exists():raise SystemExit('current report requires a new output file')
        args.current_output.write_bytes(json_bytes(current_inventory(ROOT)));return
    if args.record:
        if git_read(ROOT,'rev-parse','HEAD',text=True).strip()!=BASE:raise SystemExit('record requires exact VPIPELINE-009 base')
        folder=ROOT/REPORT
        if (folder/'inventory.json').exists():raise SystemExit('inventory already recorded')
        rules=json.loads((ROOT/'tools/asset_provenance.json').read_text())
        data=build(git_read(ROOT,'ls-tree','-r','--name-only',BASE,text=True).splitlines(),reader(ROOT,BASE),rules,BASE)
        folder.mkdir(parents=True,exist_ok=True);(folder/'inventory.json').write_bytes(json_bytes(data));(folder/'inventory.csv').write_bytes(csv_bytes(data))
        print(json.dumps(data['summary'],ensure_ascii=False,indent=2));return
    errors=verify(ROOT)
    if errors:print('\n'.join(errors),file=sys.stderr);raise SystemExit(1)
    print('ASSET REPORT: provenance dispositions, sizes, nominal memory and native export proof valid; release clearance not implied')


if __name__=='__main__':main()
