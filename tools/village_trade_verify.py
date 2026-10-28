#!/usr/bin/env python3
"""Verify source-bound static market/sack captures, without claiming focus/input or performance."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,gzip,hashlib,json,math,subprocess
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw
from tools.qa.performance.perf_contract_collect import ROOT,sha,write
from render_order import require,validate_draws
from village_trade_assets import verify as verify_assets
from village_trade_collect import ORIGINAL,EXTRA,TRADE_ASSETS
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-007'
SLOTS=[(600,576),(1032,312),(2064,624),(1896,456),(2160,672)]
CASES=['market-0-72','market-0--12','market--80-12','market-80-12']+[f'sack-{i}-{state}' for i in range(5) for state in ['closed','opened']]+['event-festival-control','event-traveler-control','event-raid-control','shop-control','sale-control','bridge-west','bridge-east','manual-pause','interior','market-control','returned']
KINDS=['stall','crate','barrel','sack']
GALLERIES=['gallery-'+kind+'-'+bg for kind in KINDS for bg in ['light','dark','grass','evening']]
CHANGED={'scripts/systems/village_event_renderer.gd','scripts/systems/world_loot_renderer.gd','scripts/systems/render_system.gd','assets/game/visual_resources.json','scripts/presentation/village_trade_visual.gd'}

def load(path):
    """Read archived evidence; missing data is never synthesized."""
    return json.loads(Path(path).read_text())

def provenance(folder,phase):
    """Bind every source and capture to the real Git base and its exact phase."""
    data=load(folder/'source.json');require(data['complete'] and data['task']=='VPROP-007' and data['phase']==phase and data['performance_eligible'] is False,'incomplete phase')
    require(subprocess.run(['git','cat-file','-e',data['base_commit']+'^{commit}'],cwd=ROOT,capture_output=True).returncode==0,'missing base commit')
    expected=set(ORIGINAL+EXTRA)
    if phase=='before':expected-={'scripts/presentation/village_trade_visual.gd'}
    else:expected|=set(TRADE_ASSETS)
    require(set(data['sources'])==expected,'source coverage changed')
    for name,digest in data['sources'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/'inputs'/name)==digest,'archived source changed')
        overlay=name.startswith('tools/village_trade') or (phase=='after' and (name in CHANGED or name.startswith('assets/game/locations/overworld/trade/')))
        if not overlay:
            historical=subprocess.run(['git','show',data['base_commit']+':'+name],cwd=ROOT,capture_output=True)
            require(historical.returncode==0 and hashlib.sha256(historical.stdout).hexdigest()==digest,'source does not match Git base: '+name)
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and 'inputs' not in p.parts and p.name!='source.json'}
    require(actual==set(data['artifacts']),'native artifact coverage changed')
    for name,digest in data['artifacts'].items():require(sha(folder/name)==digest,'native artifact changed')
    if folder.resolve()==(REPORT/'native'/phase).resolve():
        files=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*files],cwd=ROOT,capture_output=True).returncode==0,'native proof missing from Git index')
    return data

def metadata(data,width,phase):
    """Require visible native windows, real callbacks and exact saves; focus remains honestly reported."""
    require(data['task']=='VPROP-007' and data['phase']==phase and not data['errors'] and data['display']!='headless' and data['performance_eligible'] is False,'invalid native phase')
    expected=CASES+(GALLERIES if phase=='after' else []);rows={r['id']:r for r in data['rows']}
    require(set(rows)==set(expected) and len(rows)==len(data['rows']),'missing or duplicated case')
    for row in rows.values():
        require(row['window']==row['image']==[width,round(width*9/16)] and row['logical']==[1152,648] and row['visible'] and row['draws']==4,'wrong physical window, visibility or draws')
        require(type(row['focused']) is bool and row['focus_required'] is False,'focus contract missing')
        require(row['before']==row['after'],'trade draw mutated full save')
        require(not row['normal_effects'] and row['weather']=='clear' and row['locale']=='ru','different reference configuration')
    require(rows['interior']['location']=='cottage_interior' and rows['market-control']['location']=='village_market' and rows['returned']['location']=='overworld','missing actual location controls')
    return rows

def rectangles():
    """Bound changes to the old market composite and the new dry modules plus old/new sack bodies/labels."""
    source=load(REPORT/'source.json')['views'];result=[[1050,640,1210,810]]
    placements=[('stall',(1152,720),1),('crate',(1104,720),1),('barrel',(1200,720),1),('sack',(1176,720),.5)]+[('sack',(x,y+12),1) for x,y in SLOTS]
    for kind,(x,y),scale in placements:
        r=source[kind+'-south'];w,h=r['pixels'];ax,ay=r['anchor'];factor=.25*scale
        result.append([x-ax*factor-30,y-ay*factor-12,x+(w-ax)*factor+30,y+(h-ay)*factor+12])
    for x,y in SLOTS:result.append([x-65,y-42,x+65,y+42])
    return result

def changed_pixels(before,after,row,width):
    """Reject HUD/terrain/unrelated mutations outside small explicit prop rectangles."""
    with Image.open(before) as a,Image.open(after) as b:
        a,b=a.convert('RGBA'),b.convert('RGBA');require(a.size==b.size==(width,round(width*9/16)),'wrong readback size')
        diff=ImageChops.difference(a,b);changed=ImageChops.lighter(ImageChops.lighter(diff.getchannel('R'),diff.getchannel('G')),ImageChops.lighter(diff.getchannel('B'),diff.getchannel('A')))
        count=sum(v!=0 for v in changed.getdata())
        if row['id'] in ['interior','market-control']:require(count==0,'unrelated control changed');return count
        mask=Image.new('L',a.size);draw=ImageDraw.Draw(mask);scale=width/1152*1.2;cx,cy=row['camera']
        for r in rectangles():draw.rectangle((math.floor((r[0]-cx)*scale),math.floor((r[1]-cy)*scale),math.ceil((r[2]-cx)*scale),math.ceil((r[3]-cy)*scale)),fill=255)
        require(ImageChops.subtract(changed,mask).getbbox() is None,'pixels outside trade bounds changed')
        if row['id'].startswith(('market-0','market--','market-80','sack-')) or row['id'] in ['manual-pause','returned']:require(count>0,'trade replacement is a no-op')
        return count

def verify():
    """Check Git provenance, two-window before/after, every gallery and full draw/save equality."""
    verify_assets();sources={p:provenance(REPORT/'native'/p,p) for p in ['before','after']}
    require(sources['before']['base_commit']==sources['after']['base_commit'],'phase bases differ')
    for name,digest in sources['before']['sources'].items():
        if name not in CHANGED and not name.startswith('tools/village_trade'):require(sources['after']['sources'].get(name)==digest,'unrelated source changed: '+name)
    result={'task':'VPROP-007','base_commit':sources['before']['base_commit'],'performance_eligible':False,'focus_required':False,'focus_scope':'static visible-window readbacks only; no native input, timing or FPS acceptance','kinds':KINDS,'views':['south','west','east'],'windows':{}}
    for width in [1152,1280]:
        captures={p:metadata(load(REPORT/'native'/p/str(width)/'capture.json'),width,p) for p in sources};callbacks=0
        for phase in sources:
            folder=REPORT/'native'/phase/str(width);require(load(folder/'environment.json')['exit_code']==0 and not any(e in (folder/'engine.txt').read_text() for e in ['ERROR:','SCRIPT ERROR','Parse Error']),'native engine failure')
            for name,row in captures[phase].items():
                draws=json.loads(gzip.decompress((folder/(name+'-draws.json.gz')).read_bytes()));validate_draws(draws);callbacks+=len(draws);require(draws[0]['before']==row['before'],'draw not tied to snapshot')
                if name in GALLERIES:
                    gallery=json.loads(gzip.decompress((folder/(name+'-gallery-draws.json.gz')).read_bytes()));require(len(gallery)==4 and len({d['frame'] for d in gallery})==4,'missing gallery callbacks');callbacks+=4
                    for d in gallery:require(d['before']==d['after']==row['before'] and d['root_material_equal'] and d['own_material_equal'] and d['kind']==name.split('-')[1] and d['contact_counts']==([2,2,2] if d['kind']=='stall' else [1,1,1]),'gallery changed world/material/contacts')
        changes={}
        for name in CASES:
            a,b=captures['before'][name],captures['after'][name]
            for key in ['before','player','camera','location','normal_effects','minutes','darkness','weather','locale']:require(a[key]==b[key],'paired configuration differs: '+key)
            changes[name]=changed_pixels(REPORT/'native/before'/str(width)/(name+'.png'),REPORT/'native/after'/str(width)/(name+'.png'),b,width)
        for kind in KINDS:
            colors=[]
            for bg in ['light','dark','grass','evening']:
                with Image.open(REPORT/'native/after'/str(width)/('gallery-'+kind+'-'+bg+'.png')) as im:colors.append(im.convert('RGBA').getpixel((2,2)))
            require(len(set(colors))==4,'contrast backgrounds reused')
        rows=list(captures['before'].values())+list(captures['after'].values())
        result['windows'][str(width)]={'before_png':len(CASES),'after_png':len(CASES)+len(GALLERIES),'draw_callbacks':callbacks,'changed_pixels':changes,'outside_props_equal':True,'gallery_backgrounds':4,'visible_frames':sum(r['visible'] for r in rows),'focused_frames':sum(r['focused'] for r in rows),'sack_slots':5,'real_openings':5}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');a=p.parse_args();result=verify()
    if a.write:write(REPORT/'summary.json',result)
    print(json.dumps(result,indent=2))
