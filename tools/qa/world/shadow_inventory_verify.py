#!/usr/bin/env python3
"""Verify immutable raster ownership and native on/off contact controls."""
import argparse,csv,hashlib,json,subprocess
from functools import lru_cache
from tools.common.git import git_environment
from pathlib import Path
from PIL import Image
from tools.qa.world.shadow_inventory import ROOT,REPORT,RULES

GROUPS={'single':['bench'],'street':['well','cart','lamp'],'boards':['board','sign'],'trade':['stall','crate','barrel','sack']}

def require(condition,message):
    """Fail a precise evidence boundary instead of silently accepting partial coverage."""
    if not condition:raise ValueError(message)

def load(path):
    """Read one archived JSON document."""
    return json.loads(path.read_text())

def digest(data):
    """Hash bytes without decoding native images or source blobs."""
    return hashlib.sha256(data).hexdigest()

@lru_cache(maxsize=1024)
def git(base,name):
    """Read the immutable accepted source, never a mutable current working file."""
    return subprocess.check_output(['git','show',base+':'+name],cwd=ROOT, env=git_environment())

def pixels(path):
    """Close every native image after decoding its complete RGBA payload."""
    with Image.open(path) as image:
        require(image.size==(768,256),'target size')
        return list(image.convert('RGBA').getdata())

