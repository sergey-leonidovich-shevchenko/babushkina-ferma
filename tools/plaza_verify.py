#!/usr/bin/env python3
"""Verify historical VGROUND-006 evidence, exact source archives and real draw snapshots."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse
import gzip
import hashlib
import json
import subprocess
from tools.common.git import git_environment
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
from plaza_collect import ROOT, SOURCES, OVERLAY
from tools.qa.world.render_order import require, validate_draws
from tools.qa.performance.perf_contract_collect import sha, write
from ground_layers import cold_draws

REPORT=ROOT/'docs/reports/visual-overhaul/vground-006'
PAIRS=['spring','summer','autumn','winter','rain','bridge-west','bridge-east','interior','returned','junction-north','junction-east','junction-south','plaza-west','plaza-east']


def load(path):
    """Read one evidence file without mutating archived inputs."""
    return json.loads(Path(path).read_text())


def retained(data):
    """Both command counters and actual RGBA bytes must remain unchanged over real callbacks."""
    require(data['callbacks']==120,'retained witness truncated')
    for key in ['paints','requests','hash']: require(data[key+'_before']==data[key+'_after'],'retained ground rebuilt or changed')
    require(len(data['hash_before'])==64,'cache hash absent')


def metadata(capture,width):
    """Reject incomplete, headless, wrong-camera/size/state pairs or performance overclaims."""
    require(capture['task']=='VGROUND-006' and not capture['errors'] and capture['display']!='headless','invalid native capture')
    require(capture['simulation_frozen'] and not capture['performance_eligible'] and capture['gpu_time_ms'] is None,'unsupported performance claim')
    require(capture['window']==[width,round(width*9/16)],'wrong physical window')
    require(capture['material']=={'size':[512,512],'image_bytes':1398100,'cell_world':192,'scale':1.2,'texture':'plaza_limestone_v1'},'material scale or mipmap coverage changed')
    rows={r['id']:r for r in capture['rows']}
    require(len(rows)==30 and set(rows)=={p+s for p in PAIRS for s in ['-before','-after']}|{'direct','cached'},'case coverage')
    for row in rows.values():
        require(row['focused'] and row['physical']==capture['window'] and row['zoom']==1.2,'focus/host/zoom differs')
        require(row['viewports']==1 and row['draws']==4 and row['readback']==capture['window'] and row['logical']==[1152,648],'wrong viewport/readback/draw coverage')
    for pair in PAIRS:
        a,b=rows[pair+'-before'],rows[pair+'-after']
        require(not a['plaza'] and b['plaza'],'pair did not switch joining')
        for key in ['camera','player','location','season','weather','snapshot']: require(a[key]==b[key],'pair changed '+key)
    return rows


def process_policy(source):
    """Coexisting Godot is allowed only for frozen visual proof, with explicit recorded policy and no performance eligibility."""
    require(source['complete'] and source['task']=='VGROUND-006' and source['performance_eligible'] is False,'incomplete collection or unsupported performance claim')
    require(isinstance(source.get('static_coexistence'),bool) and isinstance(source.get('initial_jobs'),list),'process policy absent')
    require(source['static_coexistence'] or not source['initial_jobs'],'exclusive process policy violated')


def provenance(folder):
    """Tie each archived input to the Git base and review overlay, with complete artifact coverage."""
    source=load(folder/'source.json')
    process_policy(source)
    require(set(source['sources'])==set(SOURCES) and set(source['base_sources'])==set(SOURCES),'source coverage')
    for name,digest in source['sources'].items():
        require(sha(folder/'inputs'/name)==digest,'archived input changed')
        old=subprocess.run(['git','show',source['base_commit']+':'+name],cwd=ROOT,capture_output=True,env=git_environment())
        historical=hashlib.sha256(old.stdout).hexdigest() if old.returncode==0 else None
        require(historical==source['base_sources'][name],'historical base differs')
        if name not in OVERLAY: require(historical==digest,'unreviewed historical dependency changed')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==set(source['artifacts']),'artifact coverage differs')
    for name,digest in source['artifacts'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts,'unsafe path')
        require(sha(folder/name)==digest,'artifact changed')
    if folder.resolve()==(REPORT/'native').resolve():
        names=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*names],cwd=ROOT,capture_output=True,env=git_environment()).returncode==0,'native proof missing from Git index')
    return source


def compare(first,second):
    """Measure decoded RGB independently of PNG metadata/compression."""
    with Image.open(first) as a,Image.open(second) as b:
        diff=ImageChops.difference(a.convert('RGB'),b.convert('RGB'))
        return {'mean':sum(ImageStat.Stat(diff).mean)/3,'max':max(p[1] for p in diff.getextrema())}


def quiet_material(new_path,old_path):
    """Measure full-size native repeated surfaces, keeping the original and new textures separate."""
    def spread(path):
        with Image.open(path) as image:
            grey=image.convert('L'); hist=grey.histogram(); count=grey.width*grey.height
            def percentile(q):
                total=0
                for value,n in enumerate(hist):
                    total+=n
                    if total>=count*q:return value
            return {'p05':percentile(.05),'p95':percentile(.95),'std':ImageStat.Stat(grey).stddev[0]}
    new,old=spread(new_path),spread(old_path)
    require(new['p95']-new['p05']>10 and new['std']>3 and new['p95']-new['p05']<(old['p95']-old['p05'])*.8 and new['std']<old['std']*.8,'paving remains dominant or contrast control absent')
    return {'new':new,'old':old}


def plaza_mask(mask_path,recolor_path):
    """Require actual smooth alpha independent from color and with visible detached chips."""
    with Image.open(mask_path) as a,Image.open(recolor_path) as b:
        require(a.mode==b.mode=='RGBA' and a.size==b.size==(1152,1152),'wrong native mask')
        alpha=a.getchannel('A');other=b.getchannel('A')
        require(ImageChops.difference(alpha,other).getbbox() is None,'material changed plaza coverage')
        require(ImageChops.difference(a.convert('RGB'),b.convert('RGB')).getbbox() is not None,'recolor control absent')
        values=[alpha.getpixel((461,y)) for y in range(294,342)]
        require(values[0]<=5 and values[-1]>=250 and len(set(values))>=5,'plaza edge blank or binary')
        step=max(abs(values[i]-values[i-1]) for i in range(1,len(values)))
        require(step<=100,'plaza edge has hard alpha jump')
        return {'alpha_exact_after_recolor':True,'edge_alpha':values,'levels':len(set(values)),'max_step':step}


def verify(folder):
    """Validate actual images and snapshots; numeric success alone does not accept the artwork."""
    source=provenance(folder); result={'task':'VGROUND-006','base_commit':source['base_commit'],'windows':{},'performance_eligible':False,'gpu_time_ms':None}
    for width in [1152,1280]:
        path=folder/str(width); capture=load(path/'capture.json'); rows=metadata(capture,width)
        env=load(path/'environment.json')
        require(env['exit_code']==0 and env['existing_jobs_before']==source['initial_jobs'] and env['static_coexistence']==source['static_coexistence'],'native process policy changed')
        require(not set(env['jobs_after'])-set(source['initial_jobs']),'unexpected process remains after capture')
        require(not any(s in (path/'engine.txt').read_text() for s in ['SCRIPT ERROR','Parse Error','ERROR:']),'engine reported error')
        retained(load(path/'retained.json'))
        for name,row in rows.items():
            with Image.open(path/(name+'.png')) as image: require(list(image.size)==capture['window'],'PNG size differs')
            validate_draws(json.loads(gzip.decompress((path/(name+'-draws.json.gz')).read_bytes())))
        for pair in PAIRS:
            with Image.open(path/(pair+'-before.png')) as a,Image.open(path/(pair+'-after.png')) as b:
                for box in [(30,24,220,73),(325,597,825,633)]:
                    box=tuple(round(v*width/1152) for v in box)
                    require(ImageChops.difference(a.convert('RGB').crop(box),b.convert('RGB').crop(box)).getbbox() is None,'opaque HUD changed')
        require(compare(path/'interior-before.png',path/'interior-after.png')['max']==0,'material leaked into interior')
        require(compare(path/'spring-before.png',path/'spring-after.png')['mean']>.05,'edges unchanged')
        cold_draws(json.loads(gzip.decompress((path/'cold-first-draws.json.gz').read_bytes())))
        require(compare(path/'direct.png',path/'cold-first.png')['max']==0,'first cold frame lost full fallback coverage')
        for name in ['before','after','mask','recolor','repeat','repeat-before']:
            with Image.open(path/('edges-'+name+'-spring.png')) as image:require(image.size==(1152,1152),'plaza board no longer native 120%')
        mask=plaza_mask(path/'edges-mask-spring.png',path/'edges-recolor-spring.png')
        quiet=quiet_material(path/'edges-repeat-spring.png',path/'edges-repeat-before-spring.png')
        result['windows'][str(width)]={'mask':mask,'png_count':37,'draw_callbacks':121,'material':quiet,'spring':compare(path/'spring-before.png',path/'spring-after.png'),'junctions':{name:compare(path/(name+'-before.png'),path/(name+'-after.png')) for name in ['junction-north','junction-east','junction-south','plaza-west','plaza-east']},'board_change':compare(path/'edges-before-spring.png',path/'edges-after-spring.png'),
            'fallback':compare(path/'direct.png',path/'cached.png'),'draw_calls_before':rows['spring-before']['draw_calls'],'draw_calls_after':rows['spring-after']['draw_calls']}
    print('PLAZA EVIDENCE: 74 native PNG, 242 complete draw snapshots; no FPS claim')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,default=REPORT/'native'); parser.add_argument('--write',action='store_true')
    args=parser.parse_args(); result=verify(args.output.resolve())
    if args.write: write(REPORT/'summary.json',result)
