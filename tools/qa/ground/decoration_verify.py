#!/usr/bin/env python3
"""Validate bounded decoration policy and source-bound native controls, never FPS."""
if not __package__:
    from tools.common.launch import prepare_imports
    from tools.common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse
import gzip
import hashlib
import json
import math
import subprocess
from tools.common.git import git_environment
from pathlib import Path
from tools.qa.world.source_inputs import historical_result
from PIL import Image, ImageChops, ImageDraw
from tools.qa.ground.decoration_collect import ROOT, SOURCES, OVERLAY
from tools.qa.performance.perf_contract_collect import sha, write
from tools.qa.world.render_order import require, validate_draws

REPORT = ROOT/'docs/reports/visual-overhaul/vground-008'
CASES = ['cottage','services','farm','bridge-west','bridge-east','road-turn','road-end',
         'summer','autumn','winter','rain','interior','returned']
MODES = ['control-before','before','after','control-after']
# In retained series A the game keeps its rain cache through the house transition,
# while WorldBackground resets its own weather field. That field is not an atmosphere clock.
# These three cases get full-save/geometry checks only; never infer equality from bg.weather.
SNAPSHOT_ONLY = ['rain','interior','returned']


def load(path):
    """Read exact recorded data, without modifying it."""
    return json.loads(Path(path).read_text())


def intersects(a,b):
    """Inclusive axis intersection includes touches at the reserved boundary."""
    return a[0]<=b[0]+b[2] and a[0]+a[2]>=b[0] and a[1]<=b[1]+b[3] and a[1]+a[3]>=b[1]


def cross(a,b,c):
    """Signed area for an independent segment-intersection test."""
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def point_inside(p,polygon):
    """Ray crossing for the exact saved river/pond polygon, not an AABB or corner-only sample."""
    inside=False
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]: inside=not inside
    return inside


def water_overlap(rect,polygon):
    """Detect containment and crossing edges even when all four corners are on dry ground."""
    x,y,w,h=rect; box=[[x,y],[x+w,y],[x+w,y+h],[x,y+h]]
    if any(point_inside(p,polygon) for p in box): return True
    if any(x<=p[0]<=x+w and y<=p[1]<=y+h for p in polygon): return True
    for a,b in zip(box,box[1:]+box[:1]):
        for c,d in zip(polygon,polygon[1:]+polygon[:1]):
            if cross(a,b,c)*cross(a,b,d)<=0 and cross(c,d,a)*cross(c,d,b)<=0:
                if max(min(a[0],b[0]),min(c[0],d[0]))<=min(max(a[0],b[0]),max(c[0],d[0])) and max(min(a[1],b[1]),min(c[1],d[1]))<=min(max(a[1],b[1]),max(c[1],d[1])): return True
    return False


def policy(data):
    """Independently re-evaluate every complete footprint against the recorded real map."""
    require(data['margin']==4 and data['limit']==512 and data['world']==[2400,1368],'policy bounds differ')
    require(0<len(data['zones'])<256 and 200<len(data['candidates'])<=512 and len(data['water'])==2,'bounded map coverage differs')
    require({'door','approach','farm','bridge','road','manual'}<={r['reason'] for r in data['zones']},'protected category missing')
    accepted=[]; rejected=[]
    for row in data['candidates']:
        x,y,w,h=row['rect']; rect=[x-4,y-4,w+8,h+8]
        require(all(math.isfinite(v) for v in rect) and 0<w<=256 and 0<h<=256,'invalid seed geometry')
        reason='allowed'
        if rect[0]<0 or rect[1]<0 or rect[0]+rect[2]>2400 or rect[1]+rect[3]>1368: reason='boundary'
        else:
            for zone in data['zones']:
                if intersects(rect,zone['rect']): reason=zone['reason']; break
            if reason=='allowed' and any(water_overlap(rect,p) for p in data['water']): reason='water'
        require(row['reason']==reason,'independent footprint classification differs')
        (accepted if reason=='allowed' else rejected).append(row)
    require(len(accepted)==data['accepted'] and len(rejected)==data['rejected'] and accepted and rejected,'seed counts differ')
    return accepted,rejected


