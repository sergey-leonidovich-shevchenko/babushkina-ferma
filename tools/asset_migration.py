#!/usr/bin/env python3
"""VPIPELINE-009: проверяемый план перехода; команды массового переименования/удаления нет."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
from migration_inventory import build, historical_errors, sha, git_bytes, git_read
from visual_resources import parse

ROOT=Path(__file__).resolve().parents[1]
REPORT='docs/reports/visual-overhaul/vpipeline-009'
BASE='1621d49502cd244c1036168f9d235561b708b33a'
STEP_IDS=['snapshot','stage','register','rebuild','compatibility','wiki','compare','rollback','retire']
RETIRE_GATES=['VEDITOR-001','VEDITOR-002','VEDITOR-004','VEDITOR-008','VCOMPAT-002','VCOMPAT-010','VPIPELINE-010']


def read(path):
    """Читает декларацию без скрытой потери повторяющихся ключей."""
    return parse(Path(path).read_text())


def default_plan(inventory, manifest, decisions):
    """Связывает все семейства по ID, сохраняя существующих художественных владельцев и блокеры редактора."""
    decisions={row['id']:row for row in decisions['families']};families=[];owners={}
    stages={'archive':[1],'static':[2,3,4,24],'water':[5,7],'plants':[6,8,11,13],'actors':[18,19,20,21,23],'effects':[16]}
    for row in sorted(manifest['entries'],key=lambda row:row['id']):
        decision=decisions[row['id']];number=int(row['id'].split('-')[1]);stage=next((key for key,ids in stages.items() if number in ids),'props')
        paths=[asset['path'] for asset in row['assets']]
        families.append({'id':row['id'],'title':row['family'],'stage':stage,'decision':decision['decision'],'owner_epics':decision['owner_epics'],'assets':paths,'status':'requires_owner_task','stable_id_rule':'Preserve content/resource IDs; a file path is not a stable ID','required_steps':STEP_IDS.copy()})
        for path in paths:
            owners.setdefault(path,{'primary_epic':decision['owner_epics'][0],'families':[]})['families'].append(row['id'])
    return {'schema_version':1,'task':'VPIPELINE-009','base_commit':inventory['base_commit'],'kind':'migration-plan-with-isolated-rename-only-proof','production_operations':[],'deletion_authorized':False,'inventory_sha256':'','steps':[{'id':id,'after':[] if index==0 else [STEP_IDS[index-1]]} for index,id in enumerate(STEP_IDS)],'families':families,'file_owners':owners,'retirement_gates':RETIRE_GATES,'pilot':{'resource_id':'prop.rustic_table','sides':['south','west','east'],'production_adapter_implemented':False,'policy':'Keep old PNG paths and their UIDs; a fixture-only path adapter preserves F12 profiles. New art/geometry needs separate migration acceptance.'}}


def validate_plan(plan, inventory, manifest, decisions, task_ids):
    """Отклоняет потерю семейства, ложное разрешение удаления, конфликт владельцев и пропущенный порядок перехода."""
    errors=[];records=plan.get('families',[]);expected={row['id']:row for row in manifest['entries']};decisions={row['id']:row for row in decisions['families']}
    if plan.get('schema_version')!=1 or plan.get('task')!='VPIPELINE-009' or plan.get('deletion_authorized') is not False or plan.get('production_operations')!=[] or plan.get('kind')!='migration-plan-with-isolated-rename-only-proof':errors.append('invalid planning-only migration scope')
    if plan.get('base_commit')!=inventory.get('base_commit'):errors.append('migration base differs')
    if len(records)!=len(expected) or {row.get('id') for row in records}!=set(expected):errors.append('migration family coverage differs')
    for row in records:
        id=row.get('id')
        if id not in expected:continue
        if row.get('assets')!=[asset['path'] for asset in expected[id]['assets']]:errors.append('migration asset coverage differs: '+id)
        if row.get('owner_epics')!=decisions[id]['owner_epics'] or row.get('decision')!=decisions[id]['decision']:errors.append('migration owner/decision differs: '+id)
        if row.get('status')!='requires_owner_task' or row.get('required_steps')!=STEP_IDS or not row.get('stable_id_rule'):errors.append('migration family prematurely accepted: '+id)
        if any(path not in inventory['files'] for path in row.get('assets',[])):errors.append('migration path absent from snapshot: '+id)
    declared={path for row in records for path in row.get('assets',[])}
    if set(plan.get('file_owners',{}))!=declared:errors.append('migration file ownership incomplete')
    for path,owner in plan.get('file_owners',{}).items():
        families=[row for row in records if path in row['assets']]
        if not families or owner.get('families')!=[row['id'] for row in families] or owner.get('primary_epic') not in {epic for row in families for epic in row['owner_epics']}:errors.append('migration has ambiguous file owner: '+path)
    steps=plan.get('steps',[])
    if [row.get('id') for row in steps]!=STEP_IDS or any(row.get('after')!=([] if index==0 else [STEP_IDS[index-1]]) for index,row in enumerate(steps)):errors.append('migration dependency order differs')
    if plan.get('retirement_gates')!=RETIRE_GATES or set(RETIRE_GATES)-set(task_ids):errors.append('migration retirement gates missing')
    pilot=plan.get('pilot',{})
    if pilot.get('resource_id')!='prop.rustic_table' or pilot.get('sides')!=['south','west','east'] or pilot.get('production_adapter_implemented') is not False:errors.append('fixture adapter presented as production implementation')
    return errors


def switch_errors(before, after, old_paths, available, adapter=False, allow_retire=False):
    """Проверяет rename-only в копии: ID и геометрия неизменны, прежние пути сохранены, адаптер обязателен."""
    errors=[]
    if before.get('resources')!=after.get('resources'):errors.append('stable IDs/views/geometry changed')
    if set(before.get('textures',{}))!=set(after.get('textures',{})):errors.append('texture IDs changed')
    changed=False
    for id,old in before.get('textures',{}).items():
        new=after.get('textures',{}).get(id,{})
        if {k:v for k,v in old.items() if k!='file'}!={k:v for k,v in new.items() if k!='file'}:errors.append('rename-only texture contract changed: '+id)
        path=new.get('file','');changed|=path!=old.get('file')
        if not isinstance(path,str) or not path.startswith('res://assets/game/') or '..' in Path(path.removeprefix('res://')).parts:errors.append('unsafe migration destination')
        if path not in available:errors.append('new resource missing: '+path)
    if any(path not in available for path in old_paths):errors.append('saved F12 path retired without production compatibility')
    if changed and not adapter:errors.append('old F12 metadata/sampling adapter missing')
    if allow_retire:errors.append('retirement requires separate owner acceptance, external draft support and package proof')
    return errors


def verify(root:Path):
    """Проверяет исторический план и реальный нативный пример, не замораживая будущие игровые рисунки."""
    report=root/REPORT;inventory=read(report/'inventory.json');plan=read(report/'plan.json');base=inventory['base_commit']
    errors=historical_errors(root,inventory)
    if errors:return errors
    if base!=BASE:errors.append('unexpected migration baseline commit')
    if sha((report/'inventory.json').read_bytes())!=plan.get('inventory_sha256'):errors.append('migration inventory signature differs')
    manifest=json.loads(git_bytes(root,base,'assets/game/world_sprite_manifest.json'))
    decisions=json.loads(git_bytes(root,base,'docs/reports/visual-overhaul/vart-009/decisions.json'))
    tasks=read(root/'docs/epics/visual-overhaul-2026-10/backlog.json')['tasks']
    errors.extend(validate_plan(plan,inventory,manifest,decisions,{t['id'] for t in tasks}))
    from migration_proof import validate
    errors.extend(validate(root))
    proof=read(report/'proof.json')
    tracked=set(git_read(root,'ls-files','-z',text=True).split('\0'))
    for name in set(proof['files'])|{'proof.json'}:
        if REPORT+'/'+name not in tracked:errors.append('migration proof input missing from Git index: '+name)
    return errors


def main():
    """Создаёт одноразовый снимок либо проверяет уже сохранённый план без команд применения к игре."""
    parser=argparse.ArgumentParser();parser.add_argument('--record',action='store_true');args=parser.parse_args()
    if args.record:
        base=subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
        if base!=BASE or subprocess.check_output(['git','diff',base,'--name-only','--','scripts','assets/game','wiki/scripts','level_designs'],text=True).strip():raise SystemExit('initial migration snapshot requires unchanged VPIPELINE-008 base')
        if subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','scripts','assets/game','wiki/scripts','level_designs'],text=True).strip():raise SystemExit('untracked runtime cannot enter migration snapshot')
        report=ROOT/REPORT;report.mkdir(parents=True,exist_ok=True)
        inventory=build(ROOT,base)
        with (report/'inventory.json').open('x') as file:json.dump(inventory,file,ensure_ascii=False,separators=(',',':'));file.write('\n')
        plan=default_plan(inventory,read(ROOT/'assets/game/world_sprite_manifest.json'),read(ROOT/'docs/reports/visual-overhaul/vart-009/decisions.json'))
        plan['inventory_sha256']=sha((report/'inventory.json').read_bytes())
        with (report/'plan.json').open('x') as file:json.dump(plan,file,ensure_ascii=False,indent=2);file.write('\n')
        print('MIGRATION SNAPSHOT:',len(inventory['files']),'runtime resources;',len(inventory['sources']),'reader sources; no production operations')
    else:
        errors=verify(ROOT)
        if errors:raise SystemExit('\n'.join(errors))
        print('ASSET MIGRATION: 29 family plans, historical consumer graph, isolated rename/rollback and two negative controls valid; production unchanged')


if __name__=='__main__':main()
