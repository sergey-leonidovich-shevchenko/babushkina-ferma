#!/usr/bin/env python3
"""Derive six cardinal street props without repainting alpha or stretching axes."""
import argparse,hashlib,io,json
from pathlib import Path
from PIL import Image
from common.paths import project_root
from common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-006'
RUNTIME=ROOT/'assets/game/locations/overworld/boards'
SIDES=['south','west','east']
ANCHORS={'board-south':[728.5,997],'board-west':[728,1017],'board-east':[730,1024],
         'sign-south':[627,1200],'sign-west':[621,1196],'sign-east':[626,1202]}
CONTACTS={'board-south':[[114,997,True],[1343,997,True]],
          'board-west':[[728,1017,True],[728,963,False]],'board-east':[[730,1024,True],[730,945,False]],
          'sign-south':[[627,1200,True]],'sign-west':[[621,1196,True]],'sign-east':[[626,1202,True]]}

def sha(path):
    """Bind retained masters, runtime PNG and documentary provenance to exact bytes."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def derive(kind,side):
    """Crop opaque furniture with headroom and uniformly downsample once at authoring time."""
    key=kind+'-'+side;path=REPORT/'masters'/(key+'.png')
    with Image.open(path) as master:
        image=master.convert('RGBA');box=image.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
        x0,y0,x1,y1=box;rect=[max(0,x0-8),max(0,y0-8),min(image.width,x1+8),min(image.height,y1+8)]
        crop=image.crop(rect);major=288
        factor=major/crop.height
        size=[round(crop.width*factor),round(crop.height*factor)];crop=crop.resize(size,Image.Resampling.LANCZOS)
        output=Image.new('RGBA',(size[0]+16,size[1]+16));output.paste(crop,(8,8))
        def point(p):return [8+(p[0]-rect[0])*size[0]/(rect[2]-rect[0]),8+(p[1]-rect[1])*size[1]/(rect[3]-rect[1])]
        contacts=[]
        for p in CONTACTS[key]:
            if p[2]:assert image.getpixel(tuple(p[:2]))[3]>=200,'visible contact outside solid prop'
            contacts.append({'point':point(p),'visible':p[2]})
        raw=io.BytesIO();output.save(raw,format='PNG')
        return raw.getvalue(),{'master':'masters/'+key+'.png','master_sha256':sha(path),'crop':rect,'pixels':list(output.size),
            'anchor':point(ANCHORS[key]),'contacts':contacts,'source_contacts':CONTACTS[key],'source_anchor':ANCHORS[key],
            'authoring_major':major,'render_scale':.25,'runtime':str((RUNTIME/(kind+'_'+side+'_v1.png')).relative_to(ROOT))}

def build():
    """Register only six addressable derivatives; original large masters stay outside runtime."""
    RUNTIME.mkdir(parents=True,exist_ok=True);rows={};profile={'schema':1,'task':'VPROP-006','render_scale':.25,'props':{}}
    for kind in ['board','sign']:
        views={}
        for side in SIDES:
            raw,row=derive(kind,side);path=ROOT/row['runtime'];path.write_bytes(raw);row['sha256']=sha(path);rows[kind+'-'+side]=row
            views[side]={k:row[k] for k in ['pixels','anchor','contacts']}
        profile['props'][kind]={'views':views}
    source={'schema':1,'task':'VPROP-006','tool':'built-in image_gen','render_scale':.25,'views':rows,
        'calibration':'Both families share uniformly derived authoring height288 and render scale0.25. Measured contacts anchor two existing solid boards and three existing non-solid direction signs. No runtime fitting or axis stretch; no text baked into any PNG.',
        'alpha':'Opaque-prop ROI alpha>=8 plus 8 source pixels, preserving RGBA. Brown RGB at alpha=0 is retained and never made opaque. No background keying or painted edits.',
        'contacts':'Front board has two measured post feet. Side far support is occluded, with inferred position visible=false, not claimed as a visible pixel. Every sign has one measured post foot. Blank papers/planks were manually inspected; labels remain live six-locale wayfinding text.'}
    (REPORT/'source.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n')
    (RUNTIME/'profile.json').write_text(json.dumps(profile,indent=2)+'\n')
    p=ROOT/'assets/game/visual_resources.json';catalog=json.loads(p.read_text())
    for kind in ['board','sign']:
        views={}
        for side in SIDES:
            row=rows[kind+'-'+side];tid='village_'+kind+'_'+side+'_v1';w,h=row['pixels']
            catalog['textures'][tid]={'file':'res://'+row['runtime'],'pixels':[w,h],'sha256':row['sha256'],'layout':'standalone',
                'import':{'compress/mode':0,'mipmaps/generate':False,'process/fix_alpha_border':True,'process/premult_alpha':False},'intent':'color_srgb'}
            footprint=([72,24] if side=='south' else [24,72]) if kind=='board' else [24,24]
            views[side]={'logical_size':[w*.25,h*.25],'footprint_size':footprint,'pivot':[row['anchor'][0]/w,row['anchor'][1]/h],
                'variants':{'standard':{'texture':tid,'source_rect':[0,0,w,h]}}}
        catalog['resources']['prop.village_'+kind]={'kind':'prop','space':'world','owner':'VillageBoardVisual + VillagePropRenderer','task':'VPROP-006',
            'source':{'kind':'master','file':str((REPORT/'source.json').relative_to(ROOT)),'sha256':sha(REPORT/'source.json')},
            'filter':'linear','sampling_family':'painted_world','default_quality':'standard','views':views}
    p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')

def verify():
    """Reject stale source bytes, clipped alpha, altered pivots, missing views or fabricated contacts."""
    source=json.loads((REPORT/'source.json').read_text());profile=json.loads((RUNTIME/'profile.json').read_text())
    assert set(source['views'])==set(ANCHORS) and set(profile['props'])=={'board','sign'} and profile['render_scale']==.25
    for kind in ['board','sign']:
        assert set(profile['props'][kind]['views'])==set(SIDES)
        for side in SIDES:
            row=source['views'][kind+'-'+side];raw,expected=derive(kind,side)
            assert (ROOT/row['runtime']).read_bytes()==raw and sha(ROOT/row['runtime'])==row['sha256']
            assert all(row[k]==v for k,v in expected.items())
            assert profile['props'][kind]['views'][side]=={k:row[k] for k in ['pixels','anchor','contacts']}
            with Image.open(ROOT/row['runtime']) as image:
                box=image.getchannel('A').getbbox();assert min(box[0],box[1],image.width-box[2],image.height-box[3])>=8
    print('BOARD ASSETS: six cardinal PNG, exact derivatives/alpha/pivots and documented visible/occluded contacts')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--build',action='store_true');args=parser.parse_args()
    if args.build:build()
    verify()
