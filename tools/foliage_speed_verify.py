#!/usr/bin/env python3
"""Verify real physical speed, native GPU fields and lossless motion against immutable sources."""
import argparse,hashlib,json,math,subprocess
from pathlib import Path
from PIL import Image,ImageChops
from foliage_contact_verify import ROOT,blob,sha,require,artifacts,locked_bands,image,reaction,close
REPORT=ROOT/'docs/reports/visual-overhaul/vfoliage-005'
RUNTIME=['scripts/core/game_loop.gd','scripts/presentation/foliage_contact.gd','scripts/presentation/foliage_speed.gd']
QA=['tools/foliage_contact_capture.gd','tools/foliage_speed_capture.gd','tools/foliage_speed_collect.py','tools/foliage_wind_capture.gd','tools/visual_camera_points.gd','tools/render_order_game.gd']

def case_ids():
    """Keep the complete physical matrix and exceptional transitions explicit."""
    return {f'rate-{hz}-{side}-{pace}' for hz in [30,120] for side in range(4) for pace in [70,210,273]}|{f'sweep-{pace}-{side}-{step:02d}' for pace in [70,273] for side in [0,2] for step in range(13)}|{'center-70','center-273','stop','stop-repeat','wall','slide','hitstop-half','pause-before','pause-0','pause-1','pause-2','interpolated-25','interpolated-75','same-world-jump','offscreen','return','low','reduced','reference','interior','return-again','malformed','teleport-forest','teleport-overworld'}

def gain(velocity):
    """Independent scalar amplitude from the measured velocity, with a hard finite limit."""
    require(len(velocity)==2 and all(math.isfinite(x) for x in velocity),'finite velocity')
    return 1+0.9*min(math.hypot(*velocity)/280,1)**2

def velocity(row):
    """Reconstruct displacement per simulation delta; never trust a requested direction as speed."""
    raw=row['motion']
    if not row['frame_valid']:return [0.,0.]
    require(raw and raw['immutable'] and raw['world']==row['world'] and close(raw['player'],row['player']) and abs(raw['seconds']-row['seconds'])<1e-6,'same immutable completed tick')
    dt=raw['delta'];require(math.isfinite(dt) and dt>0,'positive simulation delta')
    calculated=[(x-y)/dt for x,y in zip(row['player'],raw['origin'])]
    require(close(raw['velocity'],calculated,.03),'actual velocity from resolved displacement')
    trace=row['trace'];require(close(trace['origin'],raw['origin']) and close(trace['end'],row['player']),'physical trace matches producer')
    expected=trace['input_delta']*(.5 if row['id']=='hitstop-half' else 1)
    require(abs(dt-expected)<1e-6,'uses simulation delta, including hit stop')
    return calculated

def field(row,anchors,amplitude):
    """Keep the accepted spatial contact, adding bounded speed only in the active mode."""
    out=[[0.,0.] for _ in range(64)]
    if row['frame_valid'] and row['mode'] not in ['low','reduced','reference','interior','teleport']:
        for i,root in enumerate(anchors):out[i]=[x*amplitude for x in reaction(row['presented'],root)]
    return out

