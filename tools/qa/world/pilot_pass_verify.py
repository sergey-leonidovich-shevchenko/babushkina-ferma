#!/usr/bin/env python3
"""Verify actual scoped production dispatch, exact legacy RGBA and atomic fallbacks."""
if not __package__:
    from tools.common.launch import prepare_imports
    from tools.common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,gzip,hashlib,json,subprocess
from tools.common.git import git_environment
from pathlib import Path
from tools.qa.world.source_inputs import historical_bytes
from PIL import Image
from tools.qa.performance.perf_contract_collect import ROOT,sha,write
from tools.qa.world.render_order import require,validate_draws
from tools.qa.world.pilot_pass_collect import ORIGINAL,EXTRA
REPORT=ROOT/'docs/reports/visual-overhaul/vrender-005'
CASES=['board-front','board-back','board-left','board-right','outside-board','tree-behind','tree-front','bush','bridge-west','bridge-east','manual-pause','opaque-storage','editor','interior','other-map','returned','invalid-source','foreign-world','foreign-layer','missing-resource','material-mismatch','inherited-material']
PROBES=CASES[-6:]
CHANGED={'scripts/systems/village_prop_renderer.gd','scripts/presentation/pilot_object_pass.gd'}


def load(path):
    """Read real archived proof; absence is an error."""
    return json.loads(Path(path).read_text())


def provenance(phase):
    """Bind every input and native byte to the base; permit exactly the selected renderer adapter."""
    folder=REPORT/'native'/phase;data=load(folder/'source.json')
    require(data['complete'] and data['task']=='VRENDER-005' and data['phase']==phase and data['performance_eligible'] is False,'incomplete phase')
    expected=set(ORIGINAL+EXTRA)-({'scripts/presentation/pilot_object_pass.gd'} if phase=='before' else set())
    require(set(data['sources'])==expected,'source coverage differs')
    for name,digest in data['sources'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/'inputs'/name)==digest,'archived source changed')
        if name not in EXTRA and not (phase=='after' and name in CHANGED):
            raw=historical_bytes(ROOT, data['base_commit'], name);require(hashlib.sha256(raw).hexdigest()==digest,'input differs from base: '+name)
    if phase=='after':
        name='scripts/systems/village_prop_renderer.gd';old=subprocess.check_output(['git','show',data['base_commit']+':'+name],cwd=ROOT, env=git_environment()).decode()
        expected=old.replace('const Lamp :=','const PilotPass:=preload("res://scripts/presentation/pilot_object_pass.gd")\nconst Lamp :=').replace('if visible.intersects(Board.destination("board",prop.position+Vector2(0,24)),true):Board.draw(game,"board",prop.position+Vector2(0,24))','if visible.intersects(Board.destination("board",prop.position+Vector2(0,24)),true):PilotPass.draw(game,prop,foreground,Board.draw.bind(game,"board",prop.position+Vector2(0,24)))')
        require((folder/'inputs'/name).read_text()==expected,'renderer changed beyond one selected adapter')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and 'inputs' not in p.parts and p.name!='source.json'};require(actual==set(data['artifacts']),'artifact coverage differs')
    for name,digest in data['artifacts'].items():require(sha(folder/name)==digest,'native artifact changed')
    files=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()];require(subprocess.run(['git','ls-files','--error-unmatch','--',*files],cwd=ROOT,capture_output=True, env=git_environment()).returncode==0,'proof absent from index')
    return data


def metadata(data,width,phase):
    """Require complete physical-window cases, real UI states, unchanged saves and explicit flags."""
    require(data['task']=='VRENDER-005' and data['phase']==phase and not data['errors'] and data['display']!='headless' and data['performance_eligible'] is False,'invalid capture')
    names=[k+'-legacy' for k in CASES]+['default']
    if phase=='after':names += [k+'-command' for k in CASES]
    rows={r['id']:r for r in data['rows']};require(set(rows)==set(names) and len(rows)==len(data['rows']),'missing/duplicated native case')
    for name,row in rows.items():
        case=name.rsplit('-',1)[0] if name!='default' else 'default'
        require(row['window']==row['image']==[width,round(width*9/16)] and row['logical']==[1152,648] and row['visible'] and row['focused'] and row['draws']==4,'invalid window/focus/draws')
        require(row['before']==row['after'],'draw mutated complete save')
        require(row['flag']=='default' if name=='default' else row['flag'] is name.endswith('-command'),'wrong feature flag')
        require(row['pause']==(case=='manual-pause') and row['storage']==(case=='opaque-storage') and row['editor']==(case=='editor'),'missing actual UI state')
        location='cottage_interior' if case=='interior' else ('village_market' if case=='other-map' else 'overworld')
        require(row['location']==location and row['weather']=='clear','wrong world or weather')
        require(row['root_material']==(case=='material-mismatch') and row['inherited_material']==(case=='inherited-material'),'wrong material probe')
    return rows


