#!/usr/bin/env python3
"""Bind acceptance to the canonical queue at its real Git base; this is an audit, not a status registry."""
import argparse,hashlib,json,subprocess,re
from common.git import git_environment
from pathlib import Path

# Сохраняет прямой CLI/cwd старого QA-входа до его отдельного переноса в REFACTOR-03.
from common.launch import prepare_imports
from common.paths import project_root

prepare_imports(project_root(__file__))
from tools.qa.world.source_inputs import historical_bytes, historical_kind

from tools.planning.pilot_rollout import project,validate,load,ROOT
REPORT=ROOT/'docs/reports/visual-overhaul/vrelease-002'

def git_json(base,path):
    """Read an immutable repository input rather than a parallel readiness ledger."""
    raw=subprocess.check_output(['git','show',base+':'+path],cwd=ROOT, env=git_environment())
    return json.loads(raw)

def audit(base):
    """Require all51 preceding cards, their actual evidence, limits and unchanged implementation sources."""
    program=git_json(base,'docs/epics/visual-overhaul-2026-10/backlog.json');plan=git_json(base,'docs/reports/visual-overhaul/vrelease-001/plan.json')
    assert not validate(plan,program)
    queue=project(plan,program);by={t['id']:t for t in program['tasks']};keys=[k.removeprefix('visual--') for k in queue['taskKeys'] if k!='visual--VRELEASE-002'];assert len(keys)==51
    rows=[]
    for key in keys:
        task=by[key];assert task['status']=='done' and task['evidence'],key
        paths=[]
        for entry in task['evidence']:
            links=re.findall(r'\]\(([^)#]+)(?:#[^)]*)?\)',entry)
            for target in links:
                if target.startswith(('http:','https:','#')):continue
                paths.append((ROOT/'docs/epics/visual-overhaul-2026-10/epics'/target).resolve())
            if entry.startswith(('docs/','tools/','wiki/','assets/')) and len(entry)<240 and ' ' not in entry:paths.append(ROOT/entry)
        if not paths:
            paths=[ROOT/'docs/reports/visual-overhaul'/key.lower()/'README.md']
        evidence=[]
        for p in paths:
            name=str(p.relative_to(ROOT));kind=historical_kind(ROOT, base, name).strip()
            assert kind in ['blob','tree'],name
            raw=historical_bytes(ROOT, base, name, allow_tree=True)
            evidence.append({'file':name,'git_type':kind,'sha256':hashlib.sha256(raw).hexdigest()})
        assert evidence,key
        rows.append({'id':key,'status_at_base':'done','evidence':evidence,'canonical_claims':task['evidence']})
    modules=load(ROOT/'docs/reports/visual-overhaul/vart-008/modules.json');assert modules['status']=='approved' and modules['selection']=='both' and modules['runtime_integration'] is False
    assert plan['limits']['max_world_cells']==1000 and plan['scope']['world_rect']==[240,312,960,576]
    return {'task':'VRELEASE-002','base_commit':base,'canonical_queue':'docs/reports/visual-overhaul/vrelease-001/queue.json','predecessors':rows,'predecessor_count':51,'grid':24,'scope_cells':960,'max_cells':1000,'projection':{'field':[960,540],'framebuffer':[1152,648],'zoom':1.2},'accepted_facades':['a','b'],'standalone_study':True,'ordinary_game_is_separate_control':True,'whole_overworld_accepted':False,'performance_eligible':False}

def verify():
    """Reject stale/missing evidence and fabricated predecessor completion."""
    data=load(REPORT/'dependency-audit.json');assert data==audit(data['base_commit']);return data

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');a=p.parse_args()
    if a.write:
        data=audit(subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True, env=git_environment()).strip());(REPORT/'dependency-audit.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('STATIC PILOT AUDIT:',verify()['predecessor_count'],'canonical predecessors and exact evidence; full map/FPS remain open')
