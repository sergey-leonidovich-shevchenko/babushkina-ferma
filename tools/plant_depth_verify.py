#!/usr/bin/env python3
"""Verify real plant/hero depth dispatch, complete gameplay, rollback and bounded changed pixels."""
import argparse,gzip,hashlib,json,math
from functools import lru_cache
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw,ImageStat
from plant_depth_collect import ORIGINAL,EXTRA
from tools.qa.world.source_inputs import historical_bytes
ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'docs/reports/visual-overhaul/vrender-006'
NEW='scripts/presentation/forage_depth_renderer.gd'
CHANGED={'scripts/game_renderer.gd','scripts/presentation/farm_renderer.gd','scripts/systems/tree_occlusion_system.gd',NEW}
ORDER=['tree:'+str(x) for x in [-24.0,-6.125,-6.0,-5.875,0.0,24.0]]+['bush:'+str(x) for x in [-24.0,-6.0,0.0,24.0]]+['crop:'+str(x) for x in [-24.0,-6.0,0.0,24.0]]+['same-depth:a','same-depth:b']+[f'sweep:{i}' for i in range(24)]+['bridge-west','bridge-east','pause','storage','editor','interior','other-map','returned']

def require(value,label):
    """Never replace damaged native evidence during validation."""
    if not value:raise ValueError(label)

