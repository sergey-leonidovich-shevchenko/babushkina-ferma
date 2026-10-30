#!/usr/bin/env python3
"""Проверяет ограниченную очередь пилота; состояния задач берёт только из общего бэклога."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from tools.assets.migration.migration_inventory import git_bytes

from tools.common.paths import project_root

ROOT = project_root(__file__)
FOLDER='docs/reports/visual-overhaul/vrelease-001'
PROGRAM='docs/epics/visual-overhaul-2026-10/backlog.json'
BASE='12e6e2c7ac30f87af839cdb8cd0e2a4d1e558ee5'
ROLES={'foundation','core','next','deferred','production'}


def load(path):
    """Отклоняет повтор ключа вместо неявной подмены решений очереди."""
    def pairs(items):
        result={}
        for key,value in items:
            if key in result:raise ValueError('duplicate JSON key: '+key)
            result[key]=value
        return result
    return json.loads(path.read_text(),object_pairs_hook=pairs)


def sha(raw):
    """Связывает конкретный источник или конфигурацию с точными байтами."""
    return hashlib.sha256(raw).hexdigest()


def encoded(value):
    """Сохраняет стабильный читаемый JSON без данных браузерной сессии."""
    return (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()


def graph_signature(tasks,keys):
    """Фиксирует состав/зависимости очереди; новые статусы и подтверждения не делают её устаревшей."""
    rows=[[t['id'],t['epic'],t['depends_on']] for t in sorted(tasks,key=lambda t:t['id']) if t['id'] in keys]
    return sha(json.dumps(rows,ensure_ascii=False,separators=(',',':')).encode())


def project(plan,program):
    """Строит полное транзитивное замыкание и топологический порядок без копирования статусов."""
    by={t['id']:t for t in program['tasks']};owner=plan['task'];extra=plan['extra_dependencies']
    selected=set();visiting=set();ordered=[];stages=[]
    def visit(tid,added):
        if tid==owner:return
        if tid not in by:raise ValueError('unknown task: '+tid)
        if tid in visiting:raise ValueError('queue dependency cycle: '+tid)
        if tid in selected:return
        visiting.add(tid)
        for dep in by[tid]['depends_on']+extra.get(tid,[]):visit(dep,added)
        visiting.remove(tid);selected.add(tid);ordered.append(tid);added.append(tid)
    for stage in plan['stages']:
        added=[]
        if owner in stage['roots']:raise ValueError('queue cannot select its own planning task')
        for tid in stage['roots']:visit(tid,added)
        stages.append({'id':stage['id'],'title':stage['title'],'goal':stage['goal'],'taskKeys':['visual--'+i for i in added]})
    return {'schema':1,'id':plan['id'],'title':plan['title'],'description':plan['description'],'guide':'visual-pilot','plan':'visual','source':FOLDER+'/plan.json','planningOnly':True,'implementationAccepted':False,'ownerKey':'visual--'+owner,'graphSignature':graph_signature(program['tasks'],selected),'taskKeys':['visual--'+i for i in ordered],'extraDependencies':{'visual--'+i:['visual--'+d for d in deps] for i,deps in extra.items()},'stages':stages}


def validate(plan,program):
    """Не разрешает расширить пилот до массового арта или принять урезанные полные карточки."""
    errors=[];by={t['id']:t for t in program['tasks']};epics={e['id'] for e in program['epics']}
    try:
        if plan['schema']!=1 or plan['task']!='VRELEASE-001' or plan['planning_only'] is not True or plan['runtime_changed'] is not False:errors.append('invalid planning-only scope')
        if set(plan['epic_roles'])!=epics or any(r['role'] not in ROLES or not r['reason'].strip() for r in plan['epic_roles'].values()):errors.append('all 25 epics need an explicit justified role')
        if plan['completion_policy']!='full-canonical-criteria-only':errors.append('partial completion cannot close canonical tasks')
        geometry=plan['scope'];rect=geometry['world_rect'];size=geometry['world_size']
        if geometry['location']!='overworld' or geometry['grid']!=24 or size!=[2400,1368] or len(rect)!=4 or any(type(v)!=int or v%24 for v in rect) or min(rect[2:])<=0 or min(rect[:2])<0 or rect[0]+rect[2]>size[0] or rect[1]+rect[3]>size[1]:errors.append('invalid canonical grid/world bounds')
        if plan['limits']['max_world_cells']!=1000 or rect[2]*rect[3]>1000*24*24:errors.append('pilot exceeds 1000 world cells')
        bridge=geometry['bridge_rect']
        if bridge!=[816,360,96,192] or not (rect[0]<=bridge[0] and rect[1]<=bridge[1] and bridge[0]+bridge[2]<=rect[0]+rect[2] and bridge[1]+bridge[3]<=rect[1]+rect[3]):errors.append('pilot must contain the full canonical bridge')
        if geometry['views']!=['south','west','east'] or plan['target']['accepted'] is not False or plan['target']['zoom']!=1.2 or plan['target']['framebuffer']!=[1152,648] or plan['target']['world_extent']!=[960,540]:errors.append('invalid or prematurely accepted target projection/views')
        if plan['target']['projection_owner']!='VCAMERA-006':errors.append('camera adoption needs its actual owner')
        if [s['id'] for s in plan['stages']]!=['foundation','static-preview']:errors.append('first queue must end at a static preview')
        if any(len(s['roots'])!=len(set(s['roots'])) for s in plan['stages']):errors.append('duplicate stage roots')
        extra=plan['extra_dependencies']
        if 'VGROUND-004' not in extra.get('VGROUND-005',[]):errors.append('path joins need the orthogonal road silhouette')
        if not set('VPROP-%03d'%i for i in range(2,8))<=set(by['VRELEASE-002']['depends_on']):errors.append('first-location props are missing from static acceptance')
        if not {'VBASE-002','VBASE-005','VCAMERA-002','VCAMERA-003','VCAMERA-006','VPERF-001','VRELEASE-005'}<=set(extra.get('VRELEASE-002',[])):errors.append('static acceptance omits explicit foundation gates')
        queue=project(plan,program);keys={k.split('--',1)[1] for k in queue['taskKeys']}
        if keys & {'VPROP-001','VPROP-008','VPROP-009','VPROP-010'}:errors.append('interior/cave/global props cannot block the first location')
        focus=plan['focus']
        if focus['location']!='overworld' or focus['final_gate']!='VMAP-003' or focus['allow_new_mechanics'] is not False or focus['other_locations_after_final_gate'] is not True:errors.append('first-location focus has drifted')
        if focus['course'][-3:]!=['selective-first-location-assets','VMAP-002','VMAP-003']:errors.append('whole-location acceptance is missing')
        if len(focus['references'])!=3 or any(not (ROOT/p).is_file() for p in focus['references']):errors.append('art reference is missing')
        if {by[k]['epic'] for k in keys}!={e for e,r in plan['epic_roles'].items() if r['role'] in ['foundation','core']}:errors.append('epic roles differ from actual first queue')
        if len(keys)>plan['limits']['max_tasks'] or plan['limits']['max_tasks']>64:errors.append('first queue exceeds its task cap')
        if any(by[k]['epic'] in ['VICON','VACTOR','VPLANT','VBUILD','VMAP'] for k in keys):errors.append('mass production cannot enter the first queue')
        if any(k in keys for k in ['VRELEASE-003','VRELEASE-004','VRELEASE-006','VRELEASE-007','VRELEASE-010']):errors.append('later acceptance is not first-preview scope')
        if set(extra)-keys:errors.append('extra gate for an unselected task')
        for tid in keys:
            if by[tid]['status']=='done' and any(by[d]['status']!='done' for d in by[tid]['depends_on']+extra.get(tid,[])):errors.append('completed task still has an open gate: '+tid)
        if plan['compatibility']['old_slot']['accepted'] or plan['compatibility']['new_pilot_normal_entry']['accepted'] or plan['compatibility']['new_pilot_rollback']['accepted']:errors.append('unimplemented pilot compatibility cannot be accepted')
        if set(plan['follow_up'])!={'motion','performance','first-location','interior','cave','mass-production'}:errors.append('missing explicit hand-off boundary')
        if plan['follow_up']['first-location']['gate']!='VMAP-003':errors.append('whole first location is not the delivery gate')
        for tid in ['VRELEASE-006','VRELEASE-007']+['VMAP-%03d'%i for i in range(4,91,3)]:
            if 'VMAP-003' not in by[tid]['depends_on']:errors.append('another location can start before the first: '+tid)
    except (KeyError,ValueError,TypeError) as exc:errors.append('invalid rollout plan: '+str(exc))
    return errors


def frontier(queue,program):
    """Показывает фактические блокеры и следующую подготовленную карточку без смены её статуса."""
    by={t['id']:t for t in program['tasks']};rows=[]
    for key in queue['taskKeys']:
        tid=key.split('--',1)[1];task=by[tid]
        deps=set(task['depends_on'])|{d.split('--',1)[1] for d in queue['extraDependencies'].get(key,[])}
        blockers=sorted(d for d in deps if by[d]['status']!='done')
        rows.append({'id':tid,'status':task['status'],'blockers':blockers,'eligible':not blockers and task['status']=='ready','preparable':not blockers and task['status']=='backlog'})
    return {'selected':len(rows),'done':sum(r['status']=='done' for r in rows),'next':next((r['id'] for r in rows if r['eligible']),None),'rows':rows}


def reference(root):
    """Сверяет историческую камеру/картинки; схема нового участка не выдаётся за реализованную графику."""
    packet=FOLDER+'/reference.json';record=load(root/packet);errors=[];sources={}
    for name,digest in record['files'].items():
        path=root/name
        if Path(name).is_absolute() or '..' in Path(name).parts or path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):errors.append('unsafe reference path');continue
        raw=path.read_bytes() if path.exists() else b''
        if sha(raw)!=digest:raw=git_bytes(root,record['package_commit'],name)
        if sha(raw)!=digest:errors.append('historical reference differs: '+name)
        sources[name]=raw
    if record['package_commit']!=BASE or record['new_art_accepted'] is not False or record['performance_eligible'] is not False:errors.append('reference scope differs')
    capture=json.loads(sources['docs/reports/visual-overhaul/vpipeline-010/native/game-source/capture.json'])
    scene=capture['scenes']['overworld']['configuration']
    if capture['framebuffer']!=[1152,648] or scene['camera']!=[0,348] or scene['player']!=[432,672] or scene['minutes']!=720 or scene['physics_processing'] is not False or capture['performance_eligible'] is not False:errors.append('reference is not the recorded static camera')
    from PIL import Image,ImageChops
    import io
    prefix='docs/reports/visual-overhaul/vpipeline-010/native/'
    with Image.open(io.BytesIO(sources[prefix+'game-source/overworld.png'])) as a,Image.open(io.BytesIO(sources[prefix+'game-pack/overworld.png'])) as b:
        if a.size!=(1152,648) or b.size!=a.size or ImageChops.difference(a,b).getbbox(alpha_only=False):errors.append('historical same-camera pair differs')
    return errors


def main():
    """Генерирует только очередь без статусов; обычная проверка ничего не меняет в источниках."""
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');parser.add_argument('--next',action='store_true');args=parser.parse_args()
    plan=load(ROOT/FOLDER/'plan.json');program=load(ROOT/PROGRAM);errors=validate(plan,program)
    if errors:raise SystemExit('\n'.join(errors))
    queue=project(plan,program);path=ROOT/FOLDER/'queue.json'
    if args.write:path.write_bytes(encoded(queue))
    elif not path.exists() or load(path)!=queue:errors.append('rollout queue is stale: run pilot_rollout.py --write')
    errors+=reference(ROOT)
    if errors:raise SystemExit('\n'.join(errors))
    actual=frontier(queue,program)
    print(json.dumps(actual if args.next else {k:actual[k] for k in ['selected','done','next']},ensure_ascii=False,indent=2))


if __name__=='__main__':main()
