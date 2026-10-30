#!/usr/bin/env python3
"""Admit a bounded static modular study and separate real-game compatibility controls."""
if not __package__:
    from tools.common.launch import prepare_imports
    from tools.common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,gzip,hashlib,json,math,subprocess
from pathlib import Path
from tools.qa.world.source_inputs import historical_result
from PIL import Image,ImageChops,ImageDraw
from tools.qa.performance.perf_contract_collect import ROOT,sha,write
from tools.qa.world.render_order import require,validate_draws
from tools.qa.world.pilot_static_collect import ORIGINAL,EXTRA
from tools.qa.world.pilot_static_audit import verify as audit
from tools.common.git import git_environment
from tools.qa.art.current_paths import recorded_paths
REPORT=ROOT/'docs/reports/visual-overhaul/vrelease-002'
STUDIES=['study-'+s+'-'+v+'-'+m for s in ['legacy','painted'] for v in ['a','b'] for m in ['front','back','bridge','grid']]
CONTROLS=['ordinary','rollback','normal-home-enter','normal-home-exit','old-slot-interior','old-slot-overworld']

def load(path):
    """Read genuine proof without replacing missing cases."""
    return json.loads(Path(path).read_text())

def metadata(data,width):
    """Require real visible windows, complete snapshots, study separation and actual old-slot data."""
    require(data['task']=='VRELEASE-002' and data['phase']=='static' and not data['errors'] and data['display']!='headless' and data['performance_eligible'] is False,'invalid native run')
    rows={r['id']:r for r in data['rows']};require(set(rows)==set(STUDIES+CONTROLS) and len(rows)==len(data['rows']),'missing or duplicated native case')
    for name,r in rows.items():
        require(r['window']==r['image']==[width,round(width*9/16)] and r['logical']==[1152,648] and r['visible'] and r['draws']==4,'invalid physical window/visibility/draws')
        require(type(r['focused']) is bool and r['focus_required'] is False,'missing static focus boundary')
        require(r['before']==r['after'],'draw mutated full save')
        require(r['study']==(name in STUDIES) and not r['normal_effects'] and r['weather']==('rain' if name.startswith('old-slot-') else 'clear'),'study confused with ordinary game')
    for name in STUDIES+['rollback']:require(rows[name]['before']==rows['ordinary']['before'] and rows[name]['player']==rows['ordinary']['player'] and rows[name]['camera']==rows['ordinary']['camera'],'study changed actual game or camera')
    for name,location in [('normal-home-enter','cottage_interior'),('normal-home-exit','overworld'),('old-slot-interior','cottage_interior'),('old-slot-overworld','overworld')]:require(rows[name]['location']==location,'real entry/old-slot control absent')
    for name in ['old-slot-interior','old-slot-overworld']:
        r=rows[name]['before'];require(r['coins']==41 and r['day']==3 and r['counts']['wood']==14 and r['counts']['apple']==2,'old-slot values changed')
    return rows

def provenance():
    """Bind every rendering input to Git and every native artifact to exact bytes and the index."""
    folder=REPORT/'native/static';data=load(folder/'source.json');require(data['complete'] and data['task']=='VRELEASE-002' and data['performance_eligible'] is False,'incomplete source run')
    require(set(data['sources'])==set(ORIGINAL+EXTRA),'source coverage changed')
    paths=recorded_paths(ORIGINAL+EXTRA,data.get('source_paths',{}))
    for name,digest in data['sources'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/'inputs'/name)==digest,'archived source changed')
        if name not in EXTRA:
            old=historical_result(ROOT, data['base_commit'], paths.get(name,name))
            require(old.returncode==0 and hashlib.sha256(old.stdout).hexdigest()==digest,'input not from Git base: '+name)
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and 'inputs' not in p.parts and p.name!='source.json'};require(actual==set(data['artifacts']),'artifact coverage changed')
    for name,digest in data['artifacts'].items():require(sha(folder/name)==digest,'native artifact changed')
    files=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()];require(subprocess.run(['git','ls-files','--error-unmatch','--',*files],cwd=ROOT,capture_output=True, env=git_environment()).returncode==0,'proof missing from index')
    return data