def metadata(data,width):
    """Reject wrong windows, missing cases, changed snapshots and ordinary-scene overclaims."""
    require(data['task']=='VGROUND-008' and not data['errors'] and data['display']!='headless','native collection failed')
    require(data['simulation_frozen'] and data['performance_eligible'] is False and data['gpu_time_ms'] is None,'unsupported performance claim')
    require(data['ordinary_scene_has_procedural_seed'] is False and data['diagnostic_overlay_only'] is True,'fallback presented as ordinary game')
    require(data.get('rain_pixel_equality_not_claimed',True) is True,'wall-clock precipitation limitation contradicted')
    window=[width,round(width*9/16)]; require(data['window']==window,'window differs')
    rows={r['id']:r for r in data['rows']}
    require(len(data['rows'])==len(rows)==len(CASES)*4 and set(rows)=={c+'-'+m for c in CASES for m in MODES},'case coverage differs')
    for row in rows.values():
        require(row['focused'] and row['physical']==row['readback']==window and row['logical']==[1152,648] and row['zoom']==1.2 and row['draws']==4,'focus/size/zoom/draw differs')
        require(row['diagnostic']==(row['mode'] in ['before','after'] and row['location']=='overworld'),'diagnostic layer differs')
    for case in CASES:
        for mode in MODES[1:]:
            for key in ['camera','player','location','season','weather','snapshot']:
                require(rows[case+'-control-before'][key]==rows[case+'-'+mode][key],'pair changed '+key)
    require([rows[c+'-after']['season'] for c in ['cottage','summer','autumn','winter']]==['spring','summer','autumn','winter'],'calendar seasons missing')
    require(rows['interior-after']['location']=='cottage_interior' and rows['returned-after']['location']=='overworld','actual house transition missing')
    return rows


def provenance(folder):
    """Bind immutable artifacts to archived inputs, their historical base, and the reviewed overlay."""
    source=load(folder/'source.json')
    require(source['task']=='VGROUND-008' and source['complete'] and source['performance_eligible'] is False,'incomplete source record')
    require(isinstance(source['static_coexistence'],bool) and isinstance(source['initial_jobs'],list) and (source['static_coexistence'] or not source['initial_jobs']),'process policy missing')
    require(set(source['sources'])==set(source['base_sources'])==set(SOURCES),'input coverage differs')
    for name,digest in source['sources'].items():
        require(sha(folder/'inputs'/name)==digest,'archived source changed')
        old=historical_result(ROOT,source['base_commit'],name)
        require(old.returncode==0 or name in OVERLAY,'historical dependency missing')
        historical=hashlib.sha256(old.stdout).hexdigest() if old.returncode==0 else None
        require(historical==source['base_sources'][name],'historical base differs')
        if name not in OVERLAY: require(historical==digest,'unreviewed runtime input differs')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==set(source['artifacts']),'artifact coverage differs')
    for name,digest in source['artifacts'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/name)==digest,'artifact changed or escaped')
    if folder.resolve()==(REPORT/'native').resolve():
        names=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*names],cwd=ROOT,capture_output=True,env=git_environment()).returncode==0,'native evidence absent from Git index')
    return source


def pixel_mask(size,accepted,camera=(0,0),scale=1,padding=0):
    """Conservatively project approved full footprints to the real readback, allowing raster edge rounding."""
    mask=Image.new('L',size); draw=ImageDraw.Draw(mask)
    for row in accepted:
        x,y,w,h=row['rect']; x=(x-camera[0])*scale; y=(y-camera[1])*scale
        draw.rectangle((math.floor(x-padding),math.floor(y-padding),math.ceil(x+w*scale+padding),math.ceil(y+h*scale+padding)),fill=255)
    return mask


