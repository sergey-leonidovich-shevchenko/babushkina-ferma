#!/usr/bin/env python3
"""Verify five natural calendar ground profiles on one immutable first-map geometry."""
if not __package__:
    from tools.common.launch import prepare_imports
    from tools.common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse
import copy
import gzip
import hashlib
import json
import subprocess
from tools.common.git import git_environment
from pathlib import Path
from tools.qa.world.source_inputs import historical_result
from PIL import Image, ImageChops, ImageStat
from tools.qa.ground.ground_seasons_collect import ROOT, SOURCES, OVERLAY
from tools.qa.performance.perf_contract_collect import sha, write
from tools.qa.world.render_order import require, validate_draws

REPORT=ROOT/'docs/reports/visual-overhaul/vground-010'
CASES={'spring':(1,'spring','clear'),'summer':(8,'summer','clear'),'autumn':(15,'autumn','clear'),'winter':(22,'winter','clear'),'wet':(3,'spring','rain')}
VIEWS=['homestead','farm-end','square','bridge-west','bridge-east','road-turn']


def load(path):
    """Read immutable JSON evidence."""
    return json.loads(Path(path).read_text())


def provenance(folder):
    """Bind exact archived sources and artifacts to the historical base and review overlay."""
    source=load(folder/'source.json')
    require(source['complete'] and source['task']=='VGROUND-010' and source['performance_eligible'] is False,'incomplete source record')
    require(isinstance(source['static_coexistence'],bool) and isinstance(source['initial_jobs'],list) and (source['static_coexistence'] or not source['initial_jobs']),'process policy absent')
    require(set(source['sources'])==set(source['base_sources'])==set(SOURCES),'source coverage')
    for name,digest in source['sources'].items():
        require(sha(folder/'inputs'/name)==digest,'archived source changed')
        old=historical_result(ROOT,source['base_commit'],name);historical=hashlib.sha256(old.stdout).hexdigest() if old.returncode==0 else None
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


def metadata(data,width):
    """Require all views, actual climates and full same-world snapshots at each camera."""
    require(data['task']=='VGROUND-010' and not data['errors'] and data['display']!='headless','invalid native capture')
    require(data['simulation_frozen'] and data['performance_eligible'] is False and data['gpu_time_ms'] is None,'unsupported performance claim')
    require(data['plot_water_fixed_by_fixture'] is True,'visual fixture is not natural watering')
    require(set(data['reference_effects_suppressed'])=={'water_overlays','ambient_motion','orchard_weather','atmosphere','action_feedback'},'unreported reference suppression')
    window=[width,round(width*9/16)];require(data['window']==window,'wrong window')
    rows={r['id']:r for r in data['rows']}
    expected={c+'-'+v for c in CASES for v in VIEWS+['ordinary']}|{'spring-return','interior','returned'}
    require(len(data['rows'])==len(rows)==38 and set(rows)==expected,'missing or duplicated case')
    identities=set()
    for row in rows.values():
        require(row['focused'] and row['physical']==row['readback']==window and row['logical']==[1152,648] and row['zoom']==1.2 and row['draws']==4,'wrong focus, viewport or draw')
        m=row['metrics'];require(m['targets']==1 and m['target_size']==[2400,1368] and m['ready'] and m['pending']==0,'extra, resized or pending terrain target')
        identities.add((m['target_id'],m['texture_id']))
    require(len(identities)==1,'terrain resource recreated')
    for climate,(day,season,weather) in CASES.items():
        for view in VIEWS+['ordinary']:
            row=rows[climate+'-'+view];base=rows['spring-'+view]
            require(row['climate']==climate and row['day']==day and row['season']==season and row['weather']==weather and row['location']=='overworld','wrong natural climate')
            require(row['reference']==(view!='ordinary'),'ordinary effects mislabeled')
            require(row['view']==('farm-end' if view=='ordinary' else view),'wrong viewpoint')
            require(row['camera']==base['camera'] and row['player']==base['player'],'same-view camera moved')
            saved=copy.deepcopy(row['snapshot']);saved['day']=base['snapshot']['day']
            require(saved==base['snapshot'],'season changed another saved field')
            if view=='ordinary':require(row['snapshot']==rows[climate+'-farm-end']['snapshot'],'ordinary effects changed save')
    for key in ['snapshot','camera','player','season','weather']:
        require(rows['spring-return'][key]==rows['spring-farm-end'][key],'calendar return changed '+key)
    require(rows['interior']['location']=='cottage_interior' and rows['returned']['location']=='overworld','actual house transition missing')
    return rows