def pixels(before,after,width):
    """Compare study pairs only within explicit prop bounds, preserving the common composition."""
    with Image.open(before) as a,Image.open(after) as b:
        a,b=a.convert('RGBA'),b.convert('RGBA');require(a.size==b.size==(width,round(width*9/16)),'readback size differs')
        d=ImageChops.difference(a,b);changed=ImageChops.lighter(ImageChops.lighter(d.getchannel('R'),d.getchannel('G')),ImageChops.lighter(d.getchannel('B'),d.getchannel('A')));count=sum(v!=0 for v in changed.getdata())
        mask=Image.new('L',a.size);draw=ImageDraw.Draw(mask);k=width/960
        rectangles=[[396,228,516,326],[610,174,734,328],[60,300,180,464],[312,246,408,400],[12,180,132,304],[252,444,516,516],[384,336,588,520],[864,180,960,304]]
        for x0,y0,x1,y1 in rectangles:draw.rectangle((math.floor(x0*k),math.floor(y0*k),math.ceil(x1*k),math.ceil(y1*k)),fill=255)
        require(count>0,'study replacement is a no-op');require(ImageChops.subtract(changed,mask).getbbox() is None,'outside study props changed')
        return count

def verify():
    """Accept the static result without claiming full overworld, live rollout, native input or FPS."""
    dep=audit();source=provenance();require(source['base_commit']==dep['base_commit'],'audit/render bases differ')
    result={'task':'VRELEASE-002','base_commit':source['base_commit'],'performance_eligible':False,'focus_required':False,'standalone_study':True,'full_map_accepted':False,'live_pilot_accepted':False,'predecessors':51,'scope_cells':960,'max_cells':1000,'windows':{}}
    for width in [1152,1280]:
        folder=REPORT/'native/static'/str(width);data=load(folder/'capture.json');rows=metadata(data,width);callbacks=0
        require(load(folder/'environment.json')['exit_code']==0 and not any(e in (folder/'engine.txt').read_text() for e in ['ERROR:','SCRIPT ERROR','Parse Error']),'native engine failure')
        for name,r in rows.items():
            draws=json.loads(gzip.decompress((folder/(name+'-draws.json.gz')).read_bytes()));validate_draws(draws);callbacks+=len(draws);require(draws[0]['before']==r['before'],'root callbacks not snapshot-bound')
            if name in STUDIES:
                scenes=json.loads(gzip.decompress((folder/(name+'-gallery-draws.json.gz')).read_bytes()));require(len(scenes)==4 and len({d['frame'] for d in scenes})==4,'missing actual study callbacks');callbacks+=4
                for d in scenes:
                    require(d['before']==d['after']==r['before'] and d['game_material'] and d['viewport']==[1152,648] and d['field']==[960,540] and len(d['actual_zoom'])==2 and all(math.isclose(z,1.2,rel_tol=1e-6) for z in d['actual_zoom']),'study altered game/material/projection')
                    require(d['style']==name.split('-')[1] and d['variant']==name.split('-')[2] and d['mode']==name.split('-')[3] and d['footprint_cells']==960,'wrong study configuration')
        changes={}
        for v in ['a','b']:
            for mode in ['front','back','bridge','grid']:changes[v+'-'+mode]=pixels(folder/('study-legacy-'+v+'-'+mode+'.png'),folder/('study-painted-'+v+'-'+mode+'.png'),width)
        require((folder/'ordinary.png').read_bytes()==(folder/'rollback.png').read_bytes(),'rollback is not pixel-exact ordinary game')
        result['windows'][str(width)]={'png':22,'draw_callbacks':callbacks,'study_pairs':8,'changed_pixels':changes,'outside_props_equal':True,'ordinary_rollback_equal':True,'old_slot_loaded':True,'home_enter_exit':True,'visible_frames':22,'focused_frames':sum(r['focused'] for r in rows.values())}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');a=p.parse_args();result=verify()
    if a.write:write(REPORT/'summary.json',result)
    print(json.dumps(result,indent=2))