def sha(path):
    """Bind immutable inputs and native artifacts to exact bytes."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

@lru_cache(maxsize=512)
def git_blob(base,name):
    """Cache only immutable Git blobs; actual evidence files are always read and hashed again."""
    return historical_bytes(ROOT,base,name)

def capture(path):
    """Read full captured saves and actual dispatches without launching Godot."""
    return json.loads(gzip.decompress((Path(path)/'capture.json.gz').read_bytes()))

def validate_rows(data,phase,width):
    """Validate every actual frame, tie boundary, alpha, dispatch and cleared queue."""
    modes=['legacy'] if phase=='before' else ['legacy','enabled']
    expected=[(i,name,mode) for i,name in enumerate(ORDER) for mode in modes]
    require(data['task']=='VRENDER-006' and data['phase']==phase and data['physical_frames']==48 and not data['errors'],'complete capture identity')
    require(data['display']!='headless' and not data['performance_eligible'] and data['fixed_physics_hz']==30 and data['video_hz']==10,'controlled native capture')
    require([(r['index'],r['id'],r['mode']) for r in data['rows']]==expected,'complete ordered real frames')
    for row in data['rows']:
        require(row['image_file']==f"frames/{row['mode']}/{row['index']:04d}.png",'unique frame filename')
        require(row['window']==row['image']==[width,width*9//16] and row['logical']==[1152,648] and row['visible'] and row['focused'],'physical window/focus')
        require(row['before']==row['after'] and len(row['draws'])==len(row['depths'])==2,'two pure production callbacks')
        require(all(d['equal'] and d['geometry_equal'] and d['before']==d['after']==row['before'] and d['queue_after']==0 for d in row['draws']),'draw changes gameplay/geometry/queue')
        require(len({d['process_frame'] for d in row['draws']})==2 and len({d['frame'] for d in row['depths']})==2,'distinct real callbacks')
        for sample in row['depths']:
            require(sample['queue_after']==0,'callback retained after frame')
            trace=sample['trace'];require(len(trace)<512,'complete bounded trace')
            if phase=='before':require(not trace,'baseline has no invented dispatch instrumentation');continue
            if not row['storage']:require(sample['hero_ground']==row['ground'],'single captured hero presentation ground')
            require(len({t['key'] for t in trace})==len(trace),'opaque duplicate key in actual draw')
            for item in trace:
                require(item['kind'] in ['texture','body'] and len(item['rect'])==4 and all(math.isfinite(n) for n in item['rect']+[item['ground_y'],item['alpha']]),'finite actual packet')
                require(item['phase']==('front' if row['ground'][1]<item['ground_y']-6 else 'back'),'strict ground boundary')
                require(item['alpha'] in [0.34,1.0] or abs(item['alpha']-0.34)<0.0001,'single preserved tree alpha')
            active=row['mode']=='enabled' and row['world']=='overworld' and not row['editor']
            if not active:require(not any(t['kind']=='body' for t in trace),'new body dispatch outside scope')
            else:
                front=[(t['ground_y'],t['key']) for t in trace if t['phase']=='front']
                require(front==sorted(front),'stable equal-root foreground order')
            if row['storage'] or row['world']=='cottage_interior':require(not trace,'hidden world must not dispatch plants')
        if row['id']=='pause':require(row['pause'],'actual manual pause')
        if row['id']=='editor':require(row['editor'],'actual F12')
        if row['id']=='interior':require(row['world']=='cottage_interior','actual home entry')
        if row['id']=='other-map':require(row['world']=='village_market','actual neighbouring map')
    for mode in modes:
        sweep=[r for r in data['rows'] if r['mode']==mode and r['id'].startswith('sweep:')]
        require(all(b['player'][1]>a['player'][1] for a,b in zip(sweep,sweep[1:])),'actual sweep must move through the threshold')
        require(min(r['ground'][1] for r in sweep)<data['tree_ground'][1]-6<max(r['ground'][1] for r in sweep),'sweep crosses the ground boundary')

def validate_source(folder,phase,changes,source=None):
    """Require complete archived inputs/artifacts, Git baseline and only the reviewed runtime patch."""
    folder=Path(folder);source=source or json.loads((folder/'source.json').read_text())
    require(source['task']=='VRENDER-006' and source['phase']==phase and source['complete'] and not source['performance_eligible'],'complete source manifest')
    names=set(ORIGINAL+EXTRA)-({NEW} if phase=='before' else set())
    require(set(source['sources'])==names,'source coverage')
    require(source['base_commit']==changes['base_commit'] and set(changes['files'])==CHANGED,'reviewed patch scope')
    for name,digest in source['sources'].items():
        p=folder/'inputs'/name;require(p.is_file() and sha(p)==digest,'exact archived source '+name)
        if name in ORIGINAL:
            old=git_blob(source['base_commit'],name)
            if phase=='before' or name not in CHANGED:require(p.read_bytes()==old,'unchanged production input '+name)
            else:require(digest==changes['files'][name]['after_sha256'] and hashlib.sha256(old).hexdigest()==changes['files'][name]['before_sha256'],'reviewed input '+name)
        elif name==NEW:require(digest==changes['files'][name]['after_sha256'],'reviewed new helper')
    actual={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==source['artifacts'],'complete exact artifacts')
    for width in [1152,1280]:
        p=folder/str(width);env=json.loads((p/'environment.json').read_text());text=(p/'engine.txt').read_text()
        require(env['exit_code']==0 and not any(token in text for token in ['ERROR:','SCRIPT ERROR','Parse Error']),'clean actual engine exit')
    return source

def video(path,mode,width):
    """Check each real MP4 and its independently decoded first frame."""
    path=Path(path);m=json.loads((path/(mode+'.json')).read_text());p=path/(mode+'.mp4')
    require(m['frames']==48 and m['fps']==10 and [m['width'],m['height']]==[width,width*9//16] and abs(m['duration']-4.8)<0.01,'complete video metadata')
    require(p.read_bytes()[4:8]==b'ftyp' and p.stat().st_size<8*1024*1024,'bounded actual MP4')
    a=Image.open(path/'frames'/mode/'0000.png').convert('RGB');b=Image.open(path/(mode+'.decoded.png')).convert('RGB')
    require(a.size==b.size and sum(ImageStat.Stat(ImageChops.difference(a,b)).mean)/3<6,'decoded video orientation/content')

def allowed_bounds(old,new):
    """Permit only moved foreground bodies and changed relative ordering of equal-root textures."""
    a=old['depths'][0]['trace'];b=new['depths'][0]['trace'];rects=[x['rect'] for x in b if x['phase']=='front' and x['kind']=='body']
    old_tex=[x for x in a if x['phase']=='front' and x['kind']=='texture'];new_tex=[x for x in b if x['phase']=='front' and x['kind']=='texture'];indices={x['key']:i for i,x in enumerate(old_tex)}
    for item in new_tex:
        if item['key'] not in indices:rects.append(item['rect'])
    for i,x in enumerate(new_tex):
        for y in new_tex[i+1:]:
            if x['key'] in indices and y['key'] in indices and indices[x['key']]>indices[y['key']]:rects.extend([x['rect'],y['rect']])
    return rects

def compare_pixels(old_image,new_image,old,new,width):
    """Check full RGBA outside actual moved plant bounds and exact HUD independently of any mask."""
    a=Image.open(old_image).convert('RGBA');b=Image.open(new_image).convert('RGBA');require(a.size==b.size==(width,width*9//16),'actual PNG dimensions')
    diff=ImageChops.difference(a,b);mask=Image.new('L',a.size);paint=ImageDraw.Draw(mask);factor=1.2*width/1152
    for x,y,w,h in allowed_bounds(old,new):
        left=math.floor((x-new['camera'][0])*factor)-2;top=math.floor((y-new['camera'][1])*factor)-2
        right=math.ceil((x+w-new['camera'][0])*factor)+2;bottom=math.ceil((y+h-new['camera'][1])*factor)+2
        paint.rectangle([left,top,right,bottom],fill=255)
    require(ImageChops.multiply(diff,Image.merge('RGBA',[ImageChops.invert(mask)]*4)).tobytes()==bytes(width*(width*9//16)*4),'unrelated pixels changed')
    if not new['editor']:
        s=width/1152
        for box in [(0,0,245,100),(912,0,1152,150),(0,568,1152,648)]:
            box=tuple(round(v*s) for v in box);require(a.crop(box).tobytes()==b.crop(box).tobytes(),'HUD changed')
    return a.tobytes()!=b.tobytes()

def verify(report=REPORT):
    """Verify baseline, exact flag-off rollback, real new dispatches and the six native videos."""
    report=Path(report);changes=json.loads((report/'changes.json').read_text());sources={phase:validate_source(report/'native'/phase,phase,changes) for phase in ['before','after']}
    for name in set(EXTRA)-{NEW}:require(sources['before']['sources'][name]==sources['after']['sources'][name],'same native QA overlay')
    result={'task':'VRENDER-006','base_commit':changes['base_commit'],'plant_depth_enabled':True,'performance_eligible':False,'full_map_accepted':False,'windows':{}}
    for width in [1152,1280]:
        before=capture(report/'native/before'/str(width));after=capture(report/'native/after'/str(width));validate_rows(before,'before',width);validate_rows(after,'after',width)
        video(report/'native/before'/str(width),'legacy',width)
        for mode in ['legacy','enabled']:video(report/'native/after'/str(width),mode,width)
        off=[r for r in after['rows'] if r['mode']=='legacy'];on=[r for r in after['rows'] if r['mode']=='enabled'];changed=[]
        for original,legacy,current in zip(before['rows'],off,on):
            for key in ['id','index','player','ground','world','camera','before','after','pause','storage','editor']:
                require(original[key]==legacy[key]==current[key],'full before/after state '+key+' '+original['id'])
            p=report/'native/before'/str(width)/original['image_file'];q=report/'native/after'/str(width)/legacy['image_file'];r=report/'native/after'/str(width)/current['image_file']
            require(Image.open(p).convert('RGBA').tobytes()==Image.open(q).convert('RGBA').tobytes(),'exact real legacy rollback')
            if compare_pixels(q,r,legacy,current,width):changed.append(original['index'])
        by={r['id']:r for r in on};p=report/'native/after'/str(width)
        require(Image.open(p/by['same-depth:a']['image_file']).tobytes()==Image.open(p/by['same-depth:b']['image_file']).tobytes(),'equal roots change pixels after reversed input order')
        require({6,10,14,15}<=set(changed),'new bush/crop/equal-root path was not visibly exercised')
        result['windows'][str(width)]={'before_png':48,'after_png':96,'draw_callbacks':288,'exact_legacy_pairs':48,'full_state_triples':48,'changed_enabled_frames':changed,'equal_root_pixels_stable':True,'single_dispatch':True,'queue_cleared':True,'videos':3}
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');args=parser.parse_args();result=verify()
    if args.write:(REPORT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))