def geometry_and_retention(data,retained):
    """Compare raw rules/motions, all retained meshes, idempotence and pause/resume."""
    climates={c['id']:c for c in data['climates']}
    require(len(data['climates'])==len(climates)==5 and set(climates)==set(CASES),'climate geometry coverage')
    baseline=climates['spring'];mesh=baseline['geometry'];nav=baseline['navigation']
    require(mesh['mesh_count']==len(mesh['mesh_ids'])==len(mesh['mesh_hashes'])==41 and mesh['world']==[2400,1368],'mesh coverage')
    require(len(nav['rules'])==1200 and len(nav['motions'])==8,'navigation sample coverage')
    previous=None
    for name,(day,season,weather) in CASES.items():
        c=climates[name]
        require((c['day'],c['season'],c['weather'],c['natural_weather'])==(day,season,weather,weather),'unnatural calendar')
        require(c['geometry']==mesh and c['navigation']==nav,'geometry, alpha, route or tilling changed')
        require(c['ordinary_cache_exact'] is True,'ordinary effects repainted terrain cache')
        require(c['idempotent_before']==c['idempotent_after'],'repeated climate rebuilt cache')
        current=c['idempotent_after']
        if previous:
            for key in ['requests','paints','revision']:require(current[key]-previous[key]==1,'season refresh count differs')
            for key in ['target_id','texture_id','targets','target_size']:require(current[key]==previous[key],'season allocated another target')
        previous=current
    require(retained['callbacks']==120 and retained['pause_resume'] and retained['cache_exact'],'retention witness missing')
    # Opening the actual menu deliberately records two existing first-use events.
    # Permit exactly these known writes; every other saved field must remain equal.
    expected=copy.deepcopy(retained['save_before'])
    expected['estate']['expansion']['first_chapter']['events']['pause_menu']=True
    expected['tutorial']['events']['pause_menu']=True
    require(retained['before']==retained['after'] and expected==retained['save_after'] and retained['geometry_after']==mesh,'idle/pause changed world or cache')
    return climates


def rgba(path):
    """Include transparent RGB bytes when comparing complete decoded targets."""
    with Image.open(path) as image:return image.convert('RGBA')


def pixels(path):
    """Require unchanged full alpha, distinct seasonal materials and an exact spring return."""
    images={c:rgba(path/(c+'-cache.png')) for c in CASES};base=images['spring']
    require(all(i.size==(2400,1368) for i in images.values()),'partial terrain image')
    stats={}
    for name,image in images.items():
        require(ImageChops.difference(base.getchannel('A'),image.getchannel('A')).getextrema()==(0,0),'season moved alpha coverage')
        stats[name]={}
        for region,box in {'meadow':(2208,1200,2304,1296),'plaza':(1248,624,1344,720)}.items():
            crop=image.crop(box).convert('RGB');stat=ImageStat.Stat(crop)
            require(min(stat.stddev)>1 and min(stat.mean)>10,'blank material')
            stats[name][region]={'rgb_mean':stat.mean,'gray_mean':ImageStat.Stat(crop.convert('L')).mean[0]}
        require(image.crop((192,864,336,960)).tobytes()==base.crop((192,864,336,960)).tobytes(),'season repainted fixed garden base')
    for region in ['meadow','plaza']:
        require(len({tuple(stats[c][region]['rgb_mean']) for c in CASES})==5,'season material did not change')
        require(stats['wet'][region]['gray_mean']<stats['spring'][region]['gray_mean'],'rain did not darken ground')
    require(base.tobytes()==rgba(path/'spring-return-cache.png').tobytes(),'spring return cache differs')
    require(rgba(path/'spring-farm-end.png').tobytes()==rgba(path/'spring-return.png').tobytes(),'spring return frame differs')
    return stats


def verify(folder=REPORT/'native'):
    """Verify archived inputs, real draw purity and the five complete seasonal targets."""
    folder=Path(folder);source=provenance(folder)
    result={'task':'VGROUND-010','base_commit':source['base_commit'],'windows':{},'performance_eligible':False}
    for width in [1152,1280]:
        path=folder/str(width);data=load(path/'capture.json');rows=metadata(data,width)
        geometry_and_retention(data,load(path/'retained.json'))
        require(load(path/'environment.json')['exit_code']==0 and not any(s in (path/'engine.txt').read_text() for s in ['ERROR:','SCRIPT ERROR','Parse Error']),'native process failed')
        callbacks=0
        for name,row in rows.items():
            draws=json.loads(gzip.decompress((path/(name+'-draws.json.gz')).read_bytes()));validate_draws(draws)
            require(len(draws)==row['draws'] and draws[0]['before']==row['snapshot'],'draw witness differs');callbacks+=len(draws)
            require(rgba(path/(name+'.png')).size==(width,round(width*9/16)),'root image size differs')
        stats=pixels(path)
        require(len(list(path.glob('*.png')))==44,'unexpected PNG coverage')
        result['windows'][str(width)]={'png_count':44,'draw_callbacks':callbacks,'climates':5,'views_per_climate':6,'retained_meshes':41,
            'identical_rules':1200,'identical_bridge_motions':8,'alpha_exact':True,'spring_return_exact':True,'retained_targets':1,
            'idle_callbacks':120,'pause_resume_cache_exact':True,'pause_saved_events_only':['first_chapter.pause_menu','tutorial.pause_menu'],
            'idempotent_calls_per_climate':10,'material_samples':stats}
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--folder',type=Path,default=REPORT/'native');parser.add_argument('--write',action='store_true')
    args=parser.parse_args();result=verify(args.folder)
    if args.write:write(REPORT/'summary.json',result)
    print(json.dumps(result,ensure_ascii=False,indent=2))
