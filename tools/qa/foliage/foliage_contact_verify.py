#!/usr/bin/env python3
"""Verify rooted hero reaction using native pixels, independent math and immutable inputs."""
from tools.common.git import git_environment
import argparse,hashlib,json,math,subprocess
from pathlib import Path
from PIL import Image,ImageChops
from tools.qa.foliage.foliage_wind_verify import ROOT, blob, require, artifacts, locked_bands, image
REPORT=ROOT/'docs/reports/visual-overhaul/vfoliage-004'
RUNTIME=['scripts/game_core.gd','scripts/presentation/foliage_contact.gd','scripts/presentation/foliage_wind.gd','scripts/presentation/foliage_wind_batch.gd','scripts/presentation/foliage_wind.gdshader']

def reaction(hero,anchor):
    """Independent scalar compact kernel, with no normalized singularity at the center."""
    x,y=(hero[0]-anchor[0])/36,(hero[1]-anchor[1])/36;s=x*x+y*y
    return [0.,0.] if s>=1 else [-8*x*(1-s)**2,-8*y*(1-s)**2]

def close(a,b,tolerance=0.0001):
    """Compare finite numeric vectors without allowing NaN to pass a tolerance test."""
    return len(a)==len(b) and all(math.isfinite(x) and math.isfinite(y) and abs(x-y)<=tolerance for x,y in zip(a,b))

