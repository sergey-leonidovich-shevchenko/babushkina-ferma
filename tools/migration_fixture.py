#!/usr/bin/env python3
"""Создаёт отдельный Godot-проект для проверки rename-only без изменений рабочей игры."""
from __future__ import annotations
import json
from pathlib import Path
import re
import shutil
from migration_inventory import git_bytes,git_read

START=['scripts/systems/visual_resource_catalog.gd','scripts/editor/level_editor_document_store.gd','scripts/systems/level_editor_asset_catalog_system.gd']
SIDES=['south','west','east']
CASE='migration-case.json'


def closure(root:Path, baseline=None):
    """Берёт настоящие транзитивные literal-зависимости трёх потребителей; динамический весь каталог не имитирует."""
    seen=set();pending=START.copy()
    available=set(git_read(root,'ls-tree','-r','--name-only',baseline,text=True).splitlines()) if baseline else None
    while pending:
        name=pending.pop()
        if name in seen:continue
        path=root/name
        if name not in available if baseline else not path.is_file():raise ValueError('missing fixture source: '+name)
        seen.add(name)
        if path.suffix in ['.gd','.tres','.tscn','.json']:
            raw=git_bytes(root,baseline,name).decode() if baseline else path.read_text()
            for value in re.findall(r'''["'](res://[^"'\n]+)["']''',raw):
                target=value.removeprefix('res://')
                if target in available if baseline else (root/target).is_file():pending.append(target)
    return sorted(seen)


def create(root:Path, target:Path, baseline=None):
    """Копирует ограниченные реальные зависимости и исходный документ в новый внешний каталог без symlink."""
    target=target.resolve()
    if target.exists() or target.is_relative_to(root.resolve()):raise ValueError('fixture requires a new directory outside the repository')
    target.mkdir(parents=True)
    names=closure(root,baseline)
    available=set(git_read(root,'ls-tree','-r','--name-only',baseline,text=True).splitlines()) if baseline else None
    for name in names:
        source=root/name;destination=target/name
        destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_bytes(git_bytes(root,baseline,name) if baseline else source.read_bytes())
        imported=Path(str(source)+'.import')
        if name+'.import' in available if baseline else imported.is_file():Path(str(destination)+'.import').write_bytes(git_bytes(root,baseline,name+'.import') if baseline else imported.read_bytes())
    catalog=json.loads(git_bytes(root,baseline,'assets/game/visual_resources.json') if baseline else (root/'assets/game/visual_resources.json').read_text())
    paths={side:catalog['textures']['oak_table_'+side]['file'] for side in SIDES}
    for path in paths.values():
        name=path.removeprefix('res://');destination=target/name;destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_bytes(git_bytes(root,baseline,name) if baseline else (root/name).read_bytes())
        Path(str(destination)+'.import').write_bytes(git_bytes(root,baseline,name+'.import') if baseline else Path(str(root/name)+'.import').read_bytes())
    (target/'tools').mkdir(exist_ok=True);shutil.copyfile(Path(__file__).with_name('migration_capture.gd'),target/'tools/migration_capture.gd')
    project='config_version=5\n[application]\nconfig/name="VPIPELINE-009 isolated fixture"\n[display]\nwindow/size/viewport_width=1152\nwindow/size/viewport_height=648\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n'
    (target/'project.godot').write_text(project)
    case={'schema_version':1,'phase':'baseline','catalog_before':catalog,'paths':paths,'copied_files':names}
    (target/CASE).write_text(json.dumps(case,ensure_ascii=False,indent=2)+'\n')
    objects=[]
    for index,side in enumerate(SIDES):
        view=catalog['resources']['prop.rustic_table']['views'][side]
        variant=view['variants']['standard'];rect=variant['source_rect'];bounds=view['logical_size'];scale=min(bounds[0]/rect[2],bounds[1]/rect[3])
        objects.append({'id':index+1,'asset_path':paths[side],'name':'Oak table '+side,'notes':'Preserve this note','position':[192+index*384,530],'size':[rect[2]*scale,rect[3]*scale],'source':rect,'anchor':'bottom','layer':'objects','collision':True,'collision_size':view['footprint_size'],'collision_offset':[0,0],'runtime_id':'table-'+side,'original_position':[192+index*384,530],'hidden':False,'reference':False,'rotation':0.0,'flip_x':False,'flip_y':False})
    draft={'format':'babushkina-ferma-level-draft','version':6,'level_name':'Migration fixture','level_notes':'No player drafts are read','base_location':'migration_fixture','grid':24,'objects':objects}
    (target/'saved-draft.json').write_text(json.dumps(draft,ensure_ascii=False,indent=2)+'\n')
    return case


def phase(target:Path, name:str):
    """Меняет только собственную копию: staging, два отрицательных контроля и точный откат."""
    target=target.resolve()
    if target.is_relative_to(Path(__file__).resolve().parents[1]) or 'config/name="VPIPELINE-009 isolated fixture"' not in (target/'project.godot').read_text():raise ValueError('not an external isolated fixture')
    case=json.loads((target/CASE).read_text())
    if name not in ['baseline','dual','unadapted','retired','rollback']:raise ValueError('unknown fixture phase')
    catalog=json.loads(json.dumps(case['catalog_before']))
    for side in SIDES:
        expected='res://assets/game/interiors/furniture_a/rustic_table_'+side+'.png'
        if case['paths'][side]!=expected:raise ValueError('unexpected fixture source')
        old=target/case['paths'][side].removeprefix('res://')
        new=target/'assets/game/interiors/migration_pilot'/old.name
        original=(target/'originals'/old.name)
        if any(p.is_symlink() for path in [old,new,original] for p in [path,*path.parents] if p.is_relative_to(target)):raise ValueError('fixture symlink is unsafe')
        if not original.exists():
            original.parent.mkdir(exist_ok=True);(original.parent/'.gdignore').touch()
            shutil.copyfile(old,original);shutil.copyfile(str(old)+'.import',str(original)+'.import')
        if name in ['dual','unadapted','retired']:
            new.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,new)
            catalog['textures']['oak_table_'+side]['file']='res://'+new.relative_to(target).as_posix()
        elif new.exists():
            new.unlink();Path(str(new)+'.import').unlink(missing_ok=True)
        if name=='retired':old.unlink(missing_ok=True);Path(str(old)+'.import').unlink(missing_ok=True)
        elif not old.exists():shutil.copyfile(original,old);shutil.copyfile(str(original)+'.import',str(old)+'.import')
    (target/'assets/game/visual_resources.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    case['phase']=name;(target/CASE).write_text(json.dumps(case,ensure_ascii=False,indent=2)+'\n')
    return case
