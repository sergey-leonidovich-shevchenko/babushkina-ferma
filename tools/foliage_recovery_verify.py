#!/usr/bin/env python3
"""Recompute the complete recovery trace and bind native GPU/pixel proof to immutable sources."""
import argparse,hashlib,json,math,subprocess
from pathlib import Path
from PIL import Image,ImageChops
from foliage_contact_verify import ROOT,blob,sha,require,artifacts,locked_bands,image,reaction,close
REPORT=ROOT/'docs/reports/visual-overhaul/vfoliage-006'
RUNTIME=['scripts/presentation/foliage_wind.gd','scripts/presentation/foliage_recovery.gd']
QA=['tools/foliage_contact_capture.gd','tools/foliage_recovery_capture.gd','tools/foliage_recovery_collect.py','tools/foliage_wind_capture.gd','tools/visual_camera_points.gd','tools/render_order_game.gd']
TICKS=[0,4,8,12,16,20,24,30,38,48]

def case_ids():
    """Require four complete approaches and all exceptional transitions."""
    return {f'sweep-{side}-{tick:02d}' for side in range(4) for tick in TICKS}|{'stop','stop-repeat','pause-0','pause-1','pause-2','resume','wall','offscreen','return','low','reduced','reference','interior','jump','invalid-frame','rollback','malformed','teleport-forest','teleport-overworld'}

def numerical(data):
    """Integrate independently in Python using actual physical clocks, foot positions and resolved velocities."""
    current=[[0.,0.] for _ in range(8)];previous_time=-1;previous_player=None;maximum=0
    require(len(data['audit'])>300,'complete intermediate physical trace')
    for step in data['audit']:
        seconds=step['seconds'];require(math.isfinite(seconds) and seconds>=0,'finite simulation clock')
        if step['reset']:current=[[0.,0.] for _ in range(8)];previous_time=-1;previous_player=None
        gain=1.;motion=step['motion']
        if motion and motion['world']==step['world'] and motion['player']==step['player'] and motion['seconds']==seconds:
            dt=motion['delta'];require(math.isfinite(dt) and dt>0,'actual motion delta')
            velocity=[(a-b)/dt for a,b in zip(motion['player'],motion['origin'])]
            require(close(velocity,motion['velocity'],.03),'resolved velocity')
            gain+=.9*min(math.hypot(*velocity)/280,1)**2
        raw=[[x*gain for x in reaction(step['presented'],root)] if step['valid'] else [0.,0.] for root in data['anchors']]
        require(len(step['raw'])==8 and all(close(a,b,.00001) for a,b in zip(raw,step['raw'])),'independent spatial target')
        flag=step['flag'];disabled=type(flag) is not bool or not flag
        elapsed=max(0,seconds-previous_time) if previous_time>=0 else 0
        jump=previous_player is not None and math.dist(step['player'],previous_player)>max(8,720*elapsed)
        if not step['valid'] or disabled or seconds<previous_time or jump:
            current=[[0.,0.] for _ in range(8)];previous_time=-1;previous_player=None;elapsed=0
        if step['valid'] and not disabled:
            for i in range(8):
                if i not in step['visible']:current[i]=[0.,0.];continue
                tau=.18 if math.hypot(*raw[i])<math.hypot(*current[i]) else .08
                if elapsed>0:current[i]=[target+(old-target)*math.exp(-elapsed/tau) for old,target in zip(current[i],raw[i])]
                if raw[i]==[0.,0.] and math.hypot(*current[i])<=.005:current[i]=[0.,0.]
            previous_time=seconds;previous_player=step['player']
        expected=raw if step['valid'] and disabled else current
        require(len(step['actual'])==len(step['expected'])==8 and all(close(a,b,.000015) and close(a,c,.000015) for a,b,c in zip(expected,step['actual'],step['expected'])),'independent analytic recovery')
        active=sum(v!=[0.,0.] for v in current);require(step['active']==active<=64,'bounded active set and real removal')
        maximum=max(maximum,active)
        require(all(math.hypot(*v)<4.36 for v in step['actual']),'bounded final displacement')
    return maximum

