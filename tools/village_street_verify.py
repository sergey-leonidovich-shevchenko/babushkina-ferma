#!/usr/bin/env python3
"""Verify actual street substitutions, immutable gameplay and cardinal native galleries."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,gzip,hashlib,json,math,subprocess
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw
from tools.qa.performance.perf_contract_collect import ROOT,sha,write
from render_order import require,validate_draws
from village_street_assets import verify as verify_assets
from village_street_collect import ORIGINAL,EXTRA,STREET_ASSETS
from tools.common.launch import prepare_imports
prepare_imports(ROOT)
from tools.qa.world.source_inputs import historical_result
from tools.assets.alpha.alpha_audit import inspect as inspect_alpha
from tools.common.git import git_environment
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-003'
CASES=[kind+'-'+str(dx)+'-'+str(dy) for kind in ['well','cart'] for dx,dy in [(0,62),(0,-10),(-60,12),(60,12)]]+['bench-control','manual-pause','interior','returned']
GALLERIES=['gallery-'+kind+'-'+background for kind in ['well','cart'] for background in ['light','dark','grass','evening']]

def load(path):
    """Read an existing native witness without manufacturing missing data."""
    return json.loads(Path(path).read_text())

def reviewed_alpha(data=None):
    """Bind a manual limestone-highlight judgement to exact diagnostics and four native backgrounds."""
    data=load(REPORT/'alpha-review.json') if data is None else data
    require(data['task']=='VPROP-003' and data['manual_review'] and data['algorithm_unchanged'],'invalid manual alpha review')
    expected={'assets/game/locations/overworld/street_props/well_'+s+'_v1.png' for s in ['west','east']}
    require(set(data['assets'])==expected,'alpha review scope changed')
    for name,row in data['assets'].items():
        observed=json.loads(json.dumps(inspect_alpha(ROOT/name)))
        require(observed==row,'alpha review diagnostics changed')
    for name,digest in data['evidence'].items():require(sha(ROOT/name)==digest,'alpha review evidence changed')

def provenance(folder,phase):
    """Bind each archived source and every native file to its phase and real Git base."""
    data=load(folder/'source.json');require(data['complete'] and data['task']=='VPROP-003' and data['phase']==phase and data['performance_eligible'] is False,'incomplete phase')
    require(subprocess.run(['git','cat-file','-e',data['base_commit']+'^{commit}'],cwd=ROOT,env=git_environment(),capture_output=True).returncode==0,'missing base commit')
    expected=set(ORIGINAL+EXTRA)
    if phase=='before':expected-={'scripts/presentation/village_street_visual.gd'}
    else:expected|=set(STREET_ASSETS)
    require(set(data['sources'])==expected,'source coverage changed')
    for name,digest in data['sources'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/'inputs'/name)==digest,'archived source changed')
        overlay=name.startswith('tools/village_street') or (phase=='after' and (name in ['scripts/systems/village_prop_renderer.gd','assets/game/visual_resources.json','scripts/presentation/village_street_visual.gd'] or name.startswith('assets/game/locations/overworld/street_props/')))
        if not overlay:
            historical=historical_result(ROOT, data['base_commit'], name)
            require(historical.returncode==0 and hashlib.sha256(historical.stdout).hexdigest()==digest,'source does not match Git base')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and 'inputs' not in p.parts and p.name!='source.json'}
    require(actual==set(data['artifacts']),'native artifact coverage changed')
    for name,digest in data['artifacts'].items():require(sha(folder/name)==digest,'native artifact changed')
    if folder.resolve()==(REPORT/'native'/phase).resolve():
        files=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*files],cwd=ROOT,env=git_environment(),capture_output=True).returncode==0,'native proof missing from Git index')
    return data

def metadata(data,width,phase):
    """Reject a fullscreen override, lost focus, false FPS claim or changed gameplay."""
    require(data['task']=='VPROP-003' and data['phase']==phase and not data['errors'] and data['display']!='headless' and data['performance_eligible'] is False,'invalid native metadata')
    expected=CASES+(GALLERIES if phase=='after' else []);rows={r['id']:r for r in data['rows']}
    require(len(rows)==len(data['rows'])==len(expected) and set(rows)==set(expected),'native case coverage changed')
    for row in rows.values():
        require(row['window']==row['image']==[width,round(width*9/16)] and row['logical']==[1152,648] and row['focused'] and row['draws']==4,'wrong window, focus or actual draws')
        require(row['before']==row['after'],'native draw changed saved world')
        if row['location']=='overworld':
            expected=[{'kind':kind,'position':[x-row['camera'][0],y-row['camera'][1]]} for kind,x,y in [('well',1296,672),('cart',1512,576)]]
            require(row['street_anchors']==expected,'canonical prop anchor changed')
    require(rows['interior']['location']=='cottage_interior' and rows['returned']['location']=='overworld','real house transition missing')
    return rows

def changed_pixels(before,after,row,width):
    """Allow the substitution only inside the two measured street bounds, never HUD or terrain."""
    with Image.open(before) as a,Image.open(after) as b:
        a,b=a.convert('RGBA'),b.convert('RGBA');require(a.size==b.size==(width,round(width*9/16)),'wrong image dimensions')
        diff=ImageChops.difference(a,b);changed=ImageChops.lighter(ImageChops.lighter(diff.getchannel('R'),diff.getchannel('G')),ImageChops.lighter(diff.getchannel('B'),diff.getchannel('A')))
        count=sum(v!=0 for v in changed.getdata())
        if row['location']!='overworld':require(count==0,'control interior pixels changed');return count
        allowed=Image.new('L',a.size);draw=ImageDraw.Draw(allowed);factor=width/1152*1.2
        geometry=load(REPORT/'source.json')['views']
        for entry in row['street_anchors']:
            kind=entry['kind'];x,y=entry['position'];y+=24
            prop=geometry[kind+'-south'];w,h=prop['pixels'];ax,ay=prop['anchor']
            bounds=[min(-60,-ax*.25)-12,min(-120 if kind=='well' else -96,-ay*.25)-12,
                    max(60,(w-ax)*.25)+12,max(0,(h-ay)*.25)+12]
            draw.rectangle((math.floor((x+bounds[0])*factor),math.floor((y+bounds[1])*factor),math.ceil((x+bounds[2])*factor),math.ceil((y+bounds[3])*factor)),fill=255)
        require(ImageChops.subtract(changed,allowed).getbbox() is None,'pixels outside street bounds changed')
        if row['id'] not in ['manual-pause']:require(count>25,'street substitution produced no visible change')
        return count

def verify():
    """Check source control, exact before/after bounds and all genuine gallery callbacks."""
    verify_assets();reviewed_alpha();sources={p:provenance(REPORT/'native'/p,p) for p in ['before','after']}
    require(sources['before']['base_commit']==sources['after']['base_commit'],'phase bases differ')
    allowed={'scripts/systems/village_prop_renderer.gd','assets/game/visual_resources.json'}
    for name,digest in sources['before']['sources'].items():
        if name not in allowed and not name.startswith('tools/village_street'):require(sources['after']['sources'].get(name)==digest,'unrelated source changed: '+name)
    result={'task':'VPROP-003','base_commit':sources['before']['base_commit'],'performance_eligible':False,'props':['well','cart'],'directions':['south','west','east'],'normal_render_scale':.25,'windows':{}}
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
                    for d in witnesses:require(d['before']==d['after']==row['before'] and d['root_material_equal'] and d['own_material_equal'] and d['kind']==name.split('-')[1] and d['contact_counts']==([1,1,1] if d['kind']=='well' else [2,2,2]),'gallery changed save/material/contacts')
                    callbacks+=len(witnesses)
        for name in CASES:
            before,after=captures['before'][name],captures['after'][name]
            for key in ['before','player','camera','location','street_anchors']:require(before[key]==after[key],'same-camera or gameplay comparison changed: '+key)
            changes[name]=changed_pixels(REPORT/'native/before'/str(width)/(name+'.png'),REPORT/'native/after'/str(width)/(name+'.png'),after,width)
        colors=[]
        for name in GALLERIES:
            with Image.open(REPORT/'native/after'/str(width)/(name+'.png')) as im:colors.append(im.convert('RGBA').getpixel((2,2)))
        require(len(set(colors))==4,'four contrast backgrounds reused one frame')
        result['windows'][str(width)]={'before_png':12,'after_png':20,'draw_callbacks':callbacks,'changed_pixels':changes,'outside_street_equal':True,'gallery_backgrounds':4,'gallery_props':2,'visible_and_occluded_contacts_documented':True}
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');args=parser.parse_args();result=verify()
    if args.write:write(REPORT/'summary.json',result)
    print(json.dumps(result,ensure_ascii=False,indent=2))