def verify(report=REPORT):
    """Bind catalogue coverage, renderer owners and every full native on/off comparison."""
    report=Path(report);audit=load(report/'inventory.json');dependency=load(report/'dependency-audit.json');base=dependency['base_commit']
    require(audit['task']=='VSHADOW-001' and audit['base_commit']==base,'inventory base')
    for key in ['runtime_changed','dynamic_solar_implemented','performance_eligible','full_map_accepted']:require(audit[key] is False,'false acceptance: '+key)
    catalog=json.loads(git(base,'assets/game/visual_resources.json'));expected=set()
    for name,item in catalog['resources'].items():
        if name.startswith(('prop.village','part.village')):
            for view in item['views'].values():
                for v in view['variants'].values():expected.add(catalog['textures'][v['texture']]['file'].removeprefix('res://'))
    tree=subprocess.check_output(['git','ls-tree','-r','--name-only',base],cwd=ROOT,text=True, env=git_environment()).splitlines()
    expected.update(n for n in tree if n.startswith('assets/game/buildings/exteriors/') and n.endswith('.png'))
    expected.update('assets/game/environment/'+n for n in ['village_ambient_atlas_v1.png','forest_tree_growth_atlas_v1.png','forest_tree.png','seasons/tree_spring.png','seasons/tree_summer.png','seasons/tree_autumn.png','seasons/tree_winter.png'])
    expected.add('assets/game/interiors/village_interior_atlas_v2.png')
    assets=audit['assets'];require(len(assets)==len(expected) and {r['file'] for r in assets}==expected,'raster coverage')
    for row in assets:
        require(digest(git(base,row['file']))==row['sha256'],'raster source: '+row['file'])
        require(row['material_shading']=='retain' and row['baked_contact'] and row['baked_solar'] and row['owner'] and row['decision'],'unowned raster')
    rules=audit['renderer_rules'];require([(r['file'],r['function']) for r in rules]==[(r[0],r[1]) for r in RULES],'renderer coverage')
    for row in rules:
        source=git(base,row['file']);require(digest(source)==row['sha256'],'owner source')
        require('func '+row['function']+'(' in source.decode().splitlines()[row['line']-1],'owner location')
    with (report/'inventory.csv').open(newline='') as stream:
        csv_rows=list(csv.DictReader(stream));require([r['file'] for r in csv_rows]==[r['file'] for r in assets] and [r['sha256'] for r in csv_rows]==[r['sha256'] for r in assets],'CSV differs')
    folder=report/'native';source=load(folder/'source.json')
    require(source['complete'] and source['task']=='VSHADOW-001' and source['base_commit']==base and source['performance_eligible'] is False,'incomplete native series')
    production=sorted(n for n in tree if n.startswith('scripts/') and n.endswith(('.gd','.gdshader')))
    require(source['production']==production,'production coverage')
    require(source['asset_tree']==subprocess.check_output(['git','rev-parse',base+':assets/game'],cwd=ROOT,text=True, env=git_environment()).strip(),'asset tree')
    for n in production+['main.tscn']:require(digest(git(base,n))==source['sources'][n],'production source: '+n)
    for n in source['overlay']:require(digest((folder/'inputs'/n).read_bytes())==source['sources'][n],'QA source')
    actual={str(p.relative_to(folder)):digest(p.read_bytes()) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==source['artifacts'],'artifact hashes')
    summary={'task':'VSHADOW-001','base_commit':base,'reviewed_png':len(assets),'renderer_owners':len(rules),'runtime_changed':False,'dynamic_solar_implemented':False,'performance_eligible':False,'full_map_accepted':False,'windows':{},'native_cases':0,'target_png':0,'window_png':0,'game_callbacks':0,'target_callbacks':0}
    baseline={}
    for width in [1152,1280]:
        target=folder/str(width);data=load(target/'capture.json');environment=load(target/'environment.json')
        require(data['task']=='VSHADOW-001' and not data['errors'] and data['display']!='headless' and data['static_only'] and data['dynamic_solar_implemented'] is False and data['performance_eligible'] is False,'native admission')
        require(data['profile'].startswith('Codex-VSHADOW-001-') and environment['exit_code']==0,'profile/exit')
        require(not any(v in (target/'engine.txt').read_text() for v in ['ERROR:','SCRIPT ERROR','Parse Error']),'engine error')
        cases=[(minutes,group) for minutes in [720,1140] for group in GROUPS]
        require([(r['minutes'],r['group']) for r in data['rows']]==cases,'case coverage')
        metrics=[]
        for row in data['rows']:
            id=f"{int(row['minutes'])}-{row['group']}";require(row['id']==id and row['window']==[width,width*9//16] and row['logical']==[1152,648] and row['visible'] and isinstance(row['focused'],bool),'window/projection')
            game=row['game'];require(game['minutes']==row['minutes'] and game['world']=='overworld' and abs(game['zoom']-1.2)<1e-6 and game['before']==game['after'],'game preservation')
            require(game['before']['world_loot_seed']==20261015,'QA seed was reset')
            require(game['before']['game_minutes']==row['minutes'] if 'game_minutes' in game['before'] else game['before']['minutes']==row['minutes'],'actual calendar')
            require(len(game['draws'])==2 and all(d['equal'] and d['geometry_equal'] and d['before']==game['before'] and d['after']==game['after'] and d['queue_after']==0 for d in game['draws']),'actual game draw')
            require(game['draws'][0]['process_frame']<game['draws'][1]['process_frame'],'distinct game callbacks')
            state_key='game-'+str(row['minutes'])
            if state_key in baseline:require(game['before']==baseline[state_key],'whole game differs across group/window')
            else:baseline[state_key]=game['before']
            require([s['mode'] for s in row['samples']]==['shadow','plain','body'],'sample modes')
            geometry=None
            for sample in row['samples']:
                require(sample['size']==[768,256] and len(sample['records'])==2,'target callbacks')
                require(sample['records'][0]['process_frame']<sample['records'][1]['process_frame'],'distinct target callbacks')
                for frame in sample['records']:
                    require(frame['mode']==sample['mode'] and frame['group']==row['group'] and frame['minutes']==row['minutes'],'actual case')
                    require([r['kind'] for r in frame['rows']]==GROUPS[row['group']],'body coverage')
                    current=[]
                    for body in frame['rows']:
                        require(body['body_calls']==1 and body['shadow_calls']==(1 if sample['mode']=='shadow' else 0) and body['contact_points']>=1,'actual on/off dispatch')
                        x,y,w,h=body['destination'];require(x*1.2>=4 and y*1.2>=4 and (x+w)*1.2<=764 and (y+h)*1.2<=252,'cropped body')
                        current.append([body['kind'],body['ground'],body['destination'],body['contact_points']])
                    if geometry is None:geometry=current
                    require(current==geometry,'on/off geometry changed')
            on,off,body=[pixels(target/f'{id}-{mode}.png') for mode in ['shadow','plain','body']]
            changed=sum(a!=b for a,b in zip(on,off));core=sum(p[3]>=250 for p in body)
            require(changed>=80 and core>=500,'missing contact/body pixels')
            require(all(max(abs(a[i]-b[i]) for i in range(4))<=1 for a,b,p in zip(on,off,body) if p[3]>=250),'shadow toggle changed body core')
            require(all(a==b for a,b,p in zip(on,off,body) if p[3]==255),'shadow toggle changed opaque body')
            require(not any(body[x][3] or body[-768+x][3] for x in range(768)),'body touches vertical edge')
            key=row['group']
            if key in baseline:require(body==baseline[key],'body changes with calendar/window')
            else:baseline[key]=body
            for suffix in ['window','game']:
                with Image.open(target/f'{id}-{suffix}.png') as image:require(image.size==(width,width*9//16),'native framebuffer size')
            metrics.append({'id':id,'changed_contact_pixels':changed,'body_core_pixels_within_one_byte':core,'focused':row['focused']})
            summary['native_cases']+=1;summary['target_png']+=3;summary['window_png']+=2;summary['game_callbacks']+=2;summary['target_callbacks']+=6
        summary['windows'][str(width)]=metrics
    return summary

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path,default=REPORT);parser.add_argument('--write',action='store_true');args=parser.parse_args();result=verify(args.report)
    if args.write:(args.report/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
