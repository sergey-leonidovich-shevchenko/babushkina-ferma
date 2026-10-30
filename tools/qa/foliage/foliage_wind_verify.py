#!/usr/bin/env python3
"""Verify native wind against CPU geometry, immutable sources and complete save snapshots."""
from tools.common.git import git_environment
from tools.common.paths import project_root
from tools.qa.world.source_inputs import historical_bytes
import argparse,hashlib,json,math,subprocess,functools
from pathlib import Path
from PIL import Image,ImageChops
ROOT=project_root(__file__)
REPORT=ROOT/'docs/reports/visual-overhaul/vfoliage-003'
RUNTIME=['scripts/game_core.gd','scripts/systems/village_ambient_renderer.gd','scripts/presentation/foliage_wind.gd','scripts/presentation/foliage_wind_batch.gd','scripts/presentation/foliage_wind.gdshader']

def require(value,label):
    """Fail at the actual violated condition."""
    if not value:raise ValueError(label)

def sha(path):
    """Hash exact artifact bytes."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

@functools.lru_cache(maxsize=None)
def blob(base,name):
    """Read historical source by immutable Git object, never current working-tree code."""
    return historical_bytes(ROOT,base,name)

def metadata(data,width,shader_sha):
    """Check complete native dispatch, phase storage, controls and full state before reading pixels."""
    require(data['task']=='VFOLIAGE-003' and data['display']!='headless' and data['profile'].startswith('Codex-VFOLIAGE-003-') and not data['errors'],'native identity')
    require(data['seed']==20261015 and data['hardware_input_accepted'] is False and data['performance_eligible'] is False,'honest scope and seed')
    rows=data['rows'];require(len(rows)==68 and len({r['id'] for r in rows})==68,'complete unique cases')
    ids={r['id']:r for r in rows};require(all(f'wind-{i:02d}' in ids for i in range(49)),'49 continuous samples')
    first=rows[0]['stats'];require(first['active']>0 and first['groups']==2 and first['owners']==1 and first['builds']==1,'bounded production owner')
    phases=None;rids=None
    for row in rows:
        require(row['visible'] and row['window']==[width,width*9//16] and row['logical']==[1152,648] and isinstance(row['focused'],bool),'actual visible physical/logical window')
        require(row['target']==[768,384] and row['stats']['scale']==2 and row['stats']['groups']==2 and row['stats']['builds']==1 and row['stats']['owners']==1,'stable atlas and ownership')
        text=data['snapshots'][row['snapshot']];digest=hashlib.sha256(text.encode()).hexdigest()
        require(digest==row['snapshot_sha']==row['after_sha'],'complete save snapshot')
        require(len(row['draws'])==2 and len({d['frame'] for d in row['draws']})==2,'two actual game callbacks')
        for draw in row['draws']:require(draw['equal'] and draw['geometry_equal'] and draw['before_sha']==draw['after_sha']==digest,'pure production draw')
        callbacks=row['callbacks'];require(len(callbacks)==4,'two actual callbacks per group')
        for group in callbacks:
            require(group['name'] in ['grass','reeds'] and group['parent']=='WindAtlas' and group['shader_sha']==shader_sha,'actual isolated shader dispatch')
            require(group['instances']==(2 if group['name']=='grass' else 6) and group['seconds']==row['seconds'],'actual group size and time')
        current={c['name']:c['phases'] for c in callbacks};materials={c['name']:c['material_rid'] for c in callbacks}
        if phases is None:phases=current;rids=materials
        require(current==phases and materials==rids,'immutable group phases and reused materials')
        require({name:sum(c['name']==name for c in callbacks) for name in ['grass','reeds']}=={'grass':2,'reeds':2},'both group callbacks are represented')
        for callback in callbacks:require(callback['phases']==phases[callback['name']] and callback['material_rid']==rids[callback['name']] and callback['material_rid']!='RID(0)','every callback preserves phases and ownership')
    roots=[(552,384,'reeds'),(744,456,'reeds'),(1032,768,'reeds'),(1440,984,'reeds'),(1800,840,'reeds'),(1968,960,'reeds'),(1944,648,'grass'),(2160,888,'grass')]
    for kind in ['reeds','grass']:
        selected=[r for r in roots if r[2]==kind]
        for stored,(x,y,_) in zip(phases[kind],selected):
            rx,ry=(148,300) if kind=='reeds' else (178,325)
            anchor=(x-36+rx*72/362,y-48+ry*72/362)
            desired=(anchor[0]*.017+anchor[1]*.031)%(2*math.pi)
            require(abs(stored-desired)<.004,'spatial phase survives compatibility half-float storage')
        require(len(set(phases[kind]))==len(selected),'distinct spatial phases')
    for i in range(49):require(abs(ids[f'wind-{i:02d}']['seconds']-i/12)<1e-12 and ids[f'wind-{i:02d}']['stats']['uploads']==i+1,'no skipped clock or repeated upload')
    for mode in ['pause-0','pause-1','pause-2','offscreen','low','reduced','flag_off','reference','interior']:
        require(ids[mode]['seconds']==4 and ids[mode]['stats']['uploads']==49,'frozen pause and fallback GPU clock')
    for mode in ['offscreen','low','reduced','flag_off','reference','interior']:require(ids[mode]['stats']['active']==0,'inactive fallback')
    for mode in ['return','return_again']:
        require(ids[mode]['stats']['active']==first['active'],'counters return to baseline')
        require(ids[mode]['target_update_request']==1,'return refreshes a previously cancelled target with the same clock')
    approaches=[r for r in rows if r['id'].startswith('approach-')]
    require(len(approaches)==4 and {tuple(r['movement']['side']) for r in approaches}=={(-1,0),(1,0),(0,-1),(0,1)},'four actual approach directions')
    require(all(r['movement']['before']!=r['movement']['after'] for r in approaches),'real movement in all approaches')
    require(ids['wall']['movement']['before']==ids['wall']['movement']['after'],'actual wall stops movement')
    for target in ['forest','overworld']:require(ids['teleport-'+target]['teleport_success'] and ids['teleport-'+target]['world']==target,'actual QA teleport route')
    require(ids['teleport-forest']['stats']['active']==0,'other world hides wind')
    return ids

def image(path):
    """Decode complete unmodified RGBA target."""
    return Image.open(path).convert('RGBA')

def locked_bands(actual,baseline):
    """Refuse any changed pixel in the entire lower strip, including visible roots and transparent padding."""
    for i in range(8):
        x,y=(i%4)*192,(i//4)*192;lock_y=294 if i<6 else 319
        lower=math.ceil((12+lock_y*72/362)*2)+1
        band=(x,y+lower,x+192,y+192)
        require(actual.crop(band).tobytes()==baseline.crop(band).tobytes(),'root/lower strip moved')
        require(actual.crop(band).getchannel('A').getextrema()[1]>200,'locked band contains actual painted root')

def artifacts(folder,entries):
    """Require exact artifact coverage and bytes; removing a corrupt entry cannot hide it."""
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==set(entries),'complete artifact coverage')
    for name,digest in entries.items():require(sha(folder/name)==digest,'native artifact: '+name)

def pixels(folder,ids):
    """Check every source pixel, lower locked band and lossless window-animation sample."""
    first=image(folder/'wind-00/atlas.png');motion=[0]*8;maximum=0
    for row in ids.values():
        a=image(folder/row['id']/'atlas.png');b=image(folder/row['id']/'reference.png')
        require(a.size==b.size==(768,384),'exact GPU target dimensions')
        delta=max(high for low,high in ImageChops.difference(a,b).getextrema());maximum=max(maximum,delta)
        require(delta<=1,'CPU geometry and actual GPU differ by more than 1/255 RGBA')
        locked_bands(a,first)
        for i in range(8):
            x,y=(i%4)*192,(i//4)*192;lock_y=294 if i<6 else 319
            crop=(x,y,x+192,y+192)
            changed=sum(1 for p in ImageChops.difference(a.crop(crop),first.crop(crop)).getdata() if max(p)>0)
            motion[i]=max(motion[i],changed)
            require(a.getpixel((x,y))[3]==0 and a.getpixel((x+191,y+191))[3]==0,'tuft crosses slot padding')
    require(min(motion)>20,'every tuft visibly moves above its root')
    movie=Image.open(folder/'motion.png');proof=json.loads((folder/'motion.json').read_text())
    require(movie.n_frames==49 and len(proof['frames'])==49,'complete lossless motion archive')
    for i,entry in enumerate(proof['frames']):
        movie.seek(i);rgba=movie.convert('RGBA')
        require(entry['frame']==i and entry['case']==f'wind-{i:02d}' and hashlib.sha256(rgba.tobytes()).hexdigest()==entry['rgba_sha'],'decoded native motion pixels')
        require(rgba.size==tuple(ids[entry['case']]['window']),'full window movie size')
        if i in [0,24,48]:require(rgba.tobytes()==image(folder/entry['case']/'window.png').tobytes(),'retained native window matches movie')
    return {'max_geometry_rgba':maximum,'moving_pixels_per_tuft':motion,'fixed_root_bands':len(ids)*8,'motion_samples':49}

def verify(folder=REPORT/'native'):
    """Bind full production code, source overlay, all native files and both physical windows."""
    folder=Path(folder);manifest=json.loads((folder/'source.json').read_text());base=manifest['base_commit']
    require(manifest['complete'] and manifest['task']=='VFOLIAGE-003' and manifest['performance_eligible'] is False,'complete limited collection')
    production={n for n in subprocess.check_output(['git','ls-tree','-r','--name-only',base],cwd=ROOT,text=True,env=git_environment()).splitlines() if n.startswith('scripts/') and n.endswith(('.gd','.gdshader'))}|set(RUNTIME)
    require(set(manifest['production'])==production,'complete production source closure')
    for name,digest in manifest['sources'].items():
        raw=(folder/'inputs'/name).read_bytes() if name in manifest['overlay'] else blob(base,name)
        require(hashlib.sha256(raw).hexdigest()==digest,'source archive: '+name)
    require(subprocess.check_output(['git','rev-parse',base+':assets/game'],cwd=ROOT,text=True,env=git_environment()).strip()==manifest['asset_tree'],'unchanged artwork tree')
    artifacts(folder,manifest['artifacts'])
    shader_sha=manifest['sources']['scripts/presentation/foliage_wind.gdshader'];shader=(folder/'inputs/scripts/presentation/foliage_wind.gdshader').read_text()
    require('TIME' not in shader and 'VERTEX.x +=' in shader and 'VERTEX.y' not in shader and 'clamp(UV * region_size' in shader,'rooted local bounded shader')
    result={'task':'VFOLIAGE-003','base_commit':base,'performance_eligible':False,'hardware_input_accepted':False,'full_map_accepted':False,'windows':{}}
    for width in [1152,1280]:
        target=folder/str(width);data=json.loads((target/'capture.json').read_text());ids=metadata(data,width,shader_sha)
        result['windows'][str(width)]={**pixels(target,ids),'cases':len(ids),'game_callbacks':sum(len(r['draws']) for r in ids.values()),'group_callbacks':sum(len(r['callbacks']) for r in ids.values())}
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--folder',type=Path,default=REPORT/'native');parser.add_argument('--write',action='store_true');args=parser.parse_args();result=verify(args.folder)
    if args.write:(REPORT/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
