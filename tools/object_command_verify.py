#!/usr/bin/env python3
"""Verify the VRENDER-004 descriptor, isolated replay and unchanged production fallback."""
import argparse
import gzip
import hashlib
import json
import re
import subprocess
from pathlib import Path
from PIL import Image
from object_command_collect import ROOT,SOURCES,OVERLAY
from perf_contract_collect import sha,write
from render_order import require,validate_draws

REPORT=ROOT/'docs/reports/visual-overhaul/vrender-004'
CASES=['village','tree-behind','tree-front','bush','bridge','manual-pause','opaque-storage','interior','returned']
PROBES=['south','west','east','source-region','translucent','shader','material-mismatch','invalid-source','foreign-world','foreign-layer','missing-resource']
FALLBACK={'material-mismatch','invalid-source','foreign-world','foreign-layer','missing-resource'}


def load(path):
    """Read a recorded witness without regenerating it."""
    return json.loads(Path(path).read_text())


def provenance(folder):
    """Bind exact archived sources and artifacts to the historical base and review overlay."""
    source=load(folder/'source.json')
    require(source['complete'] and source['task']=='VRENDER-004' and source['performance_eligible'] is False,'incomplete source record')
    require(isinstance(source['static_coexistence'],bool) and isinstance(source['initial_jobs'],list) and (source['static_coexistence'] or not source['initial_jobs']),'process policy absent')
    require(set(source['sources'])==set(source['base_sources'])==set(SOURCES),'source coverage')
    for name,digest in source['sources'].items():
        require(sha(folder/'inputs'/name)==digest,'archived source changed')
        old=subprocess.run(['git','show',source['base_commit']+':'+name],cwd=ROOT,capture_output=True);historical=hashlib.sha256(old.stdout).hexdigest() if old.returncode==0 else None
        require(old.returncode==0 or name in OVERLAY,'historical input absent')
        require(historical==source['base_sources'][name],'historical base changed')
        if name not in OVERLAY: require(historical==digest,'unreviewed dependency changed')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==set(source['artifacts']),'artifact coverage differs')
    for name,digest in source['artifacts'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/name)==digest,'artifact changed or escaped')
    if folder.resolve()==(REPORT/'native').resolve():
        names=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*names],cwd=ROOT,capture_output=True).returncode==0,'native proof absent from Git index')
    return source


def metadata(data,width):
    """Require genuine production cases without claiming that the new pass is enabled."""
    require(data['task']=='VRENDER-004' and not data['errors'] and data['display_server']!='headless','invalid native capture')
    require(data['simulation_frozen'] and data['performance_eligible'] is False and data['gpu_time_ms'] is None and data['production_pass_enabled'] is False,'unsupported live-pass or performance claim')
    require(data['requested_size']==[width,round(width*9/16)] and data['probe_size']==[256,224],'wrong target dimensions')
    rows={r['id']:r for r in data['cases']};require(len(rows)==len(data['cases'])==9 and set(rows)==set(CASES),'production case coverage')
    for row in rows.values():
        require(row['focused'] and row['window']==row['readback']==data['requested_size'] and row['visible']==[1152,648] and row['draws']==4,'focus or viewport differs')
        require(row['zoom']==(1 if row['id']=='interior' else 1.2),'wrong production zoom')
        require(row['snapshot_before']==row['snapshot_after'],'descriptor construction or draw changed saved gameplay')
        require(row['root_material_null'] and row['background_material_null'] and row['terrain_material_null'],'object material leaked into root/HUD/terrain')
    require(rows['manual-pause']['pause'] and rows['opaque-storage']['storage'],'real modal route missing')
    require(rows['interior']['location']=='cottage_interior' and rows['returned']['location']=='overworld','real house transition missing')
    require(abs(rows['tree-behind']['tree_alpha']-0.34)<1e-6 and rows['tree-front']['tree_alpha']==1,'actual foreground opacity changed')
    probes={r['id']:r for r in data['probes']};require(len(probes)==len(data['probes'])==11 and set(probes)==set(PROBES),'probe coverage')
    for name,row in probes.items():
        p=row['packet'];require(row['draws']==[4,4] and row['expected']==('fallback' if name in FALLBACK else 'command'),'wrong replay outcome')
        require(p['version']==1 and p['space']=='world' and p['world']=='overworld' and p['layer']=='behind_actors' and p['anchor']==[128.25,176.5] and p['local_uv']==[0,0,1,1],'descriptor coordinates or scope differ')
        require(p['bounds'][2]>0 and p['bounds'][3]>0 and p['source'][2]>0 and p['source'][3]>0 and p['texture_path'].startswith('res://assets/game/'),'missing real texture geometry')
    require(len({tuple(probes[n]['packet']['source']) for n in ['south','west','east']})==3,'three directions reused one atlas region')
    require(probes['shader']['packet']['material_id']!=0 and probes['south']['packet']['material_id']==0,'isolated material control missing')
    require(abs(probes['translucent']['packet']['modulate'][3]-0.34)<1e-6,'partial alpha control missing')
    return rows,probes