def metadata(data,width,shader_sha):
    """Validate actual slot attributes, final/presented foot, clock, ownership and full save state."""
    require(data['task']=='VFOLIAGE-004' and data['display']!='headless' and data['profile'].startswith('Codex-VFOLIAGE-004-') and not data['errors'],'native identity')
    require(data['seed']==20261015 and data['performance_eligible'] is False and data['hardware_input_accepted'] is False,'honest scope')
    rows=data['rows'];ids={r['id']:r for r in rows};require(len(rows)==len(ids)==89,'complete unique coverage')
    roots=[(552,384),(744,456),(1032,768),(1440,984),(1800,840),(1968,960),(1944,648),(2160,888)]
    require(len(data['anchors'])==8,'eight source roots')
    for i,(x,y) in enumerate(roots):
        px,py=(148,300) if i<6 else (178,325)
        require(close(data['anchors'][i],[x-36+px*72/362,y-48+py*72/362]),'root matches immutable source layout')
    materials=None
    for row in rows:
        require(row['visible'] and row['window']==[width,width*9//16] and row['logical']==[1152,648] and row['target']==[768,384] and isinstance(row['focused'],bool),'actual physical/logical window')
        require(row['camera']==([-8000,-8000] if row['mode']=='offscreen' else [1464,378]),'same fixed camera')
        text=data['snapshots'][row['snapshot']];digest=hashlib.sha256(text.encode()).hexdigest();require(digest==row['snapshot_sha'],'full baseline snapshot')
        expected=[[0.,0.] for _ in range(64)]
        if row['frame_valid'] and row['mode'] not in ['low','reduced','reference','interior','teleport']:
            for i,anchor in enumerate(data['anchors']):expected[i]=reaction(row['presented'],anchor)
        if row['mode']=='pause':expected=ids['pause-before']['expected']
        require(len(row['expected'])==64 and all(close(a,b) for a,b in zip(expected,row['expected'])),'independent reaction field')
        require(all(math.hypot(*v)<2.3 for v in row['expected']),'bounded reaction')
        variants=row['variants'];require(len(variants)==(1 if row['mode']=='pause' else 2) and variants[0]['active'] is True,'on/off dispatch coverage')
        for variant in variants:
            require(variant['after_sha']==digest and len(variant['draws'])==2 and len({d['frame'] for d in variant['draws']})==2,'actual game callbacks and state')
            for draw in variant['draws']:require(draw['equal'] and draw['geometry_equal'] and draw['before_sha']==draw['after_sha']==digest,'pure actual draw')
            stats=variant['stats'];require(stats['owners']==1 and stats['groups']==2 and stats['builds']==1 and stats['scale']==2,'one bounded reusable owner')
            callbacks=variant['callbacks'];require(len(callbacks)==4,'two draw signals per group')
            current={c['name']:c['material_rid'] for c in callbacks}
            if materials is None:materials=current
            require(current==materials and set(current)=={'reeds','grass'},'material ownership retained')
            require(all(sum(c['name']==name for c in callbacks)==2 for name in current),'both group callbacks')
            for c in callbacks:
                name=c['name'];require(c['shader_sha']==shader_sha and c['material_rid']==materials[name] and c['parent']=='WindAtlas','actual isolated material')
                require(c['slots']==(list(range(6)) if name=='reeds' else [6,7]) and c['instances']==(6 if name=='reeds' else 2),'exact native GPU slot indices')
                require(c['seconds']==stats['seconds'],'actual uploaded clock')
                require(len(c['contacts'])==64 and all(all(math.isfinite(x) for x in v) for v in c['contacts']),'finite uniform array')
                if stats['active']:
                    target=expected if variant['active'] else [[0,0]]*64
                    require(all(close(a,b) for a,b in zip(c['contacts'],target)),'actual GPU contact array')
        if len(variants)==2:require(variants[1]['active'] is False,'explicit contact-off control')
    for side in range(4):
        for step in range(13):require(f'sweep-{side}-{step:02d}' in ids,'four approaches and boundary crossing')
    for name in ['center','stop-0','stop-1','stop-2','wall','teleport-forest','teleport-overworld']:require(all(v==[0,0] for v in ids[name]['expected']),'safe zero at center/stop/wall/transfer')
    require(ids['wall']['player']==[40,120],'actual wall collision')
    for target in ['forest','overworld']:require(ids['teleport-'+target]['teleport_success'] and ids['teleport-'+target]['world']==target,'real QA transfer')
    a,b=ids['interpolated-25'],ids['interpolated-75']
    require(a['seconds']==b['seconds'] and a['player']==b['player'] and a['presented']!=b['presented'] and a['expected']!=b['expected'],'contact follows visible foot between physical ticks')
    for i in range(3):require(ids[f'pause-{i}']['seconds']==ids['pause-before']['seconds'] and ids[f'pause-{i}']['expected']==ids['pause-before']['expected'],'pause freezes clock and field')
    for name in ['offscreen','low','reduced','reference','interior','teleport-forest']:require(ids[name]['variants'][0]['stats']['active']==0,'inactive effect')
    for name in ['return','return-again']:require(ids[name]['variants'][0]['stats']['active']==ids['sweep-0-00']['variants'][0]['stats']['active'],'visible counter returns to baseline')
    return ids

def pair(on,reference,off,influence):
    """Check the real comparison, including a negative control that cannot pass with a stationary shader."""
    require(on.size==reference.size==(768,384),'target dimensions')
    delta=max(high for low,high in ImageChops.difference(on,reference).getextrema());require(delta<=1,'GPU/CPU geometry exceeds 1/255 RGBA')
    if off is not None:
        locked_bands(off,on)
        if influence<1e-7:require(on.tobytes()==off.tobytes(),'zero contact changes pixels')
        else:require(max(hi for lo,hi in ImageChops.difference(on,off).getextrema())>10,'contact does not visibly affect GPU pixels')
    return delta

def pixels(folder,ids):
    """Compare full GPU/CPU RGBA, exact roots, real positive contact and exact zero controls."""
    baseline=image(folder/'sweep-0-00/on.png');maximum=0;positive=zero=0
    for row in ids.values():
        on=image(folder/row['id']/'on.png');reference=image(folder/row['id']/'reference.png')
        require(on.size==reference.size==(768,384),'target dimensions');locked_bands(on,baseline)
        if row['variants'][0]['stats']['active']:
            off=image(folder/row['id']/'off.png') if len(row['variants'])==2 else None
            influence=max(math.hypot(*v) for v in row['expected'])
            maximum=max(maximum,pair(on,reference,off,influence))
            if len(row['variants'])==2:
                if influence<1e-7:zero+=1
                else:positive+=1
    require(positive>=30 and zero>=10,'positive and zero controls exercised')
    for side in range(4):
        movie=Image.open(folder/f'motion-{side}.png');proof=json.loads((folder/f'motion-{side}.json').read_text());require(movie.n_frames==len(proof['frames'])==13,'complete lossless animation')
        for i,frame in enumerate(proof['frames']):
            movie.seek(i);rgba=movie.convert('RGBA');require(frame['case']==f'sweep-{side}-{i:02d}' and hashlib.sha256(rgba.tobytes()).hexdigest()==frame['rgba_sha'],'exact decoded motion sample')
            if i in [0,6,12]:require(rgba.tobytes()==image(folder/frame['case']/'on-window.png').tobytes(),'retained window matches animation')
    return {'cases':len(ids),'max_geometry_rgba':maximum,'fixed_root_bands':len(ids)*8,'positive_controls':positive,'zero_controls':zero,'motion_samples':52,'game_callbacks':sum(len(v['draws']) for r in ids.values() for v in r['variants']),'group_callbacks':sum(len(v['callbacks']) for r in ids.values() for v in r['variants'])}

def verify(folder=REPORT/'native'):
    """Validate the complete historical source closure and every native file before acceptance."""
    folder=Path(folder);m=json.loads((folder/'source.json').read_text());base=m['base_commit'];require(m['complete'] and m['task']=='VFOLIAGE-004' and m['performance_eligible'] is False,'complete scoped collection')
    names=subprocess.check_output(['git','ls-tree','-r','--name-only',base],cwd=ROOT,text=True,env=git_environment()).splitlines();expected={n for n in names if n.startswith('scripts/') and n.endswith(('.gd','.gdshader'))}|set(RUNTIME)
    require(set(m['production'])==expected,'complete production closure')
    for name,digest in m['sources'].items():
        raw=(folder/'inputs'/name).read_bytes() if name in m['overlay'] else blob(base,name);require(hashlib.sha256(raw).hexdigest()==digest,'source archive: '+name)
    artifacts(folder,m['artifacts'])
    require(subprocess.check_output(['git','rev-parse',base+':assets/game'],cwd=ROOT,text=True,env=git_environment()).strip()==m['asset_tree'],'artwork unchanged')
    shader=(folder/'inputs/scripts/presentation/foliage_wind.gdshader').read_text();require('TIME' not in shader and 'contact_bends[64]' in shader and 'INSTANCE_CUSTOM.y' in shader,'controlled indexed shader')
    result={'task':'VFOLIAGE-004','base_commit':base,'hardware_input_accepted':False,'performance_eligible':False,'full_map_accepted':False,'windows':{}}
    for width in [1152,1280]:
        p=folder/str(width);ids=metadata(json.loads((p/'capture.json').read_text()),width,m['sources']['scripts/presentation/foliage_wind.gdshader']);result['windows'][str(width)]=pixels(p,ids)
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,default=REPORT/'native');p.add_argument('--write',action='store_true');a=p.parse_args();result=verify(a.folder)
    if a.write:(REPORT/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
