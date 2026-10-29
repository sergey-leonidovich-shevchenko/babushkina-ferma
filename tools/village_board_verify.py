#!/usr/bin/env python3
"""Verify five first-map notice/sign placements and six-locale native evidence."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,gzip,hashlib,json,math,subprocess
from common.git import git_environment
from pathlib import Path
from tools.qa.world.source_inputs import historical_result
from PIL import Image,ImageChops,ImageDraw
from tools.qa.performance.perf_contract_collect import ROOT,sha,write
from render_order import require,validate_draws
from village_board_assets import verify as verify_assets
from village_board_collect import ORIGINAL,EXTRA,FENCE_ASSETS
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-006'
LOCALES=['ru','en','es','de','fr','zh']
PORTS={'right':(2232,672),'top':(1560,192),'bottom':(1200,1248)}
CASES=[f'board-{x}-{dx}-{dy}' for x in [648,1656] for dx,dy in [(0,62),(0,-10),(-60,12),(60,12)]]+[f'sign-{p}-{l}' for l in LOCALES for p in PORTS]+['manual-pause','interior','market-control','returned','fence-control']
GALLERIES=['gallery-'+kind+'-'+bg for kind in ['board','sign'] for bg in ['light','dark','grass','evening']]
CHANGED={'scripts/systems/village_prop_renderer.gd','scripts/presentation/village_region_renderer.gd','assets/game/visual_resources.json','scripts/presentation/village_board_visual.gd'}

def load(path):
    """Read actual archived data without manufacturing a missing witness."""
    return json.loads(Path(path).read_text())

def provenance(folder,phase):
    """Bind each archived source and every native file to its phase and real Git base."""
    data=load(folder/'source.json');require(data['complete'] and data['task']=='VPROP-006' and data['phase']==phase and data['performance_eligible'] is False,'incomplete phase')
    require(subprocess.run(['git','cat-file','-e',data['base_commit']+'^{commit}'],cwd=ROOT,capture_output=True, env=git_environment()).returncode==0,'missing base commit')
    expected=set(ORIGINAL+EXTRA)
    if phase=='before':expected-={'scripts/presentation/village_board_visual.gd'}
    else:expected|=set(FENCE_ASSETS)
    require(set(data['sources'])==expected,'source coverage changed')
    for name,digest in data['sources'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/'inputs'/name)==digest,'archived source changed')
        overlay=name.startswith('tools/village_board') or (phase=='after' and (name in list(CHANGED) or name.startswith('assets/game/locations/overworld/boards/')))
        if not overlay:
            historical=historical_result(ROOT, data['base_commit'], name)
            require(historical.returncode==0 and hashlib.sha256(historical.stdout).hexdigest()==digest,'source does not match Git base')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and 'inputs' not in p.parts and p.name!='source.json'}
    require(actual==set(data['artifacts']),'native artifact coverage changed')
    for name,digest in data['artifacts'].items():require(sha(folder/name)==digest,'native artifact changed')
    if folder.resolve()==(REPORT/'native'/phase).resolve():
        files=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*files],cwd=ROOT,capture_output=True, env=git_environment()).returncode==0,'native proof missing from Git index')
    return data

def metadata(data,width,phase):
    """Require all five placements, six real locales, physical windows and identical snapshots."""
    require(data['task']=='VPROP-006' and data['phase']==phase and not data['errors'] and data['display']!='headless' and data['performance_eligible'] is False,'invalid native phase')
    expected=CASES+(GALLERIES if phase=='after' else []);rows={r['id']:r for r in data['rows']}
    require(set(rows)==set(expected) and len(rows)==len(data['rows']),'missing or duplicated case')
    for row in rows.values():
        require(row['window']==row['image']==[width,round(width*9/16)] and row['logical']==[1152,648] and row['focused'] and row['draws']==4,'wrong physical window, focus or draws')
        require(row['before']==row['after'],'board draw mutated complete save')
        require(not row['normal_effects'] and row['weather']=='clear','different reference/weather configuration')
        locale=row['id'].split('-')[-1] if row['id'].startswith('sign-') else 'ru'
        require(row['locale']==locale,'wrong live locale')
    require(rows['interior']['location']=='cottage_interior' and rows['market-control']['location']=='village_market' and rows['returned']['location']=='overworld','missing actual location controls')
    return rows

def prop_rect(row,kind,ground):
    """Project measured pixel dimensions and anchor with the same fixed0.25 density as runtime."""
    p=load(REPORT/'source.json')['views'][kind+'-south'];w,h=p['pixels'];ax,ay=p['anchor'];x,y=ground
    return [x-ax*.25,y-ay*.25,x+(w-ax)*.25,y+(h-ay)*.25]

def placements():
    """Use the original two boards and three real route ports; never invent extra scenery."""
    return [('board',(648,600)),('board',(1656,552))]+[('sign',(x,y-24)) for x,y in PORTS.values()]

def changed_pixels(before,after,row,width):
    """Bound allowed changes to old/new five silhouettes and small contact shadows."""
    with Image.open(before) as a,Image.open(after) as b:
        a,b=a.convert('RGBA'),b.convert('RGBA');require(a.size==b.size==(width,round(width*9/16)),'wrong readback size')
        diff=ImageChops.difference(a,b);changed=ImageChops.lighter(ImageChops.lighter(diff.getchannel('R'),diff.getchannel('G')),ImageChops.lighter(diff.getchannel('B'),diff.getchannel('A')))
        count=sum(v!=0 for v in changed.getdata())
        if row['id'] in ['interior','market-control','fence-control']:require(count==0,'unrelated control pixels changed');return count
        mask=Image.new('L',a.size);draw=ImageDraw.Draw(mask);scale=width/1152*1.2;cx,cy=row['camera']
        for kind,ground in placements():
            x,y=ground;r=prop_rect(row,kind,ground);old_y=y+(4 if kind=='sign' else 0)
            bounds=[min(x-60,r[0])-12,min(old_y-96,r[1])-12,max(x+60,r[2])+12,max(old_y,r[3])+12]
            draw.rectangle((math.floor((bounds[0]-cx)*scale),math.floor((bounds[1]-cy)*scale),math.ceil((bounds[2]-cx)*scale),math.ceil((bounds[3]-cy)*scale)),fill=255)
        require(ImageChops.subtract(changed,mask).getbbox() is None,'pixels outside five prop bounds changed')
        require(count>0,'notice/sign replacement is a no-op')
        return count

def locale_bodies(folder,rows,width):
    """Require identical body crops for all six languages while live labels vary below them."""
    scale=width/1152*1.2;checks=0
    for port,(x,y) in PORTS.items():
        reference=None;camera=None
        for locale in LOCALES:
            row=rows['sign-'+port+'-'+locale];require(camera is None or camera==row['camera'],'locale changed camera');camera=row['camera']
            r=prop_rect(row,'sign',(x,y-24));cx,cy=camera
            box=(math.floor((r[0]-cx)*scale),math.floor((r[1]-cy)*scale),math.ceil((r[2]-cx)*scale),math.ceil((r[3]-cy)*scale))
            require(0<=box[0]<box[2]<=width and 0<=box[1]<box[3]<=round(width*9/16),'locale body crop outside frame')
            with Image.open(folder/('sign-'+port+'-'+locale+'.png')) as im:raw=im.convert('RGBA').crop(box).tobytes()
            if reference is None:reference=raw
            else:require(raw==reference,'locale altered blank sprite body');checks+=1
    return checks

def verify():
    """Tie actual renders to Git source, configuration, glyph-independent bodies and real callbacks."""
    verify_assets();sources={p:provenance(REPORT/'native'/p,p) for p in ['before','after']}
    require(sources['before']['base_commit']==sources['after']['base_commit'],'phase bases differ')
    for name,digest in sources['before']['sources'].items():
        if name not in CHANGED and not name.startswith('tools/village_board'):require(sources['after']['sources'].get(name)==digest,'unrelated source changed: '+name)
    result={'task':'VPROP-006','base_commit':sources['before']['base_commit'],'performance_eligible':False,'kinds':['board','sign'],'locales':LOCALES,'views':['south','west','east'],'windows':{}}
    for width in [1152,1280]:
        captures={p:metadata(load(REPORT/'native'/p/str(width)/'capture.json'),width,p) for p in sources};callbacks=0
        for phase in sources:
            folder=REPORT/'native'/phase/str(width)
            require(load(folder/'environment.json')['exit_code']==0 and not any(e in (folder/'engine.txt').read_text() for e in ['ERROR:','SCRIPT ERROR','Parse Error']),'native engine failure')
            for name,row in captures[phase].items():
                draws=json.loads(gzip.decompress((folder/(name+'-draws.json.gz')).read_bytes()));validate_draws(draws);callbacks+=len(draws)
                require(draws[0]['before']==row['before'],'draw is not tied to snapshot')
                if name in GALLERIES:
                    gallery=json.loads(gzip.decompress((folder/(name+'-gallery-draws.json.gz')).read_bytes()))
                    require(len(gallery)==4 and len({d['frame'] for d in gallery})==4,'missing real gallery callbacks');callbacks+=4
                    for d in gallery:
                        require(d['before']==d['after']==row['before'] and d['root_material_equal'] and d['own_material_equal'] and d['kind']==name.split('-')[1] and d['contact_counts']==([2,2,2] if d['kind']=='board' else [1,1,1]),'gallery changed world/material/contacts')
        changes={}
        for name in CASES:
            a,b=captures['before'][name],captures['after'][name]
            for key in ['before','player','camera','location','normal_effects','minutes','darkness','weather','locale']:require(a[key]==b[key],'paired configuration differs: '+key)
            changes[name]=changed_pixels(REPORT/'native/before'/str(width)/(name+'.png'),REPORT/'native/after'/str(width)/(name+'.png'),b,width)
        for kind in ['board','sign']:
            colors=[]
            for bg in ['light','dark','grass','evening']:
                with Image.open(REPORT/'native/after'/str(width)/('gallery-'+kind+'-'+bg+'.png')) as im:colors.append(im.convert('RGBA').getpixel((2,2)))
            require(len(set(colors))==4,'contrast backgrounds reused')
        checks=locale_bodies(REPORT/'native/after'/str(width),captures['after'],width)
        result['windows'][str(width)]={'before_png':31,'after_png':39,'draw_callbacks':callbacks,'changed_pixels':changes,'outside_props_equal':True,'gallery_backgrounds':4,'locale_body_equal':checks,'locale_route_cases':18}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');a=p.parse_args();result=verify()
    if a.write:write(REPORT/'summary.json',result)
    print(json.dumps(result,indent=2))
