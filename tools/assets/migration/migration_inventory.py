#!/usr/bin/env python3
"""Снимает потенциальных потребителей графики; отсутствие ссылки не разрешает удаление."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
from tools.common.history import pinned_sha
from tools.common.paths import project_root
import re
import subprocess
from tools.assets.contracts.visual_pipeline import ignored
from tools.assets.contracts.source_paths import historical_source

EXTENSIONS={'.png','.webp','.tres','.res','.json','.gd','.uid','.import'}
TEXT={'.gd','.tscn','.tres','.json','.mjs','.ts','.vue','.py','.sh','.godot','.cfg'}
QUOTED=re.compile(r'''["'`]((?:res://)?assets/game/[^"'`\n]+)["'`]''')
SLOT=re.compile(r'\$?\{[^{}\n]*\}|%(?:\([^)]+\))?[-+ #0]*\d*(?:\.\d+)?[sdiufxX]')
ROOTS=('scripts/','tests/','wiki/scripts/','wiki/src/','tools/','level_designs/','assets/game/')
# У прежних inventory нет режима источника; их scanner остаётся точным Git blob до переноса.
LEGACY_SCANNER = (
    'tools/migration_inventory.py',
    'd609ab4fa6d82d6d013265183f018b8836abf7cc',
    '4b9cc690faef431b6e93ef2040600c2f078e27c5f50820e4baf3d373a246916c',
)


def sha(raw):
    """Привязывает снимок к точным байтам без изменения файлов."""
    return hashlib.sha256(raw).hexdigest()


def scanner_digest(inventory: dict) -> str:
    """Различает прежний Git-инструмент и свежий текущий код без пути из metadata."""
    if 'scanner_source_mode' not in inventory:
        return pinned_sha(project_root(__file__), *LEGACY_SCANNER)
    if inventory['scanner_source_mode'] == 'current':
        return sha(Path(__file__).read_bytes())
    raise ValueError('unknown migration scanner source mode')


def git_bytes(root, commit, name):
    """Читает исторический файл только из конкретного commit без checkout и перезаписи истории."""
    return git_read(root,'show',commit+':'+name)


def git_read(root, *args, text=False):
    """Изолирует read-only Git от переменных вызывающего hook и альтернативного индекса."""
    env={key:value for key,value in os.environ.items() if not key.startswith('GIT_')}
    return subprocess.check_output(['git','-C',str(root),*args],env=env,text=text,stderr=subprocess.PIPE)


def runtime_names(files, policy):
    """Учитывает барьеры исходного commit, чтобы новая графика не меняла исторический охват."""
    barriers={str(Path(name).parent) for name in files if Path(name).name=='.gdignore'}
    return [name for name in files if name.startswith('assets/game/') and Path(name).suffix in EXTENSIONS and not ignored(name,policy) and not any(name.startswith(folder+'/') for folder in barriers)]


def source_scope(name):
    """Отделяет runtime-читателя от метаданных, Wiki, инструмента и теста без вывода о фактической загрузке."""
    return 'runtime' if name.startswith('scripts/') or name in ['project.godot','main.tscn'] else ('level' if name.startswith('level_designs/') else 'wiki' if name.startswith('wiki/') else 'tool' if name.startswith('tools/') else 'test' if name.startswith('tests/') else 'metadata')


def candidates(text, names):
    """Сохраняет literal, форматные и консервативные prefix-ссылки; это возможные потребители, не факты загрузки."""
    result=set()
    for match in QUOTED.finditer(text):
        value=match[1].removeprefix('res://')
        if value in names:result.add((value,'literal'));continue
        if SLOT.search(value):
            pattern=re.compile('.*'.join(re.escape(chunk) for chunk in SLOT.split(value)))
            result.update((name,'template') for name in names if pattern.fullmatch(name))
        elif not Path(value).suffix:
            result.update((name,'prefix') for name in names if name.startswith(value))
    return result


def build(root:Path, commit:str):
    """Инвентаризует текущие байты исходного commit, все runtime-ресурсы, импорты, UID и кодовые читатели."""
    files=git_read(root,'ls-tree','-r','--name-only',commit,text=True).splitlines()
    policy=json.loads(git_bytes(root,commit,historical_source(set(files), 'tools/visual_asset_policy.json')))
    names=runtime_names(files,policy)
    records={};uids={}
    for name in names:
        raw=(root/name).read_bytes()
        record={'sha256':sha(raw),'bytes':len(raw),'consumers':[]}
        if name.endswith('.import'):
            match=re.search(r'^uid="(uid://[^"]+)"',raw.decode(),re.M)
            if match:record['uid']=match[1];uids.setdefault(match[1],[]).append(name.removesuffix('.import'))
        records[name]=record
    sources={};unresolved=[]
    for name in files:
        if Path(name).suffix not in TEXT or not (name.startswith(ROOTS) or name in ['project.godot','main.tscn']):continue
        if name.startswith('assets/game/') and name not in records:continue
        try:raw=(root/name).read_bytes();text=raw.decode()
        except (OSError,UnicodeError):continue
        scope=source_scope(name)
        sources[name]={'sha256':sha(raw),'scope':scope}
        for target,kind in candidates(text,set(names)):
            if target!=name:records[target]['consumers'].append({'source':name,'kind':kind,'scope':scope})
        for uid in set(re.findall(r'uid://[a-z0-9]+',text)):
            for target in uids.get(uid,[]):
                if target in records and target!=name:records[target]['consumers'].append({'source':name,'kind':'uid','scope':scope})
        for index,line in enumerate(text.splitlines(),1):
            if re.search(r'\b(?:load|preload|ResourceLoader\.load|Image\.load_from_file)\s*\(\s*[a-zA-Z_]',line):unresolved.append({'source':name,'line':index,'expression':line.strip()[:240]})
    for record in records.values():record['consumers'].sort(key=lambda row:(row['source'],row['kind']))
    return {'schema_version':1,'base_commit':commit,'kind':'potential-consumers-not-runtime-usage','deletion_authorized':False,'files':records,'sources':sources,'unresolved_calls':unresolved,'duplicate_uids':{uid:paths for uid,paths in uids.items() if len(set(paths))>1},'scanner_source_mode':'current','scanner_sha256':sha(Path(__file__).read_bytes())}


def historical_errors(root:Path, inventory:dict):
    """Проверяет исторический снимок, разрешая будущую согласованную замену через read-only Git baseline."""
    errors=[]
    if inventory.get('schema_version')!=1 or inventory.get('deletion_authorized') is not False or inventory.get('kind')!='potential-consumers-not-runtime-usage':return ['invalid migration inventory scope']
    try:tracked=git_read(root,'ls-tree','-r','--name-only',inventory['base_commit'],text=True).splitlines()
    except subprocess.CalledProcessError:return ['migration baseline commit missing: fetch the documented audit base before the offline gate']
    policy=json.loads(git_bytes(root,inventory['base_commit'],historical_source(set(tracked), 'tools/visual_asset_policy.json')))
    files=set(runtime_names(tracked,policy))
    sources={name for name in tracked if Path(name).suffix in TEXT and (name.startswith(ROOTS) or name in ['project.godot','main.tscn']) and (not name.startswith('assets/game/') or name in files)}
    if files!=set(inventory['files']) or sources!=set(inventory['sources']):errors.append('historical migration inventory coverage differs')
    try:
        if inventory.get('scanner_sha256') != scanner_digest(inventory):
            errors.append('migration scanner changed: review historical snapshot adapter')
    except (OSError, RuntimeError, ValueError) as error:
        errors.append('migration scanner source unavailable: ' + str(error))
    texts={};uids={}
    for name in set(inventory['files'])&set(inventory['sources']):
        if inventory['files'][name]['sha256']!=inventory['sources'][name]['sha256']:errors.append('inconsistent runtime/source signature: '+name)
    for name,record in {**inventory['files'],**inventory['sources']}.items():
        path=(root/name).resolve()
        if not path.is_relative_to(root.resolve()):errors.append('unsafe inventory path: '+name);continue
        raw=path.read_bytes() if path.is_file() else b''
        if sha(raw)!=record['sha256']:
            try:raw=git_bytes(root,inventory['base_commit'],name)
            except subprocess.CalledProcessError:errors.append('missing baseline resource: '+name);continue
        if sha(raw)!=record['sha256']:errors.append('baseline source differs: '+name)
        if name in inventory['sources']:texts[name]=raw.decode()
        if name.endswith('.import'):
            match=re.search(r'^uid="(uid://[^"]+)"',raw.decode(),re.M)
            if match:uids.setdefault(match[1],[]).append(name.removesuffix('.import'))
            if record.get('uid')!=(match[1] if match else None):errors.append('stored import UID differs: '+name)
    names=set(inventory['files']);expected={name:[] for name in names}
    unresolved=[]
    for name,text in texts.items():
        scope=inventory['sources'][name]['scope']
        if scope!=source_scope(name):errors.append('consumer scope differs: '+name)
        for target,kind in candidates(text,names):
            if target!=name:expected[target].append({'source':name,'kind':kind,'scope':scope})
        for uid in set(re.findall(r'uid://[a-z0-9]+',text)):
            for target in uids.get(uid,[]):
                if target in expected and target!=name:expected[target].append({'source':name,'kind':'uid','scope':scope})
        for index,line in enumerate(text.splitlines(),1):
            if re.search(r'\b(?:load|preload|ResourceLoader\.load|Image\.load_from_file)\s*\(\s*[a-zA-Z_]',line):unresolved.append({'source':name,'line':index,'expression':line.strip()[:240]})
    for name,rows in expected.items():
        if sorted(rows,key=lambda row:(row['source'],row['kind']))!=inventory['files'][name]['consumers']:errors.append('historical consumer graph differs: '+name)
    if unresolved!=inventory.get('unresolved_calls'):errors.append('unresolved migration reader list differs')
    if {uid:paths for uid,paths in uids.items() if len(set(paths))>1}!=inventory.get('duplicate_uids'):errors.append('duplicate UID inventory differs')
    return errors
