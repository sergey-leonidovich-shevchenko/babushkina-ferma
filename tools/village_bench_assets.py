#!/usr/bin/env python3
"""Build or verify three uniformly rendered bench views from immutable transparent masters."""
import argparse,hashlib,io,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-002'
RUNTIME=ROOT/'assets/game/locations/overworld/benches'
FEET={'south':[(173,820),(1460,820),(234,700),(1412,700)],'west':[(688,822),(914,822),(657,460),(990,540)],'east':[(693,825),(933,759),(612,540),(969,493)]}
ANCHORS={'south':(817,834),'west':(801,845),'east':(813,855)}

def sha(path):
    """Bind both authoring masters and runtime derivatives to exact bytes."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def derive(side):
    """Crop a bounded opaque prop with 8px headroom, preserving its alpha and aspect ratio."""
    with Image.open(REPORT/'masters'/f'{side}.png') as master:
        image=master.convert('RGBA');box=image.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
        x0,y0,x1,y1=box;rect=(max(0,x0-8),max(0,y0-8),min(image.width,x1+8),min(image.height,y1+8))
        crop=image.crop(rect);factor=320/(crop.width if side=='south' else crop.height)
        size=(round(crop.width*factor),round(crop.height*factor));crop=crop.resize(size,Image.Resampling.LANCZOS)
        result=Image.new('RGBA',(size[0]+16,size[1]+16));result.paste(crop,(8,8))
        def point(p):return [8+(p[0]-rect[0])*size[0]/(rect[2]-rect[0]),8+(p[1]-rect[1])*size[1]/(rect[3]-rect[1])]
        anchor=point(ANCHORS[side]);feet=[point(p) for p in FEET[side]]
        for p in FEET[side]:assert image.getpixel(p)[3]>=200,'contact is not on a real foot'
        output=io.BytesIO();result.save(output,format='PNG')
        return output.getvalue(),{'master':f'masters/{side}.png','master_sha256':sha(REPORT/'masters'/f'{side}.png'),'crop':list(rect),'pixels':list(result.size),'anchor':anchor,'contacts':feet,'source_contacts':[list(p) for p in FEET[side]],'render_scale':0.25,'physical_footprint':[72,24] if side=='south' else [24,48]}

def build():
    """Publish only three final derivatives; retain masters and correction history outside runtime."""
    RUNTIME.mkdir(parents=True,exist_ok=True);rows={};profile={'schema':1,'task':'VPROP-002','render_scale':0.25,'views':{}}
    for side in FEET:
        raw,row=derive(side);path=RUNTIME/f'bench_{side}_v1.png';path.write_bytes(raw);row['runtime']=str(path.relative_to(ROOT));row['sha256']=sha(path);rows[side]=row
        profile['views'][side]={'pixels':row['pixels'],'anchor':row['anchor'],'contacts':row['contacts']}
    source={'schema':1,'task':'VPROP-002','tool':'built-in image_gen','style':'VART-001 A / VART-003 A / VART-006 B / VART-007 A','leg_count':4,'orientation':['south','west','east'],'calibration':'Each generated master is uniformly reduced once to the authoring major axis. All runtime pixels then share exactly 0.25 world units per pixel; no per-frame fit or stretch. Source ROI uses alpha >=8 plus 8px for opaque furniture, not translucent effects.','views':rows}
    (REPORT/'source.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n');(RUNTIME/'profile.json').write_text(json.dumps(profile,indent=2)+'\n')
    path=ROOT/'assets/game/visual_resources.json';catalog=json.loads(path.read_text());views={}
    for side,row in rows.items():
        tid='village_bench_'+side+'_v1';catalog['textures'][tid]={'file':'res://'+row['runtime'],'pixels':row['pixels'],'sha256':row['sha256'],'layout':'standalone','import':{'compress/mode':0,'mipmaps/generate':False,'process/fix_alpha_border':True,'process/premult_alpha':False},'intent':'color_srgb'}
        w,h=row['pixels'];views[side]={'logical_size':[w*.25,h*.25],'footprint_size':row['physical_footprint'],'pivot':[row['anchor'][0]/w,row['anchor'][1]/h],'variants':{'standard':{'texture':tid,'source_rect':[0,0,w,h]}}}
    catalog['resources']['prop.village_bench']={'kind':'prop','space':'world','owner':'VillageBenchVisual + VillagePropRenderer','task':'VPROP-002','source':{'kind':'master','file':str((REPORT/'source.json').relative_to(ROOT)),'sha256':sha(REPORT/'source.json')},'filter':'linear','sampling_family':'painted_world','default_quality':'standard','views':views}
    path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')

def verify():
    """Reject stale masters, altered alpha, clipped contacts, missing views and nonuniform runtime scale."""
    data=json.loads((REPORT/'source.json').read_text());profile=json.loads((RUNTIME/'profile.json').read_text())
    assert data['leg_count']==4 and set(data['views'])==set(profile['views'])==set(FEET)
    assert profile['render_scale']==.25
    for side,row in data['views'].items():
        raw,expected=derive(side);assert (ROOT/row['runtime']).read_bytes()==raw,'derivative changed'
        assert all(row[k]==v for k,v in expected.items()),'master geometry changed'
        assert sha(ROOT/row['runtime'])==row['sha256']
        view=profile['views'][side];assert view=={k:row[k] for k in ['pixels','anchor','contacts']}
        assert len(view['contacts'])==len(set(map(tuple,view['contacts'])))==4
        with Image.open(ROOT/row['runtime']) as image:
            bounds=image.getchannel('A').getbbox();assert bounds and min(bounds[0],bounds[1],image.width-bounds[2],image.height-bounds[3])>=8
    print('BENCH ASSETS: three views, four real annotated feet, exact alpha/derivatives, uniform 0.25 scale')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--build',action='store_true');args=parser.parse_args()
    if args.build:build()
    verify()
