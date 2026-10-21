#!/usr/bin/env python3
"""Verify exact native fence changes, source coverage and unchanged gameplay/HUD."""
import argparse,gzip,hashlib,json,math,subprocess
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw
from perf_contract_collect import ROOT,sha,write
from render_order import require,validate_draws
from village_fence_assets import verify as verify_assets
from village_fence_collect import ORIGINAL,EXTRA,FENCE_ASSETS
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-005'
CASES=['farm-nw','farm-ne','farm-south','gap-north','gap-east','pens']+[f'gate-{o}-{s}' for o in [0,1] for s in ['false','true']]+['interior','street-control']
GALLERIES=['gallery-'+bg for bg in ['light','dark','grass','evening']]
CHANGED={'scripts/systems/village_prop_renderer.gd','scripts/systems/village_terrain_renderer.gd','scripts/systems/livestock_renderer.gd','scripts/systems/fence_renderer.gd','scripts/systems/render_system.gd','assets/game/visual_resources.json','scripts/presentation/village_fence_visual.gd'}

def load(path):
    """Read actual evidence; never synthesize a missing phase."""
    return json.loads(Path(path).read_text())

def provenance(folder,phase):
    """Bind each archived source and every native file to its phase and real Git base."""
    data=load(folder/'source.json');require(data['complete'] and data['task']=='VPROP-005' and data['phase']==phase and data['performance_eligible'] is False,'incomplete phase')
    require(subprocess.run(['git','cat-file','-e',data['base_commit']+'^{commit}'],cwd=ROOT,capture_output=True).returncode==0,'missing base commit')
    expected=set(ORIGINAL+EXTRA)
    if phase=='before':expected-={'scripts/presentation/village_fence_visual.gd'}
    else:expected|=set(FENCE_ASSETS)
    require(set(data['sources'])==expected,'source coverage changed')
    for name,digest in data['sources'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/'inputs'/name)==digest,'archived source changed')
        overlay=name.startswith('tools/village_fence') or (phase=='after' and (name in list(CHANGED) or name.startswith('assets/game/locations/overworld/fences/')))
        if not overlay:
            historical=subprocess.run(['git','show',data['base_commit']+':'+name],cwd=ROOT,capture_output=True)
            require(historical.returncode==0 and hashlib.sha256(historical.stdout).hexdigest()==digest,'source does not match Git base')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and 'inputs' not in p.parts and p.name!='source.json'}
    require(actual==set(data['artifacts']),'native artifact coverage changed')
    for name,digest in data['artifacts'].items():require(sha(folder/name)==digest,'native artifact changed')
    if folder.resolve()==(REPORT/'native'/phase).resolve():
        files=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*files],cwd=ROOT,capture_output=True).returncode==0,'native proof missing from Git index')
    return data

def metadata(data,width,phase):
    """Require two true window sizes, focus, complete cases and unchanged full snapshots."""
    require(data['task']=='VPROP-005' and data['phase']==phase and not data['errors'] and data['display']!='headless' and data['performance_eligible'] is False,'invalid native phase')
    expected=CASES+(GALLERIES if phase=='after' else []);rows={r['id']:r for r in data['rows']}
    require(set(rows)==set(expected) and len(rows)==len(data['rows']),'missing or duplicated native case')
    for row in rows.values():
        require(row['window']==row['image']==[width,round(width*9/16)] and row['logical']==[1152,648] and row['focused'] and row['draws']==4,'wrong physical window, focus or draw count')
        require(row['before']==row['after'],'fence draw mutated complete save')
        require(not row['normal_effects'] and row['weather']=='clear','different reference/weather configuration')
    require(rows['interior']['location']=='cottage_interior','real interior control absent')
    for o in [0,1]:
        for state in ['false','true']:
            values=rows[f'gate-{o}-{state}']['before']['estate']['expansion']['fences']
            require(len(values)==1 and values[0]['orientation']==o and values[0]['open']==(state=='true'),'wrong real gate fixture state')
    return rows

def fences(row):
    """Return exact fixed farm cells and thin pen wall strips; leave their gate gaps open."""
    result=[]
    for x,y,w,h in [(4,32,4,1),(12,32,11,1),(4,33,1,13),(22,33,1,5),(22,42,1,4),(5,45,17,1)]:
        for cy in range(y,y+h):
            for cx in range(x,x+w):result.append((cx*24-8,cy*24-36,(cx+1)*24+8,(cy+1)*24+12))
    for x,y,w,h,gx,gy in [(720,936,192,144,908,1008),(624,1104,288,144,908,1176),(984,1128,288,120,980,1176)]:
        walls=[(x-4,y-4,x+w+4,y+4),(x-4,y+h-4,x+w+4,y+h+4)]
        for sx in [x-4,x+w-4]:
            if sx==gx:walls.extend([(sx,y+4,sx+8,gy),(sx,gy+48,sx+8,y+h-4)])
            else:walls.append((sx,y+4,sx+8,y+h-4))
        for a,b,c,d in walls:result.append((a-10,b-36,c+10,d+10))
    for gate in row['before']['estate'].get('expansion',{}).get('fences',[]):
        x,y=gate['cell'];x=x*24+(24 if gate['orientation']==0 else 12);y=y*24+(12 if gate['orientation']==0 else 24)
        result.append((x-82,y-82,x+48,y+48))
    return result

