#!/usr/bin/env python3
"""Verify the source-bound post-motion service, real windows, shader inputs and complete saves."""
import argparse,copy,gzip,hashlib,json,math,subprocess
from pathlib import Path
from PIL import Image,ImageChops,ImageStat
from post_motion_collect import ORIGINAL,EXTRA
ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'docs/reports/visual-overhaul/vrender-008'
CASES=[('walk',8),('wall',8),('tree',2),('bush',2),('bridge-west',2),('bridge-east',2),('returned',2),('pause',4),('inventory',2),('editor',2),('interior',2),('other-map',2),('returned',2)]
ORDER=[(name,tick) for name,count in CASES for tick in range(count)]
LOOP='scripts/core/game_loop.gd'
FRAME='scripts/presentation/post_motion_frame.gd'
OLD='\tpreload("res://scripts/presentation/village_ground_clock.gd").advance(game,delta)\n'
NEW='\tpreload("res://scripts/presentation/post_motion_frame.gd").publish(game,delta)\n'

def sha(path):
    """Bind original inputs, PNGs and encoded video to exact bytes."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def require(value,label):
    """Reject incomplete evidence instead of repairing it in a validation run."""
    if not value:raise ValueError(label)

def capture(path):
    """Read immutable, compressed full-save rows without creating a Godot scene."""
    return json.loads(gzip.decompress((Path(path)/'capture.json.gz').read_bytes()))

def close(a,b):
    """Only numeric shader/delta comparisons allow floating arithmetic tolerance."""
    return len(a)==len(b) and all(abs(x-y)<0.0001 for x,y in zip(a,b))

def expected_contact(row,phase):
    """Derive contact independently from the actual visible foot, never from held input."""
    if phase=='after' and (row['world']!='overworld' or row['editor']):return [0,0]
    delta=[a-b for a,b in zip(row['ground'],row['root'])];radius=row['radius']
    return [x/radius for x in delta] if math.hypot(*delta)<radius else [0,0]

def validate_rows(data,phase,width):
    """Verify every physical endpoint, frozen interval, actual draw and observed uniform."""
    require(data['task']=='VRENDER-008' and data['phase']==phase and not data['performance_eligible'],'capture identity')
    require(data['display']!='headless' and not data['errors'] and data['fixed_physics_hz']==30 and data['video_hz']==10,'native controlled capture')
    require(data['profile'].startswith('Codex-VRENDER-008-') and [(r['id'],r['tick']) for r in data['rows']]==ORDER,'complete ordered cases')
    size=[width,width*9//16]
    for index,row in enumerate(data['rows']):
        require(row['index']==index and row['image_file']==f'frames/{index:04d}.png','unique actual frame')
        require(row['window']==row['image']==size and row['logical']==[1152,648] and row['visible'] and row['focused'],'actual window/focus')
        require(row['before']==row['after'] and len(row['draws'])==2,'full save equality around two draws')
        require(all(d['equal'] and d['geometry_equal'] and d['before']==d['after']==row['before'] and d['queue_after']==0 for d in row['draws']),'production draw mutation/queue')
        require(len({d['process_frame'] for d in row['draws']})==2,'two distinct production callbacks')
        require(close(row['contact'],expected_contact(row,phase)) and close(row['contact'],row['shader_contact']),'real shader contact')
        paused=row['pause'] or row['inventory'] or row['editor']
        advance=(row['world'] if phase=='after' else row['start_world'])=='overworld' and not paused
        require(abs(row['seconds']-row['start_seconds']-(1/30 if advance else 0))<0.00001,'post-map visual clock delta')
        if row['id']=='wall':require(row['input']==[0,1] and row['start']==row['player'] and row['contact']==[0,0],'real blocked input must not reach far root')
        if row['id']=='walk':require(row['player'][0]>row['start'][0],'walk case actually moves')
        if row['id']=='pause':require(row['pause'],'actual manual pause')
        if row['id']=='inventory':require(row['inventory'],'actual inventory pause')
        if row['id']=='editor':require(row['editor'],'actual F12')
        if row['id']=='interior':require(row['world']=='cottage_interior' and row['before']['location']=='cottage_interior','actual automatic door')
        if row['id']=='other-map':require(row['world']=='village_market','actual neighbouring map')
        if phase=='after' and row['editor']:
            require(row['packet']=={},'editor cannot expose an active effects packet')
        elif phase=='after':
            value=row['packet']
            require(set(value)=={'world','player_world','seconds','active','read_only'} and value['read_only'],'bounded read-only packet')
            require(value['world']==row['world'] and value['player_world']==row['player'] and value['seconds']==row['seconds'],'post-collision/map packet')
            require(value['active']==(row['world']=='overworld'),'map effect scope')
        else:require(row['packet']=={},'baseline must not claim the new publisher')

def validate_source(folder,phase,manifest=None):
    """Require every archived input/artifact and the exact permitted production diff from Git."""
    folder=Path(folder);source=manifest if manifest is not None else json.loads((folder/'source.json').read_text())
    require(source['task']=='VRENDER-008' and source['phase']==phase and source['complete'] and not source['performance_eligible'],'source complete/identity')
    names=set(ORIGINAL+EXTRA)-({FRAME} if phase=='before' else set())
    require(set(source['sources'])==names,'complete source coverage')
    for name,digest in source['sources'].items():
        path=folder/'inputs'/name;require(path.is_file() and sha(path)==digest,'exact source '+name)
        if name in ORIGINAL:
            original=subprocess.check_output(['git','show',source['base_commit']+':'+name],cwd=ROOT)
            if name==LOOP and phase=='after':original=original.replace(OLD.encode(),b'').replace(b'\tpreload("res://scripts/systems/dropped_loot_system.gd").update(game,delta)\n',b'\tpreload("res://scripts/systems/dropped_loot_system.gd").update(game,delta)\n'+NEW.encode())
            require(path.read_bytes()==original,'only selected production change '+name)
    actual={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==source['artifacts'],'exact artifact list/hashes')
    for width in [1152,1280]:
        env=json.loads((folder/str(width)/'environment.json').read_text())
        require(env['exit_code']==0 and all(token not in (folder/str(width)/'engine.txt').read_text() for token in ['ERROR:','SCRIPT ERROR','Parse Error']),'clean native engine exit')
    return source

def validate_video(path,width,count):
    """Check the bounded MP4 and independently decoded first image against the actual PNG."""
    path=Path(path);meta=json.loads((path/'route.json').read_text());video=path/'route.mp4'
    require(meta['frames']==count and meta['fps']==10 and meta['width']==width and meta['height']==width*9//16 and abs(meta['duration']-count/10)<0.01,'complete video metadata')
    require(video.read_bytes()[4:8]==b'ftyp' and video.stat().st_size<8*1024*1024,'bounded real MP4')
    first=Image.open(path/'frames/0000.png').convert('RGB');decoded=Image.open(path/'route.decoded.png').convert('RGB')
    require(decoded.size==first.size and sum(ImageStat.Stat(ImageChops.difference(first,decoded)).mean)/3<6,'decoded video content/orientation')

def compare_rows(before,after):
    """All saved gameplay and geometry must match across two independent native routes."""
    for a,b in zip(before['rows'],after['rows']):
        for key in ['id','tick','index','start','start_world','player','ground','world','camera','root','radius','before','after','pause','inventory','editor','input']:
            require(a[key]==b[key],'before/after gameplay '+key+' '+str(a['index']))

def verify(report=REPORT):
    """Combine source, actual phases, image readbacks, videos and exact full snapshots."""
    report=Path(report);sources={phase:validate_source(report/'native'/phase,phase) for phase in ['before','after']}
    require(sources['before']['base_commit']==sources['after']['base_commit'],'same comparison base')
    for name in set(EXTRA)-{FRAME}:require(sources['before']['sources'][name]==sources['after']['sources'][name],'same QA overlay')
    result={'task':'VRENDER-008','base_commit':sources['before']['base_commit'],'production_publisher':True,'performance_eligible':False,'full_map_accepted':False,'windows':{}}
    for width in [1152,1280]:
        series={phase:capture(report/'native'/phase/str(width)) for phase in sources}
        for phase,data in series.items():
            validate_rows(data,phase,width);validate_video(report/'native'/phase/str(width),width,len(ORDER))
            for row in data['rows']:
                with Image.open(report/'native'/phase/str(width)/row['image_file']) as picture:require(picture.size==(width,width*9//16),'actual PNG dimensions')
        compare_rows(series['before'],series['after'])
        pairs=[]
        for a,b in zip(series['before']['rows'],series['after']['rows']):
            p=report/'native/before'/str(width)/a['image_file'];q=report/'native/after'/str(width)/b['image_file']
            pairs.append(Image.open(p).convert('RGBA').tobytes()==Image.open(q).convert('RGBA').tobytes())
        result['windows'][str(width)]={'before_png':len(ORDER),'after_png':len(ORDER),'draw_callbacks':len(ORDER)*4,'full_save_pairs':len(ORDER),'rgba_equal_pairs':sum(pairs),'rgba_total_pairs':len(pairs),'changed_image_indices':[i for i,equal in enumerate(pairs) if not equal],'videos':2,'shader_matches':True,'actual_wall_steps':8,'post_transition_frames':4}
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');args=parser.parse_args();result=verify()
    if args.write:(REPORT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))