def metadata(data,width,shader_sha):
    """Check real callbacks/uniforms, complete saves, projection, ownership and exceptional cleanup."""
    require(data['task']=='VFOLIAGE-006' and data['display']!='headless' and data['profile'].startswith('Codex-VFOLIAGE-006-') and not data['errors'],'native identity')
    require(data['seed']==20261015 and data['performance_eligible'] is False and data['hardware_input_accepted'] is False,'honest scope')
    rows=data['rows'];ids={r['id']:r for r in rows};require(len(rows)==len(ids)==59 and set(ids)==case_ids(),'complete unique native coverage')
    origins=[(552,384),(744,456),(1032,768),(1440,984),(1800,840),(1968,960),(1944,648),(2160,888)]
    require(len(data['anchors'])==8,'eight original plants')
    for i,(x,y) in enumerate(origins):
        px,py=(148,300) if i<6 else (178,325)
        require(close(data['anchors'][i],[x-36+px*72/362,y-48+py*72/362]),'original fixed root')
    numerical(data);materials=None
    for row in rows:
        sample=data['audit'][row['sample']]
        require(row['world']==sample['world'] and row['seconds']==sample['seconds'] and row['player']==sample['player'],'captured physical sample')
        require(row['visible'] and row['window']==[width,width*9//16] and row['logical']==[1152,648] and row['target']==[768,384] and isinstance(row['focused'],bool),'actual native window')
        require(row['camera']==([-8000,-8000] if row['mode']=='offscreen' else [1464,378]),'same fixed camera')
        zoom=1.2 if row['world']=='overworld' else 1
        require(close(row['background']['scale'],[zoom,zoom]) and close(row['background']['position'],[-v*zoom for v in row['camera']],.001),'background shares fixed camera')
        digest=hashlib.sha256(data['snapshots'][row['snapshot']].encode()).hexdigest();require(digest==row['snapshot_sha'],'complete snapshot')
        variants=row['variants'];require(len(variants)==(1 if row['mode']=='pause' else 2) and variants[0]['active'] is True,'explicit on/off comparison')
        for variant in variants:
            require(variant['after_sha']==digest and len(variant['draws'])==2 and len({d['frame'] for d in variant['draws']})==2,'actual game callbacks')
            for draw in variant['draws']:require(draw['equal'] and draw['geometry_equal'] and draw['before_sha']==draw['after_sha']==digest,'draw preserves complete gameplay')
            expected_flag=sample['flag'] if variant['active'] else False
            require(type(variant['flag']) is type(expected_flag) and variant['flag']==expected_flag,'actual technical flag')
            stats=variant['stats'];require(stats['owners']==1 and stats['groups']==2 and stats['builds']==1 and stats['scale']==2 and stats['recovery_limit']==64,'bounded reused resources')
            require(stats['recovery_active']==(sample['active'] if variant['active'] else 0),'actual filtered entries')
            require(stats['active']==len(sample['visible']),'actual visible subset')
            callbacks=variant['callbacks'];require(len(callbacks)==4,'two actual group callbacks per frame')
            current={c['name']:c['material_rid'] for c in callbacks}
            if materials is None:materials=current
            require(current==materials and set(current)=={'grass','reeds'},'stable material ownership')
            for callback in callbacks:
                name=callback['name'];require(callback['shader_sha']==shader_sha and callback['parent']=='WindAtlas','actual source material')
                require(sum(c['name']==name for c in callbacks)==2 and callback['slots']==(list(range(6)) if name=='reeds' else [6,7]),'actual GPU indices')
                require(callback['instances']==(6 if name=='reeds' else 2) and callback['seconds']==stats['seconds'],'actual instances and clock')
                target=(sample['actual'] if variant['active'] else sample['raw'])+[[0.,0.]]*56
                require(len(callback['contacts'])==64 and all(all(math.isfinite(v) for v in p) for p in callback['contacts']),'finite bounded shader array')
                if stats['active']:require(all(close(a,b,.000015) for a,b in zip(callback['contacts'],target)),'actual filtered GPU array')
    for side in range(4):
        first=data['audit'][ids[f'sweep-{side}-00']['sample']];last=data['audit'][ids[f'sweep-{side}-48']['sample']]
        require(first['active']==last['active']==0 and all(v==[0,0] for v in last['actual']),'every approach settles to baseline')
        root=data['anchors'][6]
        require(math.dist(first['player'],last['player'])>84 and math.dist(last['player'],root)>36 and sum((a-c)*(b-c) for a,b,c in zip(first['player'],last['player'],root))<0,'actual passage crosses the root and exits the contact radius')
        require(any(data['audit'][ids[f'sweep-{side}-{tick:02d}']['sample']]['active']>0 for tick in TICKS),'positive contact on every side')
    stopped=data['audit'][ids['stop']['sample']]
    for name in ['pause-0','pause-1','pause-2']:
        sample=data['audit'][ids[name]['sample']];require(sample['seconds']==stopped['seconds'] and sample['actual']==stopped['actual'],'pause freezes filtered state')
    for name in ['offscreen','low','reduced','reference','interior','jump','invalid-frame','rollback','malformed','teleport-forest','teleport-overworld']:
        require(data['audit'][ids[name]['sample']]['active']==0,'exceptional cleanup')
    for target in ['forest','overworld']:require(ids['teleport-'+target]['teleport_success'] and ids['teleport-'+target]['world']==target,'real QA transfer')
    wall=data['audit'][ids['wall']['sample']];require(math.hypot(*wall['motion']['velocity'])==0 and wall['active']>0,'real wall preserves only stationary soft contact')
    return ids

def pair(on,reference,off,influence):
    """Compare every RGBA channel and fixed lower strip, with positive and zero controls."""
    require(on.size==reference.size==off.size==(768,384),'target dimensions')
    maximum=max(hi for _,hi in ImageChops.difference(on,reference).getextrema());require(maximum<=1,'GPU/CPU geometry')
    locked_bands(on,off);change=max(hi for _,hi in ImageChops.difference(on,off).getextrema())
    if influence<1e-7:require(on.tobytes()==off.tobytes(),'zero recovery pixel control')
    elif influence>.15:require(change>5,'recovery must visibly affect GPU')
    return maximum

def pixels(folder,ids,data):
    """Validate native targets and every losslessly decoded motion sample."""
    baseline=image(folder/'sweep-0-00/on.png');maximum=positive=zero=0
    for row in ids.values():
        on=image(folder/row['id']/'on.png');locked_bands(on,baseline)
        if row['variants'][0]['stats']['active']:
            sample=data['audit'][row['sample']];reference=image(folder/row['id']/'reference.png')
            if len(row['variants'])==2:
                off=image(folder/row['id']/'off.png');influence=max(math.dist(a,b) for a,b in zip(sample['actual'],sample['raw']))
                maximum=max(maximum,pair(on,reference,off,influence));positive+=int(influence>.15);zero+=int(influence<1e-7)
            else:require(max(hi for _,hi in ImageChops.difference(on,reference).getextrema())<=1,'paused GPU/CPU geometry')
    for side in [0,2]:
        movie=Image.open(folder/f'motion-{side}.png');proof=json.loads((folder/f'motion-{side}.json').read_text())
        require(movie.n_frames==len(proof['frames'])==len(TICKS),'complete motion')
        for i,frame in enumerate(proof['frames']):
            movie.seek(i);rgba=movie.convert('RGBA');require(frame['case']==f'sweep-{side}-{TICKS[i]:02d}' and hashlib.sha256(rgba.tobytes()).hexdigest()==frame['rgba_sha'],'lossless motion pixels')
            duration=(TICKS[i+1]-TICKS[i])*1000/30 if i+1<len(TICKS) else 350
            require(abs(movie.info['duration']-duration)<=.5 and abs(frame['duration_ms']-duration)<.001,'motion follows simulation sample time within integer millisecond encoding')
            if i in [0,3,9]:require(rgba.tobytes()==image(folder/frame['case']/'window.png').tobytes(),'native key motion window')
    require(positive>=8 and zero>=8,'positive and zero pixel controls')
    return {'cases':len(ids),'trace_samples':len(data['audit']),'max_geometry_rgba':maximum,'fixed_root_bands':len(ids)*8,'positive_controls':positive,'zero_controls':zero,'motion_samples':20,'max_active':numerical(data),'game_callbacks':sum(len(v['draws']) for r in ids.values() for v in r['variants']),'group_callbacks':sum(len(v['callbacks']) for r in ids.values() for v in r['variants'])}

def verify(folder=REPORT/'native'):
    """Bind the complete production closure and native artifact hashes to the exact base plus reviewed overlay."""
    folder=Path(folder);manifest=json.loads((folder/'source.json').read_text());base=manifest['base_commit']
    require(manifest['complete'] and manifest['task']=='VFOLIAGE-006' and manifest['performance_eligible'] is False,'complete source collection')
    names=subprocess.check_output(['git','ls-tree','-r','--name-only',base],cwd=ROOT,text=True).splitlines();expected={n for n in names if n.startswith('scripts/') and n.endswith(('.gd','.gdshader'))}|set(RUNTIME)
    require(set(manifest['production'])==expected,'full production closure')
    require(set(manifest['sources'])==expected|set(QA)|{'project.godot','main.tscn','assets/game/environment/village_ambient_atlas_v1.png'} and set(manifest['overlay'])==set(RUNTIME+QA+['project.godot']),'exact source and overlay coverage')
    for name,digest in manifest['sources'].items():
        raw=(folder/'inputs'/name).read_bytes() if name in manifest['overlay'] else blob(base,name)
        require(hashlib.sha256(raw).hexdigest()==digest,'source archive: '+name)
    artifacts(folder,manifest['artifacts']);require(subprocess.check_output(['git','rev-parse',base+':assets/game'],cwd=ROOT,text=True).strip()==manifest['asset_tree'],'unchanged artwork')
    result={'task':'VFOLIAGE-006','base_commit':base,'hardware_input_accepted':False,'performance_eligible':False,'full_map_accepted':False,'windows':{}}
    for width in [1152,1280]:
        path=folder/str(width);data=json.loads((path/'capture.json').read_text());ids=metadata(data,width,manifest['sources']['scripts/presentation/foliage_wind.gdshader'])
        require(json.loads((path/'environment.json').read_text())['exit_code']==0 and not any(v in (path/'engine.txt').read_text() for v in ['ERROR:','SCRIPT ERROR','Parse Error']),'clean native exit')
        result['windows'][str(width)]=pixels(path,ids,data)
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--folder',type=Path,default=REPORT/'native');parser.add_argument('--write',action='store_true');args=parser.parse_args();result=verify(args.folder)
    if args.write:(REPORT/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