def images(folder,rows,accepted,width):
    """Ordinary controls must be exact; the filtered layer may change pixels only inside approved footprints."""
    total=0
    for case in CASES:
        frames={m:Image.open(folder/(case+'-'+m+'.png')).convert('RGB') for m in MODES}
        require(all(i.size==(width,round(width*9/16)) for i in frames.values()),'PNG/readback size differs')
        # Production rain uses wall-clock ticks despite frozen simulation. Validate its full snapshots
        # and independent transparent board, but never declare those moving pixels equivalent.
        if case in SNAPSHOT_ONLY: continue
        require(rows[case+'-after']['weather']=='clear','uncontrolled moving precipitation')
        require(ImageChops.difference(frames['control-before'],frames['control-after']).getbbox() is None,'ordinary scene changed')
        diff=ImageChops.difference(frames['control-before'],frames['after'])
        if case=='interior': require(diff.getbbox() is None,'interior changed')
        else:
            mask=pixel_mask(diff.size,accepted,rows[case+'-after']['camera'],1.2*width/1152,3)
            require(ImageChops.multiply(diff,ImageChops.invert(mask).convert('RGB')).getbbox() is None,'filtered seed escaped allowed footprint')
        total+=ImageChops.difference(frames['before'],frames['after']).getbbox() is not None
    require(total>=6,'diagnostic before/after did not exercise exclusions')
    before=Image.open(folder/'seed-before.png').convert('RGBA'); after=Image.open(folder/'seed-after.png').convert('RGBA')
    require(before.size==after.size==(2400,1368),'native seed board is not full world size')
    expected=Image.composite(before,Image.new('RGBA',before.size),pixel_mask(before.size,accepted))
    require(expected.tobytes()==after.tobytes(),'board lost safe seed or retained rejected seed')
    require(sum(before.getchannel('A').getdata())>sum(after.getchannel('A').getdata())>0,'seed filtering is empty or ineffective')
    return total


def verify(folder=REPORT/'native'):
    """Verify native proof, full draw snapshots and geometry without relaunching the user's game."""
    folder=Path(folder); source=provenance(folder); result={'task':'VGROUND-008','base_commit':source['base_commit'],'windows':{},'performance_eligible':False}
    first=None
    for width in [1152,1280]:
        target=folder/str(width); data=load(target/'capture.json'); rows=metadata(data,width); geometry=load(target/'policy.json'); accepted,rejected=policy(geometry)
        if first is None: first=geometry
        require(first==geometry,'window changed decoration geometry')
        env=load(target/'environment.json'); require(env['exit_code']==0 and env['profile']==data['profile'],'native process failed')
        require(not any(s in (target/'engine.txt').read_text() for s in ['ERROR:','SCRIPT ERROR','Parse Error']),'native engine error')
        callbacks=0
        for name,row in rows.items():
            with gzip.open(target/(name+'-draws.json.gz'),'rt') as stream: draws=json.load(stream)
            validate_draws(draws); require(len(draws)==row['draws'] and draws[0]['before']==row['snapshot'],'draw witness differs'); callbacks+=len(draws)
        changed=images(target,rows,accepted,width)
        moving=SNAPSHOT_ONLY
        result['windows'][str(width)]={'png_count':len(list(target.glob('*.png'))),'draw_callbacks':callbacks,'ordinary_exact_cases':len(CASES)-len(moving),'snapshot_only_cases':moving,'rain_pixel_equality':False,'diagnostic_changed_cases':changed,
            'accepted':len(accepted),'rejected':len(rejected),'zones':len(geometry['zones'])}
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--folder',type=Path,default=REPORT/'native'); parser.add_argument('--write',action='store_true')
    args=parser.parse_args(); result=verify(args.folder)
    if args.write: write(REPORT/'summary.json',result)
    print(json.dumps(result,ensure_ascii=False,indent=2))
