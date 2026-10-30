#!/usr/bin/env python3
"""Derive modular oak fence sprites mechanically, without stretching or repainting."""
import argparse,hashlib,io,json
from pathlib import Path
from PIL import Image
from tools.common.paths import project_root
from tools.common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-005'
RUNTIME=ROOT/'assets/game/locations/overworld/fences'
HEIGHTS={'post':128,'rail':64,'depth':128}

def sha(path):
    """Bind every derivative to the exact authored source."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def derive(name):
    """Retain alpha, crop the measured object and uniformly downsample with headroom."""
    path=REPORT/'masters'/(name+'.png')
    with Image.open(path) as image:
        image=image.convert('RGBA');box=image.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
        cropbox=[max(0,box[0]-8),max(0,box[1]-8),min(image.width,box[2]+8),min(image.height,box[3]+8)]
        crop=image.crop(cropbox);scale=HEIGHTS[name]/crop.height;size=[round(crop.width*scale),HEIGHTS[name]]
        out=Image.new('RGBA',(size[0]+16,size[1]+16));out.paste(crop.resize(size,Image.Resampling.LANCZOS),(8,8))
        data=io.BytesIO();out.save(data,format='PNG')
        return data.getvalue(),{'master':'masters/'+name+'.png','master_sha256':sha(path),'crop':cropbox,'uniform_resize':scale,'pixels':list(out.size),'content_size':size,'runtime':str((RUNTIME/(name+'_v1.png')).relative_to(ROOT))}

def build():
    """Save three standalone parts and register their common linear world sampling."""
    RUNTIME.mkdir(parents=True,exist_ok=True);rows={}
    for name in HEIGHTS:
        raw,row=derive(name);p=ROOT/row['runtime'];p.write_bytes(raw);row['sha256']=sha(p);rows[name]=row
    source={'task':'VPROP-005','tool':'built-in image_gen','parts':rows,'render_scale':.25,'processing':'Alpha >=8 measured ROI plus8 source pixels, uniform Lanczos reduction and8 output padding; no repaint, rotation, keying or mirroring. Subregions repeat at the same density, never fit a rectangular sprite to a square.'}
    (REPORT/'source.json').write_text(json.dumps(source,indent=2)+'\n')
    (RUNTIME/'profile.json').write_text(json.dumps({'task':'VPROP-005','render_scale':.25,'parts':rows},indent=2)+'\n')
    p=ROOT/'assets/game/visual_resources.json';catalog=json.loads(p.read_text())
    for name,row in rows.items():
        tid='village_fence_'+name+'_v1';w,h=row['pixels']
        catalog['textures'][tid]={'file':'res://'+row['runtime'],'pixels':[w,h],'sha256':row['sha256'],'layout':'standalone','import':{'compress/mode':0,'mipmaps/generate':False,'process/fix_alpha_border':True,'process/premult_alpha':False},'intent':'color_srgb'}
        # Non-directional construction parts: no invented back-facing furniture view.
        catalog['resources']['part.village_fence_'+name]={'kind':'tile','space':'world','owner':'VillageFenceVisual','task':'VPROP-005','source':{'kind':'master','file':str((REPORT/'source.json').relative_to(ROOT)),'sha256':sha(REPORT/'source.json')},'filter':'linear','sampling_family':'painted_world','default_quality':'standard','views':{'south':{'logical_size':[w*.25,h*.25],'footprint_size':[24,24],'pivot':[.5,1],'variants':{'standard':{'texture':tid,'source_rect':[0,0,w,h]}}}}}
    p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')

def verify():
    """Reject changed masters, stale geometry, alpha loss or a nonuniform derivative."""
    source=json.loads((REPORT/'source.json').read_text());profile=json.loads((RUNTIME/'profile.json').read_text())
    assert source['task']==profile['task']=='VPROP-005' and set(source['parts'])==set(HEIGHTS)
    assert source['parts']==profile['parts'] and profile['render_scale']==.25
    for name,row in source['parts'].items():
        raw,expected=derive(name);assert all(row[k]==v for k,v in expected.items())
        assert (ROOT/row['runtime']).read_bytes()==raw and sha(ROOT/row['runtime'])==row['sha256']
        with Image.open(ROOT/row['runtime']) as im:
            assert im.mode=='RGBA';a=im.getchannel('A');box=a.getbbox();assert box and min(box[0],box[1],im.width-box[2],im.height-box[3])>=8
    print('FENCE ASSETS: three independent alpha parts; uniform density, exact masters and padding')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--build',action='store_true');a=p.parse_args()
    if a.build:build()
    verify()
