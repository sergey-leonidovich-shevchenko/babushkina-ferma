#!/usr/bin/env python3
"""Check native roots, every mask texel, complete state and immutable source bindings."""
import argparse,hashlib,io,json,math,re,subprocess
from functools import lru_cache
from pathlib import Path
from PIL import Image
from foliage_root_collect import ROOT,REPORT,RUNTIME,QA,ART

def require(value,label):
    if not value:raise ValueError(label)

def load(path):return json.loads(Path(path).read_text())
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

@lru_cache(maxsize=600)
def blob(base,name):return subprocess.check_output(['git','show',base+':'+name],cwd=ROOT)

def passport(source):
    """Read the actually archived profile declarations, not a second readiness registry."""
    result={}
    pattern=r'"(\w+)":\{"root":Vector2i\((\d+),(\d+)\),"top":(\d+),"mode":"(\w+)"(?:,"size":Vector2i\((\d+),(\d+)\))?\}'
    for m in re.finditer(pattern,source):
        kind,x,y,top,mode,w,h=m.groups();result[kind]={'root':[int(x),int(y)],'top':int(top),'mode':mode,'size':[int(w or 362),int(h or 362)]}
    require(len(result)==13,'complete root declarations')
    return result

def check_masks(folder,entries,definitions,base=None):
    """Inspect each original pixel and data byte independently of the Godot mask builder."""
    require(len(entries)==13 and {e['kind'] for e in entries}==set(definitions),'complete unique profile coverage')
    base=base or load(REPORT/'changes.json')['base_commit']
    atlas=Image.open(io.BytesIO(blob(base,ART[0]))).convert('RGBA');pilot=Image.open(io.BytesIO(blob(base,ART[1]))).convert('RGBA')
    names=list(definitions);values={}
    for entry in entries:
        kind=entry['kind'];data=definitions[kind]
        require(all(entry[k]==data[k] for k in ['root','top','mode','size']) and entry['lock_y']==data['root'][1]-6,'profile differs from reviewed source')
        i=names.index(kind);source=pilot if kind=='grass_low' else atlas.crop((i%4*362,i//4*362,(i%4+1)*362,(i//4+1)*362))
        require(list(source.size)==data['size'] and source.getpixel(tuple(data['root']))[3]==entry['root_alpha']>=224,'root is transparent or out of source')
        path=folder/'masks'/(kind+'.png');require(sha(path)==entry['mask_sha256'],'mask hash differs')
        with Image.open(path) as opened:mask=opened.convert('L')
        require(mask.size==source.size,'mask domain mismatch')
        pixels=list(source.getdata());actual=mask.tobytes();expected=bytearray(len(actual));lock=entry['lock_y'];width=source.width
        if data['mode']=='ground':
            for y in range(lock):
                value=math.floor(max(0,min(1,(lock-y)/(lock-data['top'])))**2*255+0.5)
                for x in range(width):
                    if pixels[y*width+x][3]>=224:expected[y*width+x]=value
        require(actual==bytes(expected),'mask violates alpha/fixed-root/rigid weight contract')
        values[kind]={'root_alpha':entry['root_alpha'],'nonzero':sum(v>0 for v in actual),'bytes':len(actual)}
    require(definitions['grass_low']['root']==[219,480] and pilot.getpixel((219,490))[3]<6,'old transparent pilot pivot not distinguished')
    require(definitions['mossy_stone']['root'][1]<294 and atlas.getpixel((155,722))[3]>=224,'neighbor fragment control missing')
    return values

def frames(data,width):
    """Validate physical windows, real callbacks, all scenarios and exact whole-state pairs."""
    require(data['task']=='VFOLIAGE-001' and data['contract']=='static-root-data-v1' and data['hardware_input_accepted'] is False and data['display']!='headless' and data['profile'].startswith('Codex-VFOLIAGE-001-') and not data['errors'] and data['performance_eligible'] is False,'native identity/exit')
    cases=['west','east','north','south','stop','wall','teleport','pause','offscreen','low']
    expected=[f'sheet-{i}' for i in range(1,5)]+[f'{c}-{mode}' for c in cases for mode in ['plain','roots']]
    rows=data['rows'];require([r['id'] for r in rows]==expected,'missing, duplicate or reordered native frame')
    profiles={p['kind']:p for p in data['profiles']}
    for row in rows:
        require(row['visible'] and row['static_reduced_motion'] is True and isinstance(row['focused'],bool) and row['window']==row['image']==[width,width*9//16] and row['logical']==[1152,648],'window/visibility/static-motion/logical geometry')
        require(row['world']=='overworld' and row['before']==row['after'],'draw mutated full game')
        draws=row['draws'];require(len(draws)==2 and draws[0]['process_frame']<draws[1]['process_frame'],'actual draw coverage')
        for draw in draws:require(draw['equal'] and draw['geometry_equal'] and draw['before']==draw['after']==row['before'],'actual draw state/geometry differs')
        if row['sheet']:require(len(row['board_frames'])==2 and row['board_frames'][0]<row['board_frames'][1],'actual board callbacks missing')
        elif row['query_roots']:
            require(len(row['roots'])==2 and [r['frame'] for r in row['roots']]==[r['process_frame'] for r in draws],'root query not inside actual draw')
            for record in row['roots']:
                require(record['pure'] and len(record['anchors'])==12 and len({a['kind'] for a in record['anchors']})==12,'root query state/coverage')
                for anchor in record['anchors']:
                    root=profiles[anchor['kind']]['root'];origin=row['motion']['root_origin']
                    expected_root=[origin[0]-36+root[0]/362*72,origin[1]-48+root[1]/362*72]
                    require(all(abs(a-b)<0.001 for a,b in zip(anchor['world'],expected_root)),'native root projection differs')
        else:require(not row['roots'],'plain control called new query')
    by={r['id']:r for r in rows}
    for case in cases:
        plain=by[case+'-plain'];queried=by[case+'-roots']
        require(all(plain[k]==queried[k] for k in ['before','after','motion','camera','player','world']),'same-camera full-state pair differs')
        motion=plain['motion'];positions=motion['positions'];require(len(positions)==12,'actual input step coverage')
        if case in ['west','east','north','south']:
            require(positions[-1]!=motion['start'],'approach did not move')
            dx=positions[-1][0]-motion['start'][0];dy=positions[-1][1]-motion['start'][1]
            require(dx*motion['direction'][0]+dy*motion['direction'][1]>0,'actual movement direction differs')
        if case=='stop':require(len({tuple(p) for p in positions[4:]})==1 and positions[3]!=motion['start'],'stop input is ineffective')
        if case=='wall':require(positions[-1]==positions[-2] and positions[-1][1]>900,'actual wall control missing')
        if case=='pause':require(motion['pause'] and all(p==motion['start'] for p in positions),'pause advanced movement')
        if case=='low':require(motion['reduced_motion'],'low motion fallback control missing')
        if case=='offscreen':require(motion['root_origin']==[-8000,4000],'offscreen control missing')
        if case=='teleport':require(plain['before']['counts'].get('qa_teleport_stone',0)==1 and by['west-plain']['before']['counts'].get('qa_teleport_stone',0)==0,'actual owned teleport control missing')
    return by

def same_pixels(first,second,size):
    """Read exact RGBA from both physical images, not a similarity percentage."""
    with Image.open(first) as a,Image.open(second) as b:
        require(a.size==b.size==size and a.convert('RGBA').tobytes()==b.convert('RGBA').tobytes(),'root reads changed game pixels')

def verify(folder=None):
    folder=Path(folder or REPORT/'native');manifest=load(folder/'source.json');base=manifest['base_commit']
    require(manifest['complete'] and manifest['task']=='VFOLIAGE-001' and manifest['performance_eligible'] is False,'complete native collection')
    baseline=set(subprocess.check_output(['git','ls-tree','-r','--name-only',base],cwd=ROOT,text=True).splitlines())
    production={n for n in baseline if n.startswith('scripts/') and n.endswith('.gd')}|set(RUNTIME)
    require(set(manifest['production'])==production and len(manifest['production'])==len(production),'full production coverage')
    frozen=production|set(QA+ART+['project.godot','main.tscn'])
    require(set(manifest['sources'])==frozen and set(manifest['overlay'])==set(RUNTIME+QA+['project.godot']),'complete source and overlay coverage')
    require(manifest['asset_tree']==subprocess.check_output(['git','rev-parse',base+':assets/game'],cwd=ROOT,text=True).strip(),'immutable art tree')
    changes=load(REPORT/'changes.json');require(changes['base_commit']==base and set(changes['runtime'])==set(RUNTIME),'reviewed runtime coverage')
    for name,digest in manifest['sources'].items():
        if name in manifest['overlay']:require(sha(folder/'inputs'/name)==digest,'archived overlay source changed')
        else:require(hashlib.sha256(blob(base,name)).hexdigest()==digest,'unrelated source differs from immutable base')
        if name in RUNTIME:
            require(changes['runtime'][name]['after_sha256']==digest,'unreviewed runtime source')
            if name in baseline:require(changes['runtime'][name]['before_sha256']==hashlib.sha256(blob(base,name)).hexdigest(),'runtime base changed')
            else:require(changes['runtime'][name]['before_sha256'] is None,'new profile has fictitious history')
    actual={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==manifest['artifacts'],'complete exact native artifacts')
    definitions=passport((folder/'inputs'/RUNTIME[0]).read_text());result={'task':'VFOLIAGE-001','base_commit':base,'performance_eligible':False,'full_map_accepted':False,'profiles':13,'native_png':48,'game_draw_callbacks':96,'board_callbacks':16,'rgba_pairs':20,'windows':{}}
    for width in [1152,1280]:
        target=folder/str(width);require(load(target/'environment.json')['exit_code']==0 and not any(t in (target/'engine.txt').read_text() for t in ['ERROR:','SCRIPT ERROR','Parse Error']),'clean native process')
        data=load(target/'capture.json');by=frames(data,width);masks=check_masks(target,data['profiles'],definitions,base)
        for id,row in by.items():
            with Image.open(target/(id+'.png')) as im:require(im.size==(width,width*9//16),'physical screenshot dimensions')
            if id.endswith('-plain'):
                same_pixels(target/(id+'.png'),target/(id.removesuffix('-plain')+'-roots.png'),(width,width*9//16))
        result['windows'][str(width)]={'native_png':24,'rgba_pairs':10,'masks':masks,'root_queries':240,'full_state_equal':True,'focused_frames':sum(r['focused'] for r in data['rows']),'unfocused_frames':sum(not r['focused'] for r in data['rows']),'hardware_input_accepted':False}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');a=p.parse_args();result=verify()
    if a.write:(REPORT/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
