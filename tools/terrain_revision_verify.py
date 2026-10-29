#!/usr/bin/env python3
"""Verify local writes to the retained GPU target, full controls and unchanged gameplay."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse
import copy
import gzip
import hashlib
import json
import subprocess
from tools.common.git import git_environment
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw
from terrain_revision_collect import ROOT, SOURCES, OVERLAY
from tools.qa.performance.perf_contract_collect import sha, write
from tools.qa.world.render_order import require, validate_draws
from ground_layers import cold_draws

REPORT=ROOT/'docs/reports/visual-overhaul/vground-009'
CASES=['cottage','bridge-west','bridge-east','road-turn','road-end','summer','autumn','winter']
FARM=[144,816,288,240]
MODES=['full-before','full-after','local-before','local-after','plot-before','plot-after','direct-fallback','cached-final','interior','returned']


def load(path):
    """Read evidence without modifying the archived input."""
    return json.loads(Path(path).read_text())


def metadata(data,width):
    """Reject wrong windows, altered snapshots, missing comparisons and performance claims."""
    require(data['task']=='VGROUND-009' and not data['errors'] and data['display']!='headless','native capture invalid')
    require(data['simulation_frozen'] and data['performance_eligible'] is False and data['gpu_time_ms'] is None,'unsupported performance claim')
    require(data['plot_water_set_by_fixture'] is True and data['real_tools_in_profile'] is True,'visual fixture presented as physical input')
    window=[width,round(width*9/16)];require(data['window']==window,'window differs')
    rows={r['id']:r for r in data['rows']}; expected=set(MODES)|{c+s for c in CASES for s in ['-local','-full']}
    require(len(data['rows'])==len(rows)==26 and set(rows)==expected,'case coverage differs')
    for row in rows.values():
        require(row['focused'] and row['physical']==row['readback']==window and row['logical']==[1152,648] and row['zoom']==1.2 and row['draws']==4,'focus/viewport/zoom/draw differs')
        require(row['weather']=='clear','moving weather is not a pixel control')
        require(row['metrics']['targets']==1 and row['metrics']['target_size']==[2400,1368],'extra or resized render target')
    for a,b in [('full-before','local-before'),('full-after','local-after')]+[(c+'-local',c+'-full') for c in CASES]:
        for key in ['camera','player','location','season','weather','garden','snapshot']: require(rows[a][key]==rows[b][key],'pair changed '+key)
    for key in ['snapshot','camera','player','location']: require(rows['full-before'][key]==rows['full-after'][key],'style switch changed '+key)
    original=copy.deepcopy(rows['plot-before']['snapshot']);watered=copy.deepcopy(rows['plot-after']['snapshot'])
    a=next(p for p in original['plots'] if p['x']==p['y']==2);b=next(p for p in watered['plots'] if p['x']==p['y']==2)
    require(a['watered'] is False and b['watered'] is True,'watering fixture did not change its target')
    b['watered']=False;require(original==watered,'watering fixture changed another saved field')
    require(rows['interior']['location']=='cottage_interior' and rows['returned']['location']=='overworld','actual transition missing')
    return rows


def metrics(data):
    """Distinguish real completions from requests and require the same retained GPU resources."""
    ops={r['id']:r for r in data['operations']};require(len(ops)==len(data['operations'])==15,'operation coverage')
    require(set(ops)=={'full','local','disjoint','rapid','global','plot','idle'}|set(CASES),'operation IDs differ')
    identities=[]
    for op in ops.values():
        for phase in ['before','scheduled','after']:
            if phase not in op: continue
            m=op[phase];r=m['revision'];identities.append((m['target_id'],m['texture_id'],m['children']))
            require(m['targets']==1 and m['target_size']==[2400,1368] and len(r['sections'])<=60 and len(r['pending'])<=32,'unbounded local cache')
        after=op['after'];require(after['ready'] and not after['revision']['pending'] and not after['revision']['full_pending'] and after['revision']['active']==[0,0,0,0],'unfinished cache accepted')
    require(len(set(identities))==1,'target/texture/nodes recreated during local updates')
    for name,full,local in [('full',1,0),('local',0,1),('disjoint',0,3),('rapid',0,2),('global',1,0),('plot',0,0),('idle',0,0)]+[(c,1,1) for c in CASES]:
        op=ops[name];a,b=op['before'],op['after']
        require(b['requests']-a['requests']==full and b['revision']['full_paints']-a['revision']['full_paints']==full and b['revision']['local_paints']-a['revision']['local_paints']==local,'wrong completion delta: '+name)
    local=ops['local']['scheduled']
    require(local['clip']==FARM and local['clear_mode']==1 and local['revision']['active']==FARM and not local['revision']['full_pending'],'local region cleared or repainted whole target')
    require(ops['full']['scheduled']['clip']==[0,0,2400,1368] and ops['full']['scheduled']['clear_mode']==0,'full control did not use the old complete refresh')
    require(len(ops['disjoint']['scheduled']['revision']['pending'])==2 and len(ops['rapid']['scheduled']['revision']['pending'])==1,'pending requests lost or merged across distant regions')
    require(ops['global']['scheduled']['revision']['full_pending'] and not ops['global']['scheduled']['revision']['pending'],'global refresh did not supersede stale local work')
    plot=ops['plot'];a,b=plot['meshes_before'],plot['meshes_after'];require(len(a)==len(b)==30 and set(a)==set(b),'plot cache not bounded to thirty cells')
    changed={k for k in a if a[k]!=b[k]}
    require(changed=={'(2, 2)','(1, 2)','(3, 2)','(2, 1)','(2, 3)'},'watering rebuilt unrelated plot geometry or left stale neighbor edges')
    require(ops['idle']['callbacks']==120 and ops['idle']['before']==ops['idle']['after'],'idle draw rebuilt or grew retained resources')
    return ops


def provenance(folder):
    """Bind exact archived sources and artifacts to the historical base and review overlay."""
    source=load(folder/'source.json')
    require(source['complete'] and source['task']=='VGROUND-009' and source['performance_eligible'] is False,'incomplete source record')
    require(isinstance(source['static_coexistence'],bool) and isinstance(source['initial_jobs'],list) and (source['static_coexistence'] or not source['initial_jobs']),'process policy absent')
    require(set(source['sources'])==set(source['base_sources'])==set(SOURCES),'source coverage')
    for name,digest in source['sources'].items():
        require(sha(folder/'inputs'/name)==digest,'archived source changed')
        old=subprocess.run(['git','show',source['base_commit']+':'+name],cwd=ROOT,capture_output=True,env=git_environment());historical=hashlib.sha256(old.stdout).hexdigest() if old.returncode==0 else None
        require(old.returncode==0 or name in OVERLAY,'historical input absent')
        require(historical==source['base_sources'][name],'historical base changed')
        if name not in OVERLAY: require(historical==digest,'unreviewed dependency changed')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==set(source['artifacts']),'artifact coverage differs')
    for name,digest in source['artifacts'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/name)==digest,'artifact changed or escaped')
    if folder.resolve()==(REPORT/'native').resolve():
        names=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*names],cwd=ROOT,capture_output=True,env=git_environment()).returncode==0,'native proof absent from Git index')
    return source


def rgba(path):
    """Decode complete RGBA, including the RGB bytes hidden by transparent alpha."""
    with Image.open(path) as image: return image.convert('RGBA')


def equal(a,b):
    """Equality is measured in decoded pixels, not PNG metadata."""
    label=Path(a).name+' / '+Path(b).name
    a,b=rgba(a),rgba(b)
    require(a.size==b.size and a.tobytes()==b.tobytes(),'pixel equality failed: '+label)


def local_pixels(before,after):
    """The complete cache changes only inside the declared farm; a no-op cannot pass."""
    a,b=rgba(before),rgba(after);require(a.size==b.size==(2400,1368),'cache is not full world size')
    diff=ImageChops.difference(a,b); mask=Image.new('L',a.size,255);ImageDraw.Draw(mask).rectangle((144,816,431,1055),fill=0)
    outside=ImageChops.multiply(diff,Image.merge('RGBA',(mask,mask,mask,mask)))
    require(all(high==0 for low,high in outside.getextrema()),'local update changed pixels outside declared region')
    changed=sum(v!=0 for v in diff.convert('RGB').convert('L').getdata())
    require(10000<changed<=288*240,'region did not update or exceeded its pixel budget')
    return changed


def historical_control(path,rows,width,base):
    """Compare against the previous accepted commit, excluding only its intentionally different untilled fixture."""
    relative='docs/reports/visual-overhaul/vground-008/native/'+str(width)+'/cottage-control-before.png'
    old=ROOT/relative;historical=subprocess.check_output(['git','show',base+':'+relative],cwd=ROOT,env=git_environment())
    require(sha(old)==hashlib.sha256(historical).hexdigest(),'previous native control changed after Git base')
    old_meta=load(old.parent/'capture.json');before=next(r for r in old_meta['rows'] if r['id']=='cottage-control-before');after=rows['cottage-full']
    require(before['player']==after['player'] and before['camera']==after['camera'] and before['zoom']==after['zoom']==1.2,'historical camera differs')
    different={k for k in before['snapshot'] if before['snapshot'][k]!=after['snapshot'][k]}
    require(different<={'plots','containers','rng','world_loot_seed'},'unexpected historical gameplay difference')
    if different-{'plots'}:
        # Separate QA sessions did not retain the same generated loot seed. Do not mask
        # the container sprite and pretend that these are equivalent historical scenes.
        return {'eligible':False,'different_fields':sorted(different),'reason':'different initial loot/RNG fixture; use same-state full/local controls in this series'}
    a,b=rgba(old),rgba(path/'cottage-full.png');mask=Image.new('L',a.size,255);scale=1.2*width/1152
    x=(144-after['camera'][0])*scale;y=(816-after['camera'][1])*scale
    ImageDraw.Draw(mask).rectangle((int(x)-2,int(y)-2,int(x+288*scale)+2,int(y+240*scale)+2),fill=0)
    diff=ImageChops.multiply(ImageChops.difference(a,b),Image.merge('RGBA',(mask,mask,mask,mask)))
    require(all(high==0 for low,high in diff.getextrema()),'new full cache changed the historical scene outside the plot fixture')
    return {'eligible':True,'outside_plot_fixture_exact':True}


def verify(folder=REPORT/'native'):
    """Verify images, immutable sources, real render snapshots and bounded local revisions."""
    folder=Path(folder);source=provenance(folder);result={'task':'VGROUND-009','base_commit':source['base_commit'],'windows':{},'performance_eligible':False}
    for width in [1152,1280]:
        path=folder/str(width);data=load(path/'capture.json');rows=metadata(data,width);metrics(data)
        require(load(path/'environment.json')['exit_code']==0 and not any(s in (path/'engine.txt').read_text() for s in ['ERROR:','SCRIPT ERROR','Parse Error']),'native process failed')
        callbacks=0
        for name,row in rows.items():
            draws=json.loads(gzip.decompress((path/(name+'-draws.json.gz')).read_bytes()));validate_draws(draws)
            require(len(draws)==row['draws'] and draws[0]['before']==row['snapshot'],'render witness differs');callbacks+=len(draws)
        for name in ['full-first','local-first']:
            draws=json.loads(gzip.decompress((path/(name+'-draws.json.gz')).read_bytes()));cold_draws(draws);callbacks+=len(draws)
        for a,b in [('full-before','local-before'),('full-after','local-after'),('full-first','local-first')]+[(c+'-local',c+'-full') for c in CASES]: equal(path/(a+'.png'),path/(b+'.png'))
        for a,b in [('full-before','local-before'),('full-after','local-after'),('retained-before','retained-after'),('retained-before','rapid-after'),('plot-before','plot-after'),('idle-before','idle-after')]: equal(path/(a+'-cache.png'),path/(b+'-cache.png'))
        changed=local_pixels(path/'local-before-cache.png',path/'local-after-cache.png')
        historical=historical_control(path,rows,width,source['base_commit'])
        # Direct rendering has the pre-existing sampling difference from the offscreen cache.
        # First-frame local/full controls above must nevertheless remain pixel-identical.
        fallback=ImageChops.difference(rgba(path/'direct-fallback.png').convert('RGB'),rgba(path/'cached-final.png').convert('RGB'))
        result['windows'][str(width)]={'png_count':len(list(path.glob('*.png'))),'draw_callbacks':callbacks,'changed_cache_pixels':changed,
            'outside_changed_pixels':0,'region':[288,240],'world':[2400,1368],'region_fraction':288*240/(2400*1368),
            'local_equals_full':True,'first_local_equals_full':True,'historical_control':historical,'retained_target_count':1,'plot_affected_meshes':5,'idle_callbacks':120,
            'direct_cache_preexisting_max_delta':max(high for low,high in fallback.getextrema())}
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--folder',type=Path,default=REPORT/'native');parser.add_argument('--write',action='store_true')
    args=parser.parse_args();result=verify(args.folder)
    if args.write: write(REPORT/'summary.json',result)
    print(json.dumps(result,ensure_ascii=False,indent=2))