def changed_pixels(before,after,row,width):
    """Permit only bounded fence artwork; detect changes to HUD, terrain and offscreen controls."""
    with Image.open(before) as a,Image.open(after) as b:
        a,b=a.convert('RGBA'),b.convert('RGBA');require(a.size==b.size==(width,round(width*9/16)),'wrong readback size')
        diff=ImageChops.difference(a,b);changed=ImageChops.lighter(ImageChops.lighter(diff.getchannel('R'),diff.getchannel('G')),ImageChops.lighter(diff.getchannel('B'),diff.getchannel('A')))
        count=sum(v!=0 for v in changed.getdata())
        if row['id']=='interior':require(count==0,'unrelated control changed');return count
        mask=Image.new('L',a.size);draw=ImageDraw.Draw(mask);scale=width/1152*1.2;cx,cy=row['camera']
        for x,y,r,bottom in fences(row):draw.rectangle((math.floor((x-cx)*scale),math.floor((y-cy)*scale),math.ceil((r-cx)*scale),math.ceil((bottom-cy)*scale)),fill=255)
        require(ImageChops.subtract(changed,mask).getbbox() is None,'pixels outside fence bounds changed')
        require(count>0,'fence replacement is a no-op')
        return count

def verify():
    """Bind paired screenshots and draw witnesses to committed baseline source and configuration."""
    verify_assets();sources={p:provenance(REPORT/'native'/p,p) for p in ['before','after']}
    require(sources['before']['base_commit']==sources['after']['base_commit'],'phase base differs')
    for name,digest in sources['before']['sources'].items():
        if name not in CHANGED and not name.startswith('tools/village_fence'):require(sources['after']['sources'].get(name)==digest,'unrelated source changed: '+name)
    result={'task':'VPROP-005','base_commit':sources['before']['base_commit'],'performance_eligible':False,'scope':'original farm perimeter, pen walls, existing oak player fences on overworld only','windows':{}}
    for width in [1152,1280]:
        captures={p:metadata(load(REPORT/'native'/p/str(width)/'capture.json'),width,p) for p in sources};callbacks=0
        for phase in sources:
            folder=REPORT/'native'/phase/str(width)
            require(load(folder/'environment.json')['exit_code']==0 and not any(e in (folder/'engine.txt').read_text() for e in ['ERROR:','SCRIPT ERROR','Parse Error']),'native engine failure')
            for name,row in captures[phase].items():
                draws=json.loads(gzip.decompress((folder/(name+'-draws.json.gz')).read_bytes()));validate_draws(draws);callbacks+=len(draws)
                require(draws[0]['before']==row['before'],'draw not tied to snapshot')
                if name in GALLERIES:
                    gallery=json.loads(gzip.decompress((folder/(name+'-gallery-draws.json.gz')).read_bytes()))
                    require(len(gallery)==4 and all(d=={'background':name.removeprefix('gallery-'),'masks':16,'gates':4} for d in gallery),'missing real gallery draws');callbacks+=4
        changes={}
        for name in CASES:
            a,b=captures['before'][name],captures['after'][name]
            for key in ['before','player','camera','location','normal_effects','minutes','darkness','weather']:require(a[key]==b[key],'paired configuration differs: '+key)
            changes[name]=changed_pixels(REPORT/'native/before'/str(width)/(name+'.png'),REPORT/'native/after'/str(width)/(name+'.png'),b,width)
        colors=[]
        for name in GALLERIES:
            with Image.open(REPORT/'native/after'/str(width)/(name+'.png')) as im:colors.append(im.convert('RGBA').getpixel((2,2)))
        require(len(set(colors))==4,'contrast backgrounds reused')
        result['windows'][str(width)]={'before_png':12,'after_png':16,'draw_callbacks':callbacks,'changed_pixels':changes,'outside_fence_equal':True,'gallery_backgrounds':4,'all_masks':16,'gate_states':4}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');a=p.parse_args();result=verify()
    if a.write:write(REPORT/'summary.json',result)
    print(json.dumps(result,indent=2))
