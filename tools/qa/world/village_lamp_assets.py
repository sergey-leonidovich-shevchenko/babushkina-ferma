#!/usr/bin/env python3
"""Derive unlit lamp bodies; emission remains independent procedural profile data."""
import argparse,hashlib,io,json
from pathlib import Path
from PIL import Image
from tools.common.paths import project_root
from tools.common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-004'
RUNTIME=ROOT/'assets/game/locations/overworld/lamps'
ANCHORS={'south':[511,1487],'west':[621,1489],'east':[418,1484]}
EMITTERS={'south':[511,665],'west':[304,635],'east':[741,635]}
GLOW={'darkness_peak':.62,'radii':[0,3,7,16,32],'alpha':[.65,.4,.16,.055,0],
      'color':[1,.77,.36],'segments':24,'clock':'WorldEventSystem.darkness; no separate timer'}

def sha(path):
    """Sign original masters, exact derivatives and their documentary passport."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def derive(side):
    """Crop an opaque prop with alpha headroom and uniformly reduce its authoring height."""
    path=REPORT/'masters'/(side+'.png')
    with Image.open(path) as master:
        image=master.convert('RGBA');box=image.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
        x0,y0,x1,y1=box;rect=[max(0,x0-8),max(0,y0-8),min(image.width,x1+8),min(image.height,y1+8)]
        crop=image.crop(rect);factor=480/crop.height;size=[round(crop.width*factor),480]
        output=Image.new('RGBA',(size[0]+16,size[1]+16));output.paste(crop.resize(size,Image.Resampling.LANCZOS),(8,8))
        def point(p):return [8+(p[0]-rect[0])*size[0]/(rect[2]-rect[0]),8+(p[1]-rect[1])*size[1]/(rect[3]-rect[1])]
        assert image.getpixel(tuple(ANCHORS[side]))[3]>=200
        assert image.getpixel(tuple(EMITTERS[side]))[3]>=200
        raw=io.BytesIO();output.save(raw,format='PNG')
        return raw.getvalue(),{'master':'masters/'+side+'.png','master_sha256':sha(path),'crop':rect,'pixels':list(output.size),
            'anchor':point(ANCHORS[side]),'emitter':point(EMITTERS[side]),'source_anchor':ANCHORS[side],'source_emitter':EMITTERS[side],
            'runtime':str((RUNTIME/('lamp_'+side+'_v1.png')).relative_to(ROOT)),'render_scale':.25}

def build():
    """Keep three body PNG outside the independent glow profile and stable game resource IDs."""
    RUNTIME.mkdir(parents=True,exist_ok=True);rows={};profile={'schema':1,'task':'VPROP-004','render_scale':.25,'glow':GLOW,'views':{}}
    for side in ANCHORS:
        raw,row=derive(side);path=ROOT/row['runtime'];path.write_bytes(raw);row['sha256']=sha(path);rows[side]=row
        profile['views'][side]={k:row[k] for k in ['pixels','anchor','emitter']}
    source={'schema':1,'task':'VPROP-004','tool':'built-in image_gen','unlit_body':True,'render_scale':.25,'views':rows,'glow':GLOW,
        'processing':'Mechanical alpha>=8 ROI plus 8 source pixels, uniform Lanczos height 480 and 8 output pixels of padding. No repaint, mirroring, background keying or runtime axis fitting. RGBA at zero alpha retained.',
        'separation':'Grey unlit panes remain the same PNG at every time. WorldEventSystem.darkness drives one radial mesh shared by all facings and placements; no baked emissive bitmap or added timer.'}
    (REPORT/'source.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n')
    (RUNTIME/'profile.json').write_text(json.dumps(profile,indent=2)+'\n')
    p=ROOT/'assets/game/visual_resources.json';catalog=json.loads(p.read_text());views={}
    for side,row in rows.items():
        tid='village_lamp_'+side+'_v1';w,h=row['pixels']
        catalog['textures'][tid]={'file':'res://'+row['runtime'],'pixels':[w,h],'sha256':row['sha256'],'layout':'standalone',
            'import':{'compress/mode':0,'mipmaps/generate':False,'process/fix_alpha_border':True,'process/premult_alpha':False},'intent':'color_srgb'}
        views[side]={'logical_size':[w*.25,h*.25],'footprint_size':[24,24],'pivot':[row['anchor'][0]/w,row['anchor'][1]/h],
            'variants':{'standard':{'texture':tid,'source_rect':[0,0,w,h]}}}
    catalog['resources']['prop.village_lamp']={'kind':'prop','space':'world','owner':'VillageLampVisual + VillagePropRenderer + AtmosphereRenderer','task':'VPROP-004',
        'source':{'kind':'master','file':str((REPORT/'source.json').relative_to(ROOT)),'sha256':sha(REPORT/'source.json')},
        'filter':'linear','sampling_family':'painted_world','default_quality':'standard','views':views}
    p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')

def verify():
    """Reject changed RGBA, missing sides, stale emitter placement or a light baked into the profile contract."""
    source=json.loads((REPORT/'source.json').read_text());profile=json.loads((RUNTIME/'profile.json').read_text())
    assert source['unlit_body'] is True and source['glow']==profile['glow']==GLOW
    assert set(source['views'])==set(profile['views'])==set(ANCHORS) and profile['render_scale']==.25
    for side,row in source['views'].items():
        raw,expected=derive(side);assert (ROOT/row['runtime']).read_bytes()==raw and sha(ROOT/row['runtime'])==row['sha256']
        assert all(row[k]==v for k,v in expected.items())
        assert profile['views'][side]=={k:row[k] for k in ['pixels','anchor','emitter']}
        with Image.open(REPORT/row['master']) as master:
            r,g,b,a=master.convert('RGBA').getpixel(tuple(EMITTERS[side]))
            assert a>=200 and b>=r and max(r,g,b)<210,'measured pane sample is not cool unlit glass'
        with Image.open(ROOT/row['runtime']) as im:
            box=im.getchannel('A').getbbox();assert min(box[0],box[1],im.width-box[2],im.height-box[3])>=8
    print('LAMP ASSETS: three unlit bodies, exact RGBA/pivots/pane centers and separate bounded glow profile')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--build',action='store_true');args=parser.parse_args()
    if args.build:build()
    verify()