def metadata(data,width,shader_sha):
    """Check actual physical steps, native attributes, source shader, callbacks and unchanged saves."""
    require(data['task']=='VFOLIAGE-005' and data['display']!='headless' and data['profile'].startswith('Codex-VFOLIAGE-005-') and not data['errors'],'native identity')
    require(data['seed']==20261015 and data['performance_eligible'] is False and data['hardware_input_accepted'] is False,'honest scope')
    rows=data['rows'];ids={r['id']:r for r in rows};require(len(rows)==len(ids)==100 and set(ids)==case_ids(),'complete unique physical coverage')
    origins=[(552,384),(744,456),(1032,768),(1440,984),(1800,840),(1968,960),(1944,648),(2160,888)]
    require(len(data['anchors'])==8,'eight existing plants')
    for i,(x,y) in enumerate(origins):
        px,py=(148,300) if i<6 else (178,325)
        require(close(data['anchors'][i],[x-36+px*72/362,y-48+py*72/362]),'immutable source roots')
    materials=None
    for row in rows:
        require(row['visible'] and row['window']==[width,width*9//16] and row['logical']==[1152,648] and row['target']==[768,384] and isinstance(row['focused'],bool),'actual native window')
        require(row['camera']==([-8000,-8000] if row['mode']=='offscreen' else [1464,378]),'same camera')
        zoom=1.2 if row['world']=='overworld' else 1
        require(close(row['background']['scale'],[zoom,zoom]) and close(row['background']['position'],[-v*zoom for v in row['camera']],.001),'background shares actual fixed camera')
        measured=velocity(row);amplitude=gain(measured) if row['mode']!='malformed' else 1
        expected=field(row,data['anchors'],amplitude)
        if row['mode']=='pause':expected=ids['pause-before']['expected']
        require(len(row['expected'])==64 and all(close(a,b,.0006) for a,b in zip(row['expected'],expected)),'independent speed contact')
        require(all(math.hypot(*v)<4.36 for v in row['expected']),'bounded combined spatial speed field')
        text=data['snapshots'][row['snapshot']];digest=hashlib.sha256(text.encode()).hexdigest();require(digest==row['snapshot_sha'],'full snapshot')
        variants=row['variants'];require(len(variants)==(1 if row['mode']=='pause' else 2) and variants[0]['active'] is True,'on/off coverage')
        for variant in variants:
            require(variant['after_sha']==digest and len(variant['draws'])==2 and len({d['frame'] for d in variant['draws']})==2,'actual game callbacks')
            for d in variant['draws']:require(d['equal'] and d['geometry_equal'] and d['before_sha']==d['after_sha']==digest,'draw preserves all gameplay')
            active=variant['active'];flag=17 if row['mode']=='malformed' and active else active
            require(type(variant['speed_flag']) is type(flag) and variant['speed_flag']==flag,'actual speed flag')
            expected_gain=amplitude if active else 1
            require(math.isfinite(variant['gain']) and abs(variant['gain']-expected_gain)<.0003,'actual strength from displacement')
            stats=variant['stats'];require(stats['owners']==1 and stats['groups']==2 and stats['builds']==1 and stats['scale']==2,'bounded reused geometry')
            callbacks=variant['callbacks'];require(len(callbacks)==4,'two actual draws per group')
            current={c['name']:c['material_rid'] for c in callbacks}
            if materials is None:materials=current
            require(current==materials and set(current)=={'grass','reeds'},'stable material ownership')
            for c in callbacks:
                name=c['name'];require(c['shader_sha']==shader_sha and c['parent']=='WindAtlas' and c['material_rid']==materials[name],'actual source material')
                require(sum(v['name']==name for v in callbacks)==2 and c['slots']==(list(range(6)) if name=='reeds' else [6,7]),'exact native slots')
                require(c['instances']==(6 if name=='reeds' else 2) and c['seconds']==stats['seconds'],'actual instances and clock')
                target=expected if active else field(row,data['anchors'],1)
                require(len(c['contacts'])==64 and all(all(math.isfinite(v) for v in p) for p in c['contacts']),'finite GPU buffer')
                if stats['active']:require(all(close(a,b,.0006) for a,b in zip(c['contacts'],target)),'actual speed GPU contact array')
        if len(variants)==2:require(variants[1]['active'] is False,'explicit speed-only rollback')
    for hz in [30,120]:
        for side in range(4):
            samples=[ids[f'rate-{hz}-{side}-{pace}'] for pace in [70,210,273]]
            require(all(close(r['player'],samples[0]['player'],.0002) and abs(r['seconds']-12)<1e-6 for r in samples),'shared endpoint and wind phase across paces')
            actual=[math.hypot(*velocity(r)) for r in samples]
            require(all(abs(a-b)<.03 for a,b in zip(actual,[70,210,273])) and actual[0]<actual[1]<actual[2],'real slow, walk and buffed run')
    require(ids['wall']['trace']['held']==[False,True,False,False] and velocity(ids['wall'])==[0.,0.],'held input at real wall produces no velocity')
    require(gain(velocity(ids['slide']))<gain([210,0]) and abs(velocity(ids['slide'])[0])<.001 and velocity(ids['slide'])[1]>0,'sliding uses resolved tangent speed')
    for name in ['stop','stop-repeat']:require(velocity(ids[name])==[0.,0.] and ids[name]['variants'][0]['gain']==1,'stop has no retained boost')
    require(ids['stop']['variants'][0]['stats']==ids['stop-repeat']['variants'][0]['stats'],'stationary rendering does not grow counters')
    for i in range(3):require(ids[f'pause-{i}']['seconds']==ids['pause-before']['seconds'] and ids[f'pause-{i}']['expected']==ids['pause-before']['expected'],'pause freezes physical speed field')
    a,b=ids['interpolated-25'],ids['interpolated-75'];require(a['player']==b['player'] and a['seconds']==b['seconds'] and a['motion']==b['motion'] and a['presented']!=b['presented'],'same speed and distinct presented feet')
    for name in ['center-70','center-273','same-world-jump','teleport-forest','teleport-overworld']:require(all(v==[0,0] for v in ids[name]['expected']),'zero center or invalidated transfer')
    for target in ['forest','overworld']:require(ids['teleport-'+target]['teleport_success'] and ids['teleport-'+target]['world']==target,'real QA transfer')
    for name in ['offscreen','low','reduced','reference','interior','teleport-forest']:require(ids[name]['variants'][0]['stats']['active']==0,'disabled target')
    for name in ['return','return-again']:require(ids[name]['variants'][0]['stats']['active']==ids['rate-30-0-70']['variants'][0]['stats']['active'],'active counter restored')
    return ids

def pair(on,reference,off,influence):
    """Use full RGBA and a real positive control; retain exact zero and fixed-root checks."""
    require(on.size==reference.size==off.size==(768,384),'target size')
    delta=max(hi for lo,hi in ImageChops.difference(on,reference).getextrema());require(delta<=1,'GPU/CPU geometry')
    locked_bands(on,off);change=max(hi for lo,hi in ImageChops.difference(on,off).getextrema())
    if influence<1e-7:require(on.tobytes()==off.tobytes(),'zero speed changes pixels')
    elif influence>.15:require(change>5,'speed does not visibly affect GPU')
    return delta

def pixels(folder,ids,anchors):
    """Verify native geometry, real cross-pace differences and every decoded motion sample."""
    baseline=image(folder/'rate-30-0-70/on.png');maximum=positive=zero=0
    for row in ids.values():
        on=image(folder/row['id']/'on.png');locked_bands(on,baseline)
        if row['variants'][0]['stats']['active']:
            ref=image(folder/row['id']/'reference.png')
            if len(row['variants'])==2:
                off=image(folder/row['id']/'off.png');base=field(row,anchors,1)
                influence=max(math.dist(a,b) for a,b in zip(row['expected'],base))
                maximum=max(maximum,pair(on,ref,off,influence));positive+=int(influence>.15);zero+=int(influence<1e-7)
            else:require(max(hi for lo,hi in ImageChops.difference(on,ref).getextrema())<=1,'paused GPU/CPU geometry')
    for hz in [30,120]:
        for side in range(4):
            a=image(folder/f'rate-{hz}-{side}-70/on.png');b=image(folder/f'rate-{hz}-{side}-273/on.png')
            require(max(hi for lo,hi in ImageChops.difference(a,b).getextrema())>10,'real slow/run pixel difference')
    for pace in [70,273]:
        for side in [0,2]:
            movie=Image.open(folder/f'motion-{pace}-{side}.png');proof=json.loads((folder/f'motion-{pace}-{side}.json').read_text())
            require(movie.n_frames==len(proof['frames'])==13,'complete lossless motion')
            for i,f in enumerate(proof['frames']):
                movie.seek(i);rgba=movie.convert('RGBA');require(f['case']==f'sweep-{pace}-{side}-{i:02d}' and hashlib.sha256(rgba.tobytes()).hexdigest()==f['rgba_sha'],'decoded motion pixels')
                if i in [0,6,12]:require(rgba.tobytes()==image(folder/f['case']/'on-window.png').tobytes(),'key motion window')
    require(positive>=20 and zero>=10,'real positive and zero controls')
    return {'cases':len(ids),'max_geometry_rgba':maximum,'fixed_root_bands':len(ids)*8,'positive_controls':positive,'zero_controls':zero,'slow_run_pairs':8,'motion_samples':52,'game_callbacks':sum(len(v['draws']) for r in ids.values() for v in r['variants']),'group_callbacks':sum(len(v['callbacks']) for r in ids.values() for v in r['variants'])}

def verify(folder=REPORT/'native'):
    """Bind all production/QA sources and artifacts to the immutable base and reviewed overlay."""
    folder=Path(folder);m=json.loads((folder/'source.json').read_text());base=m['base_commit']
    require(m['complete'] and m['task']=='VFOLIAGE-005' and m['performance_eligible'] is False,'complete source collection')
    names=subprocess.check_output(['git','ls-tree','-r','--name-only',base],cwd=ROOT,text=True).splitlines();expected={n for n in names if n.startswith('scripts/') and n.endswith(('.gd','.gdshader'))}|set(RUNTIME)
    require(set(m['production'])==expected,'full production closure')
    require(set(m['sources'])==expected|set(QA)|{'project.godot','main.tscn','assets/game/environment/village_ambient_atlas_v1.png'} and set(m['overlay'])==set(RUNTIME+QA+['project.godot']),'exact source and overlay coverage')
    for name,digest in m['sources'].items():
        raw=(folder/'inputs'/name).read_bytes() if name in m['overlay'] else blob(base,name)
        require(hashlib.sha256(raw).hexdigest()==digest,'source archive: '+name)
    artifacts(folder,m['artifacts']);require(subprocess.check_output(['git','rev-parse',base+':assets/game'],cwd=ROOT,text=True).strip()==m['asset_tree'],'unchanged artwork')
    result={'task':'VFOLIAGE-005','base_commit':base,'hardware_input_accepted':False,'performance_eligible':False,'full_map_accepted':False,'windows':{}}
    for width in [1152,1280]:
        p=folder/str(width);data=json.loads((p/'capture.json').read_text());ids=metadata(data,width,m['sources']['scripts/presentation/foliage_wind.gdshader'])
        require(json.loads((p/'environment.json').read_text())['exit_code']==0 and not any(v in (p/'engine.txt').read_text() for v in ['ERROR:','SCRIPT ERROR','Parse Error']),'clean native exit')
        result['windows'][str(width)]=pixels(p,ids,data['anchors'])
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,default=REPORT/'native');p.add_argument('--write',action='store_true');a=p.parse_args();result=verify(a.folder)
    if a.write:(REPORT/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
