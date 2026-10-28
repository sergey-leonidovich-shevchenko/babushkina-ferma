#!/usr/bin/env python3
"""Verify historical VGROUND-005 evidence, exact source archives and real draw snapshots."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse
import gzip
import hashlib
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
from road_network_collect import ROOT, SOURCES, OVERLAY
from render_order import require, validate_draws
from tools.qa.performance.perf_contract_collect import sha, write
from ground_layers import cold_draws

REPORT=ROOT/'docs/reports/visual-overhaul/vground-005'
PAIRS=['spring','summer','autumn','winter','rain','bridge-west','bridge-east','interior','returned','junction-north','junction-east','junction-south']


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
    require(capture['task']=='VGROUND-005' and not capture['errors'] and capture['display']!='headless','invalid native capture')
    require(capture['simulation_frozen'] and not capture['performance_eligible'] and capture['gpu_time_ms'] is None,'unsupported performance claim')
    require(capture['window']==[width,round(width*9/16)],'wrong physical window')
    require(capture['material']=={'size':[512,512],'image_bytes':1398100,'cell_world':192,'scale':1.2},'material scale or mipmap coverage changed')
    rows={r['id']:r for r in capture['rows']}
    require(len(rows)==26 and set(rows)=={p+s for p in PAIRS for s in ['-before','-after']}|{'direct','cached'},'case coverage')
    for row in rows.values():
        require(row['focused'] and row['physical']==capture['window'] and row['zoom']==1.2,'focus/host/zoom differs')
        require(row['viewports']==1 and row['draws']==4 and row['readback']==capture['window'] and row['logical']==[1152,648],'wrong viewport/readback/draw coverage')
    for pair in PAIRS:
        a,b=rows[pair+'-before'],rows[pair+'-after']
        require(not a['joined'] and b['joined'],'pair did not switch joining')
        for key in ['camera','player','location','season','weather','snapshot']: require(a[key]==b[key],'pair changed '+key)
    return rows


def provenance(folder):
    """Tie each archived input to the Git base and review overlay, with complete artifact coverage."""
    source=load(folder/'source.json')
    require(source['complete'] and source['task']=='VGROUND-005','incomplete collection')
    require(set(source['sources'])==set(SOURCES) and set(source['base_sources'])==set(SOURCES),'source coverage')
    for name,digest in source['sources'].items():
        require(sha(folder/'inputs'/name)==digest,'archived input changed')
        old=subprocess.run(['git','show',source['base_commit']+':'+name],cwd=ROOT,capture_output=True)
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
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*names],cwd=ROOT,capture_output=True).returncode==0,'native proof missing from Git index')
    return source


def compare(first,second):
    """Measure decoded RGB independently of PNG metadata/compression."""
    with Image.open(first) as a,Image.open(second) as b:
        diff=ImageChops.difference(a.convert('RGB'),b.convert('RGB'))
        return {'mean':sum(ImageStat.Stat(diff).mean)/3,'max':max(p[1] for p in diff.getextrema())}


def profile(values):
    """Reject binary or coarse alpha jumps on a real straight-edge cross-section."""
    require(len(values)==26 and values[0]<=5 and values[-1]>=250,'edge cross-section missing')
    step=max(abs(values[i]-values[i-1]) for i in range(1,len(values)))
    require(len(set(values))>=9 and step<=64,'binary or stepped alpha edge')
    return {'alpha':values,'max_step':step,'levels':len(set(values))}


def mask_pair(first,second):
    """Texture color may change, but every actual framebuffer alpha byte must stay identical."""
    with Image.open(first) as a,Image.open(second) as b:
        require(a.mode=='RGBA' and b.mode=='RGBA','transparent native mask lost')
        alpha=a.getchannel('A'); other=b.getchannel('A')
        require(ImageChops.difference(alpha,other).getbbox() is None,'material changed coverage')
        require(ImageChops.difference(a.convert('RGB'),b.convert('RGB')).getbbox() is not None,'color control did not change material')
        result=profile([alpha.getpixel((144,y)) for y in range(120,146)])
        result['alpha_exact_after_recolor']=True
        return result


def network_agreement(partition,reference,mask,reference_mask):
    """Require an independent single-pass reference, full alpha agreement and equal widths on five arms."""
    color=compare(partition,reference); alpha=compare(mask,reference_mask)
    require(color['max']<=1 and alpha['max']<=1,'partition differs from one-pass reference')
    with Image.open(mask) as a,Image.open(reference_mask) as b:
        require(a.mode==b.mode=='RGBA' and a.size==b.size==(1152,1152),'native mask format changed')
        first=a.getchannel('A'); second=b.getchannel('A')
        require(first.getbbox() is not None and sum(first.histogram()[128:])>50000,'blank reference/partition')
        require(max(ImageChops.difference(first,second).getextrema())<=1,'double alpha or missing owner at join')
        widths=[]
        for x,y in [(120,144),(800,144),(120,432),(600,480),(800,816)]:
            widths.append(sum(first.getpixel((round(x*1.2),round(y*1.2)+dy))>=128 for dy in range(-60,61)))
        require(min(widths)>=84 and max(widths)<=89 and max(widths)-min(widths)<=3,'inconsistent road arm width')
    return {'single_pass_color':color,'single_pass_mask_rgb':alpha,'alpha_max_error':max(ImageChops.difference(first,second).getextrema()),'arm_width_pixels':widths}


def verify(folder):
    """Validate actual images and snapshots; numeric success alone does not accept the artwork."""
    source=provenance(folder); result={'task':'VGROUND-005','base_commit':source['base_commit'],'windows':{},'performance_eligible':False,'gpu_time_ms':None}
    for width in [1152,1280]:
        path=folder/str(width); capture=load(path/'capture.json'); rows=metadata(capture,width)
        require(load(path/'environment.json')['exit_code']==0,'native process failed')
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
        require(compare(path/'junction-north-before.png',path/'junction-north-after.png')['mean']>.05,'edges unchanged')
        cold_draws(json.loads(gzip.decompress((path/'cold-first-draws.json.gz').read_bytes())))
        require(compare(path/'direct.png',path/'cold-first.png')['max']==0,'first cold frame lost full fallback coverage')
        for name in ['edges-before-spring','edges-after-spring','edges-reference-spring','edges-reference-mask-spring','edges-mask-spring','edges-recolor-spring','edges-after-winter']:
            with Image.open(path/(name+'.png')) as image: require(image.size==(1152,1152),'edge board no longer 120%')
        mask=mask_pair(path/'edges-mask-spring.png',path/'edges-recolor-spring.png')
        mask.update(network_agreement(path/'edges-after-spring.png',path/'edges-reference-spring.png',path/'edges-mask-spring.png',path/'edges-reference-mask-spring.png'))
        result['windows'][str(width)]={'mask':mask,'png_count':34,'draw_callbacks':105,'spring':compare(path/'spring-before.png',path/'spring-after.png'),'junctions':{name:compare(path/(name+'-before.png'),path/(name+'-after.png')) for name in ['junction-north','junction-east','junction-south']},'board_change':compare(path/'edges-before-spring.png',path/'edges-after-spring.png'),
            'fallback':compare(path/'direct.png',path/'cached.png'),'draw_calls_before':rows['spring-before']['draw_calls'],'draw_calls_after':rows['spring-after']['draw_calls']}
    print('ROAD NETWORK EVIDENCE: 68 native PNG, 210 complete draw snapshots; no FPS claim')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,default=REPORT/'native'); parser.add_argument('--write',action='store_true')
    args=parser.parse_args(); result=verify(args.output.resolve())
    if args.write: write(REPORT/'summary.json',result)