def probe_draws(draws,mode,expected,packet):
    """Check real draw witnesses, exact resource scope and one atomic fallback per callback."""
    require(len(draws)==4 and len({d['frame'] for d in draws})==4,'missing real probe callbacks')
    for d in draws:
        require(d['before']==d['after'] and d['own_material_equal'] and d['parent_material_equal'] and d['transform_equal'],'probe mutated gameplay, transform or material')
        require(d['packet']==packet,'probe changed descriptor mid-pair')
        require(d['result']==('legacy' if mode=='legacy' else expected),'wrong actual backend result')
        require(d['fallback_calls']==(1 if mode=='command' and expected=='fallback' else 0),'lost or duplicate fallback')


def equal(a,b):
    """Compare every decoded RGBA byte, including transparent colours."""
    with Image.open(a) as first,Image.open(b) as second:
        a,b=first.convert('RGBA'),second.convert('RGBA')
        require(a.size==b.size and a.tobytes()==b.tobytes(),'native pixel equality failed')
        return a


def legacy_body(text):
    """The production workbench draw body must remain exactly the predecessor's body."""
    return re.search(r'static func draw\([^\n]+\n((?:\t[^\n]*\n|\n)*)',text)[1].strip()


def verify(folder=REPORT/'native'):
    """Check source-bound native controls; historical reports never validate a changed live pass."""
    folder=Path(folder);source=provenance(folder)
    file='scripts/presentation/world_workbench_visual_system.gd'
    old=subprocess.check_output(['git','show',source['base_commit']+':'+file],cwd=ROOT,text=True)
    require(legacy_body(old)==legacy_body((folder/'inputs'/file).read_text()),'production legacy draw changed')
    result={'task':'VRENDER-004','base_commit':source['base_commit'],'production_pass_enabled':False,'performance_eligible':False,'windows':{}}
    for width in [1152,1280]:
        path=folder/str(width);data=load(path/'capture.json');rows,probes=metadata(data,width)
        require(load(path/'environment.json')['exit_code']==0 and not any(t in (path/'engine.txt').read_text() for t in ['ERROR:','SCRIPT ERROR','Parse Error']),'engine or process failed')
        callbacks=0
        for name,row in rows.items():
            image=equal(path/(name+'-baseline.png'),path/(name+'-observed.png'))
            require(image.size==(width,round(width*9/16)),'wrong production image dimensions')
            draws=json.loads(gzip.decompress((path/(name+'-draws.json.gz')).read_bytes()));validate_draws(draws)
            require(draws[0]['before']==row['snapshot_before'],'draw witness not tied to production save');callbacks+=len(draws)
        alpha={}
        for name,row in probes.items():
            image=equal(path/('probe-'+name+'-legacy.png'),path/('probe-'+name+'-command.png'))
            require(image.size==(256,224),'wrong probe image dimensions')
            alpha[name]=image.getchannel('A').getextrema()
            require(alpha[name][1]>0 and image.getchannel('A').getbbox() is not None,'blank replay accepted')
            for mode in ['legacy','command']:
                draws=json.loads(gzip.decompress((path/('probe-'+name+'-'+mode+'-draws.json.gz')).read_bytes()))
                probe_draws(draws,mode,row['expected'],row['packet']);callbacks+=len(draws)
        require(0<alpha['translucent'][1]<alpha['south'][1],'alpha modulation ignored')
        require(len(list(path.glob('*.png')))==40,'unexpected PNG coverage')
        result['windows'][str(width)]={'png_count':40,'draw_callbacks':callbacks,'production_pairs':9,'probe_pairs':11,'pixel_equal':True,
            'fallback_cases':5,'descriptor_only_in_game':True,'owned_material_proved':True,'translucent_alpha_max':alpha['translucent'][1]}
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--folder',type=Path,default=REPORT/'native');parser.add_argument('--write',action='store_true')
    args=parser.parse_args();result=verify(args.folder)
    if args.write:write(REPORT/'summary.json',result)
    print(json.dumps(result,ensure_ascii=False,indent=2))
