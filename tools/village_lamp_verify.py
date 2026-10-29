#!/usr/bin/env python3
"""Verify actual lamp substitutions, immutable gameplay and cardinal native galleries."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,gzip,hashlib,json,math,struct,subprocess
from common.git import git_environment
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw
from tools.qa.performance.perf_contract_collect import ROOT,sha,write
from render_order import require,validate_draws
from village_lamp_assets import verify as verify_assets
from village_lamp_collect import ORIGINAL,EXTRA,LAMP_ASSETS
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-004'
CASES=[f'lamp-{x}-{dx}-{dy}' for x in [768,1728] for dx,dy in [(0,62),(0,-10),(-60,12),(60,12)]]+['normal-day','normal-sunset','normal-night','normal-east-night','manual-pause','interior','returned','bench-control','street-control']
GALLERIES=['gallery-'+mode+'-'+background for mode in ['dry','lit'] for background in ['light','dark','grass','evening']]

def load(path):
    """Read an existing native witness without manufacturing missing data."""
    return json.loads(Path(path).read_text())

def f32(value):
    """Match Godot Vector2 component subtraction exactly rather than adding a broad position tolerance."""
    return struct.unpack('f',struct.pack('f',value))[0]

def provenance(folder,phase):
    """Bind each archived source and every native file to its phase and real Git base."""
    data=load(folder/'source.json');require(data['complete'] and data['task']=='VPROP-004' and data['phase']==phase and data['performance_eligible'] is False,'incomplete phase')
    require(subprocess.run(['git','cat-file','-e',data['base_commit']+'^{commit}'],cwd=ROOT,capture_output=True, env=git_environment()).returncode==0,'missing base commit')
    expected=set(ORIGINAL+EXTRA)
    if phase=='before':expected-={'scripts/presentation/village_lamp_visual.gd'}
    else:expected|=set(LAMP_ASSETS)
    require(set(data['sources'])==expected,'source coverage changed')
    for name,digest in data['sources'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/'inputs'/name)==digest,'archived source changed')
        overlay=name.startswith('tools/village_lamp') or (phase=='after' and (name in ['scripts/systems/village_prop_renderer.gd','scripts/systems/atmosphere_renderer.gd','assets/game/visual_resources.json','scripts/presentation/village_lamp_visual.gd'] or name.startswith('assets/game/locations/overworld/lamps/')))
        if not overlay:
            historical=subprocess.run(['git','show',data['base_commit']+':'+name],cwd=ROOT,capture_output=True, env=git_environment())
            require(historical.returncode==0 and hashlib.sha256(historical.stdout).hexdigest()==digest,'source does not match Git base')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and 'inputs' not in p.parts and p.name!='source.json'}
    require(actual==set(data['artifacts']),'native artifact coverage changed')
    for name,digest in data['artifacts'].items():require(sha(folder/name)==digest,'native artifact changed')
    if folder.resolve()==(REPORT/'native'/phase).resolve():
        files=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*files],cwd=ROOT,capture_output=True, env=git_environment()).returncode==0,'native proof missing from Git index')
    return data

def metadata(data,width,phase):
    """Reject a fullscreen override, lost focus, false FPS claim or changed gameplay."""
    require(data['task']=='VPROP-004' and data['phase']==phase and not data['errors'] and data['display']!='headless' and data['performance_eligible'] is False,'invalid native metadata')
    expected=CASES+(GALLERIES if phase=='after' else []);rows={r['id']:r for r in data['rows']}
    require(len(rows)==len(data['rows'])==len(expected) and set(rows)==set(expected),'native case coverage changed')
    for row in rows.values():
        require(row['window']==row['image']==[width,round(width*9/16)] and row['logical']==[1152,648] and row['focused'] and row['draws']==4,'wrong window, focus or actual draws')
        require(row['before']==row['after'],'native draw changed saved world')
        if row['location']=='overworld':
            expected=[[f32(x-row['camera'][0]),f32(y-row['camera'][1])] for x,y in [(768,552),(1728,672)]]
            actual=[[f32(v) for v in point] for point in row['lamp_anchors']]
            require(actual==expected,'canonical lamp anchor changed')
        normal=row['id'].startswith('normal-') or row['id']=='manual-pause'
        require(row['normal_effects']==normal and row['weather']=='clear','incorrect normal/reference effect mode or live weather')
    require(rows['normal-day']['minutes']==720 and rows['normal-day']['darkness']==0,'daylight control missing')
    require(rows['normal-sunset']['minutes']==1140 and abs(rows['normal-sunset']['darkness']-.31)<1e-6,'sunset control missing')
    require(rows['normal-night']['minutes']==1320 and abs(rows['normal-night']['darkness']-.62)<1e-6,'night control missing')
    require(rows['manual-pause']['minutes']==1320 and rows['manual-pause']['darkness']==rows['normal-night']['darkness'],'pause changed light clock')
    require(rows['interior']['location']=='cottage_interior' and rows['returned']['location']=='overworld','real house transition missing')
    return rows

def changed_pixels(before,after,row,width):
    """Allow the substitution only inside the two measured lamp bounds, never HUD or terrain."""
    with Image.open(before) as a,Image.open(after) as b:
        a,b=a.convert('RGBA'),b.convert('RGBA');require(a.size==b.size==(width,round(width*9/16)),'wrong image dimensions')
        diff=ImageChops.difference(a,b);changed=ImageChops.lighter(ImageChops.lighter(diff.getchannel('R'),diff.getchannel('G')),ImageChops.lighter(diff.getchannel('B'),diff.getchannel('A')))
        count=sum(v!=0 for v in changed.getdata())
        if row['location']!='overworld':require(count==0,'control interior pixels changed');return count
        if row['id']=='bench-control':require(count==0,'offscreen-lamp bench control changed');return count
        allowed=Image.new('L',a.size);draw=ImageDraw.Draw(allowed);factor=width/1152*1.2
        source=load(REPORT/'source.json');prop=source['views']['south'];w,h=prop['pixels'];ax,ay=prop['anchor'];ex,ey=prop['emitter']
        bounds=[min(-24,-ax*.25)-10,min(-120,-ay*.25)-10,max(24,(w-ax)*.25)+10,max(0,(h-ay)*.25)+10]
        for x,y in row['lamp_anchors']:
            y+=24
            draw.rectangle((math.floor((x+bounds[0])*factor),math.floor((y+bounds[1])*factor),math.ceil((x+bounds[2])*factor),math.ceil((y+bounds[3])*factor)),fill=255)
            if row['normal_effects'] and row['darkness']>0:
                for cx,cy,radius in [(x,y-62,43),(x+(ex-ax)*.25,y+(ey-ay)*.25,source['glow']['radii'][-1]+2)]:
                    draw.ellipse((math.floor((cx-radius)*factor),math.floor((cy-radius)*factor),math.ceil((cx+radius)*factor),math.ceil((cy+radius)*factor)),fill=255)
        require(ImageChops.subtract(changed,allowed).getbbox() is None,'pixels outside lamp bounds changed')
        if row['id'] not in ['manual-pause']:require(count>25,'lamp substitution produced no visible change')
        return count

def separated_glow(folder,width):
    """Compare actual dry/lit GPU boards: unchanged body region outside a bounded separate halo."""
    source=load(REPORT/'source.json');factor=width/1152*1.2;gains=[]
    for background in ['light','dark','grass','evening']:
        with Image.open(folder/('gallery-dry-'+background+'.png')) as a,Image.open(folder/('gallery-lit-'+background+'.png')) as b:
            a,b=a.convert('RGBA'),b.convert('RGBA');diff=ImageChops.difference(a,b)
            changed=ImageChops.lighter(ImageChops.lighter(diff.getchannel('R'),diff.getchannel('G')),ImageChops.lighter(diff.getchannel('B'),diff.getchannel('A')))
            mask=Image.new('L',a.size);draw=ImageDraw.Draw(mask)
            draw.rectangle((24*factor,10*factor,950*factor,40*factor),fill=255)
            for i,side in enumerate(['south','west','east']):
                prop=source['views'][side];ex=(prop['emitter'][0]-prop['anchor'][0])*.25;ey=(prop['emitter'][1]-prop['anchor'][1])*.25
                for row in [0,1]:
                    x=(192+i*288+ex)*factor;y=(224+row*252+ey)*factor;radius=(source['glow']['radii'][-1]+2)*factor
                    draw.ellipse((math.floor(x-radius),math.floor(y-radius),math.ceil(x+radius),math.ceil(y+radius)),fill=255)
                    roi=(math.floor(x-1.5*factor),math.floor(y-1.5*factor),math.ceil(x+1.5*factor),math.ceil(y+1.5*factor))
                    def luma(im):
                        pixels=list(im.crop(roi).getdata());return sum(.2126*p[0]+.7152*p[1]+.0722*p[2] for p in pixels)/len(pixels)
                    gains.append(luma(b)-luma(a))
            require(ImageChops.subtract(changed,mask).getbbox() is None,'dry/lit difference outside separate glow and mode caption')
    require(min(gains)>5,'separate glow did not illuminate the measured pane')
    return {'pane_samples':len(gains),'minimum_luma_gain':min(gains),'body_outside_glow_equal':True}

def verify():
    """Check source control, exact before/after bounds and all genuine gallery callbacks."""
    verify_assets();sources={p:provenance(REPORT/'native'/p,p) for p in ['before','after']}
    require(sources['before']['base_commit']==sources['after']['base_commit'],'phase bases differ')
    allowed={'scripts/systems/village_prop_renderer.gd','scripts/systems/atmosphere_renderer.gd','assets/game/visual_resources.json'}
    for name,digest in sources['before']['sources'].items():
        if name not in allowed and not name.startswith('tools/village_lamp'):require(sources['after']['sources'].get(name)==digest,'unrelated source changed: '+name)
    result={'task':'VPROP-004','base_commit':sources['before']['base_commit'],'performance_eligible':False,'props':['lamp'],'directions':['south','west','east'],'normal_render_scale':.25,'windows':{}}
    for width in [1152,1280]:
        captures={p:metadata(load(REPORT/'native'/p/str(width)/'capture.json'),width,p) for p in sources};changes={};callbacks=0
        for phase in sources:
            path=REPORT/'native'/phase/str(width)
            require(load(path/'environment.json')['exit_code']==0 and not any(t in (path/'engine.txt').read_text() for t in ['ERROR:','SCRIPT ERROR','Parse Error']),'native engine error')
            for name,row in captures[phase].items():
                draws=json.loads(gzip.decompress((path/(name+'-draws.json.gz')).read_bytes()));validate_draws(draws);require(draws[0]['before']==row['before'],'draw witness is not tied to save');callbacks+=len(draws)
                if name in GALLERIES:
                    witnesses=json.loads(gzip.decompress((path/(name+'-gallery-draws.json.gz')).read_bytes()))
                    require(len(witnesses)==4 and len({d['frame'] for d in witnesses})==4,'missing real gallery callbacks')
                    for d in witnesses:require(d['before']==d['after']==row['before'] and d['root_material_equal'] and d['own_material_equal'] and d['lit']==(name.split('-')[1]=='lit') and len(d['emitters'])==3,'gallery changed save/material/contacts')
                    callbacks+=len(witnesses)
        for name in CASES:
            before,after=captures['before'][name],captures['after'][name]
            for key in ['before','player','camera','location','lamp_anchors']:require(before[key]==after[key],'same-camera or gameplay comparison changed: '+key)
            changes[name]=changed_pixels(REPORT/'native/before'/str(width)/(name+'.png'),REPORT/'native/after'/str(width)/(name+'.png'),after,width)
        colors=[]
        for name in GALLERIES:
            with Image.open(REPORT/'native/after'/str(width)/(name+'.png')) as im:colors.append(im.convert('RGBA').getpixel((2,2)))
        require(len(set(colors))==4,'four contrast backgrounds reused one frame')
        result['windows'][str(width)]={'before_png':17,'after_png':25,'draw_callbacks':callbacks,'changed_pixels':changes,'outside_lamp_equal':True,'gallery_backgrounds':4,'gallery_modes':['dry','lit'],'separate_glow':True,'glow_comparison':separated_glow(REPORT/'native/after'/str(width),width)}
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');args=parser.parse_args();result=verify()
    if args.write:write(REPORT/'summary.json',result)
    print(json.dumps(result,ensure_ascii=False,indent=2))