def routes(values,row,phase):
    """Validate actual replay outcome, exactly one legacy callback and bounded cache per observed frame."""
    require(len(values)==4 and len({v['frame'] for v in values})==4,'missing actual dispatch frames')
    require(len({v['cache_builds'] for v in values})==1,'packet rebuilt inside repeated draw')
    case=row['id'].rsplit('-',1)[0] if row['id']!='default' else 'default';seen=[]
    for value in values:
        require(value['material_equal'] and value['inherit_equal'] and 0<=value['cache_count']<=3,'material leak or unbounded cache')
        trace=value['trace'];require(len(trace)<=8,'unbounded diagnostic trace')
        if phase=='before':require(not trace and value['cache_count']==value['cache_builds']==0,'old renderer contains new pass');continue
        if case in ['opaque-storage','interior','other-map']:require(not trace,'pass leaked into other world/UI')
        for event in trace:
            chosen=event['world']=='overworld' and event['position']==[648,576] and not event['foreground'] and not row['editor']
            require(event['selected']==chosen and event['world']==row['location'] and event['editor']==row['editor'],'false selected scope')
            active=row['flag'] is not False;require(event['flag']==active,'dispatch flag differs')
            expected='legacy' if not chosen or not active else ('fallback' if case in PROBES else 'command')
            require(event['route']==expected and event['fallback_calls']==(0 if expected=='command' else 1),'wrong route or non-atomic fallback')
            if expected=='command':require(not event['foreground'] and event['position']==[648,576] and value['cache_count']>=1,'new pass escaped chosen object/phase')
            seen.append(expected)
    if phase=='after' and (case in ['board-front','board-left','board-right','manual-pause','returned','default'] or case in PROBES):
        expected='legacy' if row['flag'] is False else ('fallback' if case in PROBES else 'command')
        require(seen==[expected]*4,'selected pass was not actually exercised')
    if phase=='after' and case in ['board-back','outside-board','editor']:require(seen==['legacy']*4,'foreground/outside/editor did not retain legacy draw')
    return {kind:seen.count(kind) for kind in ['command','legacy','fallback']}


def equal_png(a,b,width):
    """Compare every RGBA byte, including alpha and hidden RGB; never use a visual tolerance."""
    with Image.open(a) as x,Image.open(b) as y:
        require(x.size==y.size==(width,round(width*9/16)),'PNG size differs')
        require(x.convert('RGBA').tobytes()==y.convert('RGBA').tobytes(),'legacy/new pixels differ')


def verify():
    """Admit only one real first-map pass, not global graphics, sorting, shaders or performance."""
    src={p:provenance(p) for p in ['before','after']};require(src['before']['base_commit']==src['after']['base_commit'],'phase bases differ')
    for name,digest in src['before']['sources'].items():
        if name not in CHANGED:require(src['after']['sources'].get(name)==digest,'unrelated input changed: '+name)
    result={'task':'VRENDER-005','base_commit':src['before']['base_commit'],'production_pass_enabled':True,'default_enabled':True,'scope':[240,312,960,576],'selected_object':'board:648:576','layer':'behind_actors','performance_eligible':False,'full_map_accepted':False,'windows':{}}
    for width in [1152,1280]:
        meta={p:metadata(load(REPORT/'native'/p/str(width)/'capture.json'),width,p) for p in src};callbacks=0;totals={k:0 for k in ['command','legacy','fallback']}
        for phase in src:
            folder=REPORT/'native'/phase/str(width);require(load(folder/'environment.json')['exit_code']==0 and not any(e in (folder/'engine.txt').read_text() for e in ['ERROR:','SCRIPT ERROR','Parse Error']),'native engine error')
            for name,row in meta[phase].items():
                draws=json.loads(gzip.decompress((folder/(name+'-draws.json.gz')).read_bytes()));validate_draws(draws);require(len(draws)==4 and draws[0]['before']==row['before'],'draw not snapshot-bound');callbacks+=4
                counts=routes(json.loads(gzip.decompress((folder/(name+'-routes.json.gz')).read_bytes())),row,phase)
                for k,v in counts.items():totals[k]+=v
        pairs=0
        for name,a in meta['before'].items():
            b=meta['after'][name]
            for key in ['before','player','camera','location','editor','pause','storage','root_material','inherited_material','minutes','weather']:require(a[key]==b[key],'before/after configuration differs: '+key)
            equal_png(REPORT/'native/before'/str(width)/(name+'.png'),REPORT/'native/after'/str(width)/(name+'.png'),width);pairs+=1
        for case in CASES:
            a,b=meta['after'][case+'-legacy'],meta['after'][case+'-command']
            for key in ['before','player','camera','location','editor','pause','storage','root_material','inherited_material','minutes','weather']:require(a[key]==b[key],'flag changed paired configuration: '+key)
            equal_png(REPORT/'native/after'/str(width)/(case+'-legacy.png'),REPORT/'native/after'/str(width)/(case+'-command.png'),width);pairs+=1
        require(totals['command']>0 and totals['fallback']==24,'selected replay or all six real refusals missing')
        result['windows'][str(width)]={'before_png':23,'after_png':45,'draw_callbacks':callbacks,'rgba_pairs':pairs,'all_rgba_equal':True,'actual_routes':totals,'foreground_other_world_hud_retained':True,'cache_max':3,'default_on_exercised':True}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');a=p.parse_args();result=verify()
    if a.write:write(REPORT/'summary.json',result)
    print(json.dumps(result,indent=2))
