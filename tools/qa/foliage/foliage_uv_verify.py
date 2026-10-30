#!/usr/bin/env python3
"""Verify actual GPU atlas isolation, independent reflection and fixed lower geometry."""
from tools.common.git import git_environment
from tools.qa.world.source_inputs import historical_bytes
import argparse,hashlib,json,math,re,subprocess
from functools import lru_cache
from pathlib import Path
from PIL import Image,ImageChops
from tools.qa.foliage.foliage_uv_collect import ROOT,REPORT,RUNTIME,QA,ART
from tools.qa.foliage.foliage_root_verify import passport

def require(value,label):
    if not value:raise ValueError(label)

def load(path):return json.loads(Path(path).read_text())
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

@lru_cache(maxsize=650)
def blob(base,name):return historical_bytes(ROOT,base,name)

def difference(first,second):
    """Use the complete RGBA targets; never hide a boundary with a crop or similarity score."""
    with Image.open(first) as a,Image.open(second) as b:
        require(a.size==b.size==(192,192),'GPU target dimensions')
        data=ImageChops.difference(a.convert('RGBA'),b.convert('RGBA')).tobytes()
    return max(data),sum(any(data[i:i+4]) for i in range(0,len(data),4))

def records(data,width,definitions,shader):
    """Bind actual material parameters and world-state digests to real mesh draw callbacks."""
    require(data['task']=='VFOLIAGE-002' and data['display']!='headless' and not data['errors'] and data['profile'].startswith('Codex-VFOLIAGE-002-'),'native identity')
    require(data['performance_eligible'] is False and data['hardware_input_accepted'] is False,'static GPU scope')
    require(hashlib.sha256(data['snapshot_text'].encode()).hexdigest()==data['snapshot_sha'],'complete gameplay witness')
    snapshot=json.loads(data['snapshot_text']);require(snapshot['location']=='overworld' and snapshot['version']==2,'ordinary compatible game snapshot')
    expected=[kind+'-'+str(flip)+'-'+str(bend) for kind in definitions for flip in [0,1] for bend in [0,8,-8]]+['grass-0-8-unsafe','grass-1-8-unsafe']
    require([r['id'] for r in data['rows']]==expected,'complete ordered matrix')
    safe_sha=hashlib.sha256(shader.encode()).hexdigest()
    unsafe_line='vec2 pixel = clamp(local_uv * source_rect.zw, vec2(0.5), source_rect.zw - vec2(0.5));'
    require(shader.count(unsafe_line)==1 and not re.search(r'\bTIME\b',shader),'reviewed bounded shader without a wind clock')
    unsafe_sha=hashlib.sha256(shader.replace(unsafe_line,'vec2 pixel = local_uv * source_rect.zw;').encode()).hexdigest()
    names=list(definitions)
    for row in data['rows']:
        require(row['visible'] and isinstance(row['focused'],bool) and row['window']==[width,width*9//16] and row['logical']==[1152,648],'visible physical/logical window')
        require(row['before_sha']==row['after_sha']==data['snapshot_sha'],'UV resource draw mutated game')
        require(row['targets']==[[192,192]]*3 and len(row['projection'])==2 and all(abs(p-1.2)<.000001 for p in row['projection']),'measured separate target/projection')
        require(row['active_during']==[1,1,1] and row['active_after']==[0,0,0],'target ownership does not return to zero')
        draws=row['game_draws'];require(len(draws)==2 and draws[0]['frame']<draws[1]['frame'],'real game callbacks')
        for draw in draws:require(draw['equal'] and draw['geometry_equal'] and draw['before_sha']==draw['after_sha']==data['snapshot_sha'],'complete actual game draw witness')
        require(len(row['board_frames'])==2 and row['board_frames'][0]<row['board_frames'][1],'real visible board callbacks')
        require(len(row['uniforms'])==3 and all(len(r)==2 and r[0]['frame']<r[1]['frame'] for r in row['uniforms']),'three actual mesh draw witnesses')
        definition=definitions[row['kind']];w,h=definition['size'];root_x,root_y=definition['root'];scale=.2 if row['kind']=='grass_low' else .25
        expected_root_x=w-root_x if row['flip'] else root_x
        rows=sorted({0,.25,.5,.75,(root_y-6)/h,root_y/h,1})
        expected_vertices=[[(u*w-expected_root_x)*scale,(v*h-root_y)*scale] for v in rows for u in [0,.5,1]]
        require(len(row['vertices'])==21 and all(abs(a-b)<.0001 for p,q in zip(row['vertices'],expected_vertices) for a,b in zip(p,q)),'source-relative geometry/root or vertical flip differs')
        cell=names.index(row['kind']);region=[0,0,w,h] if row['kind']=='grass_low' else [cell%4*362,cell//4*362,w,h]
        for index,observations in enumerate(row['uniforms']):
            geometric=index==2 and row['flip'];expected_bend=[-row['bend'][0],row['bend'][1]] if geometric else row['bend']
            for record in observations:
                require(record['source_valid'] and record['mask_valid'],'actual GPU sampler missing')
                require(record['region']==(region if index==0 else [0,0,w,h]) and record['atlas_size']==([1448,1086] if index==0 and row['kind']!='grass_low' else [w,h]),'material region or sampler domain changed')
                require(record['mirror_x']==(row['flip'] if index<2 else False) and record['scale']==([-1,1] if geometric else [1,1]),'independent reflection witness')
                require(record['bend']==expected_bend and abs(record['lock_v']-(root_y-6)/h)<.000001 and abs(record['top_v']-definition['top']/h)<.000001,'actual deformation/root parameters')
                require(record['flexible']==(definition['mode']=='ground') and record['position']==[80.25,138.25] and record['vertices']==21 and record['indices']==72,'root policy or mesh differs')
                require(record['shader_sha']==(unsafe_sha if index==0 and row['unsafe'] else safe_sha),'actual shader is not the reviewed program')
    return {r['id']:r for r in data['rows']}

def pixels(folder,rows,definitions):
    """Compare source isolation and geometric reflection separately, with mandatory failing controls."""
    max_sampling=0;max_reflection=0;negative=[]
    for id,row in rows.items():
        target=folder/'pairs'/id
        delta,count=difference(target/'atlas.png',target/'isolated.png')
        reflection,_=difference(target/'atlas.png',target/'reflected.png')
        if row['unsafe']:
            require(delta>=64 and count>=500,'intentional unclamped negative control did not leak')
            negative.append({'id':id,'max':delta,'changed_pixels':count})
        else:
            require(delta<=1,'linear atlas sample differs from same-geometry isolated source')
            require(reflection<=2,'independent reflected geometry differs beyond raster precision')
            max_sampling=max(max_sampling,delta);max_reflection=max(max_reflection,reflection)
    for kind,definition in definitions.items():
        for flip in [0,1]:
            with Image.open(folder/'pairs'/f'{kind}-{flip}-0'/'atlas.png') as original:
                baseline=original.convert('RGBA')
            scale=.2 if kind=='grass_low' else .25
            locked_y=math.ceil((138.25-6*scale)*1.2)+1
            for bend in [8,-8]:
                with Image.open(folder/'pairs'/f'{kind}-{flip}-{bend}'/'atlas.png') as deformed:
                    actual=deformed.convert('RGBA')
                require(baseline.crop((0,locked_y,192,192)).tobytes()==actual.crop((0,locked_y,192,192)).tobytes(),'fixed lower strip moved')
                if definition['mode']!='ground':require(baseline.tobytes()==actual.tobytes(),'rigid/floating sprite deformed')
    require(len(negative)==2,'both negative flips required')
    return {'source_max':max_sampling,'reflection_max':max_reflection,'negative':negative,'fixed_lower_strips':26,'rigid_types':8}

def verify(folder=None):
    folder=Path(folder or REPORT/'native');manifest=load(folder/'source.json');base=manifest['base_commit']
    require(manifest['complete'] and manifest['task']=='VFOLIAGE-002' and manifest['performance_eligible'] is False,'complete accepted collection')
    baseline=set(subprocess.check_output(['git','ls-tree','-r','--name-only',base],cwd=ROOT,text=True,env=git_environment()).splitlines())
    production={n for n in baseline if n.startswith('scripts/') and n.endswith(('.gd','.gdshader'))}|set(RUNTIME)
    require(set(manifest['production'])==production and len(manifest['production'])==len(production),'complete production coverage')
    require(set(manifest['sources'])==production|set(QA+ART+['project.godot','main.tscn']) and set(manifest['overlay'])==set(RUNTIME+QA+['project.godot']),'complete frozen source coverage')
    require(manifest['asset_tree']==subprocess.check_output(['git','rev-parse',base+':assets/game'],cwd=ROOT,text=True,env=git_environment()).strip(),'immutable artwork tree')
    changes=load(REPORT/'changes.json');require(changes['base_commit']==base and set(changes['runtime'])==set(RUNTIME),'reviewed runtime changes')
    for name,digest in manifest['sources'].items():
        if name in manifest['overlay']:require(sha(folder/'inputs'/name)==digest,'archived source changed')
        else:require(hashlib.sha256(blob(base,name)).hexdigest()==digest,'unrelated source changed')
        if name in RUNTIME:require(changes['runtime'][name]['after_sha256']==digest and changes['runtime'][name]['before_sha256'] is None,'new runtime source differs from review')
    actual={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==manifest['artifacts'],'complete exact native artifacts')
    definitions=passport(blob(base,'scripts/presentation/foliage_root_profile.gd').decode());shader=(folder/'inputs'/RUNTIME[1]).read_text()
    result={'task':'VFOLIAGE-002','base_commit':base,'profiles':13,'positive_gpu_triplets':156,'negative_gpu_triplets':4,'target_png':480,'quad_callbacks':960,'game_callbacks':320,'board_callbacks':320,'performance_eligible':False,'hardware_input_accepted':False,'full_map_accepted':False,'windows':{}}
    for width in [1152,1280]:
        target=folder/str(width);require(load(target/'environment.json')['exit_code']==0 and not any(t in (target/'engine.txt').read_text() for t in ['ERROR:','SCRIPT ERROR','Parse Error']),'clean actual GPU process')
        data=load(target/'capture.json');by=records(data,width,definitions,shader);stats=pixels(target,by,definitions)
        for file in target.glob('pairs/*/window.png'):
            with Image.open(file) as image:require(image.size==(width,width*9//16),'actual physical window capture')
        with Image.open(target/'ordinary-game.png') as image:require(image.size==(width,width*9//16),'ordinary game control size')
        result['windows'][str(width)]={**stats,'focused':sum(r['focused'] for r in data['rows']),'unfocused':sum(not r['focused'] for r in data['rows']),'ownership_returns_to_zero':True,'full_gameplay_unchanged':True}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');a=p.parse_args();result=verify()
    if a.write:(REPORT/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
