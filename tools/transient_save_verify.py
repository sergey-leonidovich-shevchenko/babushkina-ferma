#!/usr/bin/env python3
"""Verify native file preservation, unchanged gameplay/rendering and exact reviewed save code."""
import argparse,hashlib,json,subprocess
from functools import lru_cache
from pathlib import Path
from PIL import Image
from transient_save_collect import ROOT,REPORT,QA

def require(value,label):
    if not value:raise ValueError(label)

def load(path):return json.loads(Path(path).read_text())
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

@lru_cache(maxsize=512)
def blob(base,name):return subprocess.check_output(['git','show',base+':'+name],cwd=ROOT)

def metadata(data,phase,width):
    """Both real frames contain two actual pure draw callbacks and the same full gameplay state."""
    require(data['task']=='VCOMPAT-001' and data['phase']==phase and data['display']!='headless' and not data['errors'] and data['performance_eligible'] is False,'native identity/exit')
    rows=data['rows'];require([r['id'] for r in rows]==['plain','metadata'],'complete ordered native rows')
    require(rows[0]['before']==rows[1]['before'],'transient metadata leaked into snapshot')
    for row in rows:
        require(row['world']=='overworld' and row['window']==row['image']==[width,width*9//16] and row['logical']==[1152,648] and row['focused'],'physical window/focus')
        require(row['metadata']==(row['id']=='metadata') and row['before']==row['after'] and len(row['draws'])==2,'transient owner/pure draw')
        for d in row['draws']:require(d['before']==d['after']==row['before'] and d['equal'] and d['geometry_equal'],'draw changed gameplay or geometry')
        require(len({d['process_frame'] for d in row['draws']})==2,'two distinct production callbacks')
    writer=data['writer'];require(writer['healthy_writes'] and writer['material_rid_valid'] and not writer['temporary_exists'],'real writer positive control')
    before=phase=='before'
    require(writer['unsafe_accepted']==writer['resource_became_string']==before,'actual resource stringify/refusal control')
    require(writer['primary_unchanged']==writer['backup_unchanged']==(not before),'primary/backup preservation control')
    return {r['id']:r for r in rows}

def provenance(folder,phase,changes,source=None):
    """Assets are pinned to the accepted Git tree; every script and native artifact is independently hashed."""
    folder=Path(folder);s=source or load(folder/'source.json');base=changes['base_commit']
    require(s['task']=='VCOMPAT-001' and s['phase']==phase and s['complete'] and not s['performance_eligible'] and s['base_commit']==base,'complete phase/source identity')
    expected=set(subprocess.check_output(['git','ls-tree','-r','--name-only',base],cwd=ROOT,text=True).splitlines())
    expected={n for n in expected if n.startswith('scripts/') and n.endswith('.gd')}|{'project.godot','main.tscn'}|set(QA)
    require(set(s['sources'])==expected,'full production script coverage')
    require(s['asset_tree']==subprocess.check_output(['git','rev-parse',base+':assets/game'],cwd=ROOT,text=True).strip(),'accepted asset tree')
    for name,digest in s['sources'].items():
        p=folder/'inputs'/name;require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(p)==digest,'exact archived source')
        if name in QA:continue
        raw=blob(base,name)
        if name=='scripts/systems/atomic_json_store.gd' and phase=='after':require(digest==changes['after_sha256'] and hashlib.sha256(raw).hexdigest()==changes['before_sha256'],'reviewed save writer')
        else:require(p.read_bytes()==raw,'unrelated production source changed')
    actual={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==s['artifacts'],'complete exact native artifacts')
    for width in [1152,1280]:
        p=folder/str(width);require(load(p/'environment.json')['exit_code']==0 and not any(v in (p/'engine.txt').read_text() for v in ['ERROR:','SCRIPT ERROR','Parse Error']),'clean actual engine exit')
    return s

def same_pixels(a,b,width):
    with Image.open(a) as x,Image.open(b) as y:
        require(x.size==y.size==(width,width*9//16),'native image size')
        require(x.convert('RGBA').tobytes()==y.convert('RGBA').tobytes(),'save guard changed native pixels')

def verify():
    changes=load(REPORT/'changes.json');sources={p:provenance(REPORT/'native'/p,p,changes) for p in ['before','after']}
    for name in QA:require(sources['before']['sources'][name]==sources['after']['sources'][name],'frozen QA overlay changed')
    report={'task':'VCOMPAT-001','base_commit':changes['base_commit'],'save_version':2,'performance_eligible':False,'full_map_accepted':False,'windows':{}}
    for width in [1152,1280]:
        rows={p:metadata(load(REPORT/'native'/p/str(width)/'capture.json'),p,width) for p in sources}
        for name in ['plain','metadata']:
            a=rows['before'][name];b=rows['after'][name]
            require(all(a[k]==b[k] for k in ['before','player','camera','world','metadata']),'same-camera/gameplay pair')
            same_pixels(REPORT/'native/before'/str(width)/(name+'.png'),REPORT/'native/after'/str(width)/(name+'.png'),width)
        report['windows'][str(width)]={'before_png':2,'after_png':2,'draw_callbacks':8,'full_gameplay_equal':True,'rgba_pairs':2,'native_gpu_reference':True,'before_unsafe_accepted':True,'after_primary_backup_preserved':True}
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');args=p.parse_args();result=verify()
    if args.write:(REPORT/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
