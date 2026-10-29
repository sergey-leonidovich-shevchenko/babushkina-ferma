#!/usr/bin/env python3
"""Derive a small cardinal trading kit with preserved RGBA and uniform scale."""
import argparse,hashlib,io,json
from pathlib import Path
from PIL import Image
from common.paths import project_root
from common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
REPORT=ROOT/'docs/reports/visual-overhaul/vprop-007'
RUNTIME=ROOT/'assets/game/locations/overworld/trade'
SIDES=['south','west','east']
KINDS=['stall','crate','barrel','sack']
CONTACTS={'stall-south':[[150,1000],[1280,1000]],'stall-west':[[500,1030],[950,1030]],'stall-east':[[520,1032],[890,1032]],'crate-south':[[660,1012]],'crate-west':[[650,1008]],'crate-east':[[730,941]],'barrel-south':[[526,1180]],'sack-south':[[580,1253]]}

def sha(path):
    """Bind exact selected master and derivative bytes."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def key_for(kind,side):
    """Unmarked round barrel and sack deliberately have no directional face."""
    return kind+'-'+('south' if kind in ['barrel','sack'] else side)

def derive(key):
    """Crop with padding and uniformly downsample; never key, paint or stretch alpha."""
    kind,side=key.split('-');path=REPORT/'masters'/(key+'.png')
    with Image.open(path) as src:
        im=src.convert('RGBA');box=im.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
        rect=[max(0,box[0]-8),max(0,box[1]-8),min(im.width,box[2]+8),min(im.height,box[3]+8)]
        crop=im.crop(rect);major=300 if kind=='stall' else (192 if kind=='sack' else 96)
        factor=major/(crop.height if kind=='stall' else crop.width);size=[round(crop.width*factor),round(crop.height*factor)]
        crop=crop.resize(size,Image.Resampling.LANCZOS);out=Image.new('RGBA',(size[0]+16,size[1]+16));out.paste(crop,(8,8))
        def point(p):return [8+(p[0]-rect[0])*size[0]/(rect[2]-rect[0]),8+(p[1]-rect[1])*size[1]/(rect[3]-rect[1])]
        contacts=CONTACTS[key]
        for p in contacts:assert im.getpixel(tuple(p))[3]>=200,'base contact outside solid pixels: '+key
        anchor=[sum(p[0] for p in contacts)/len(contacts),max(p[1] for p in contacts)]
        raw=io.BytesIO();out.save(raw,format='PNG')
        return raw.getvalue(),{'master':'masters/'+key+'.png','master_sha256':sha(path),'crop':rect,'pixels':list(out.size),'anchor':point(anchor),'contacts':[point(p) for p in contacts],'source_contacts':contacts,'source_anchor':anchor,'authoring_major':major,'render_scale':.25,'runtime':str((RUNTIME/(kind+'_'+side+'_v1.png')).relative_to(ROOT))}

def build():
    """Create eight small PNGs and four props; neutral bodies share views explicitly."""
    RUNTIME.mkdir(parents=True,exist_ok=True);rows={};profile={'schema':1,'task':'VPROP-007','render_scale':.25,'props':{}}
    for key in CONTACTS:
        raw,row=derive(key);p=ROOT/row['runtime'];p.write_bytes(raw);row['sha256']=sha(p);rows[key]=row
    for kind in KINDS:
        profile['props'][kind]={'direction_independent':kind in ['barrel','sack'],'views':{s:{k:rows[key_for(kind,s)][k] for k in ['pixels','anchor','contacts']} for s in SIDES}}
    source={'schema':1,'task':'VPROP-007','tool':'built-in image_gen','render_scale':.25,'views':rows,'calibration':'Stall height300 authoring px; crate/barrel width96; sack width192; fixed uniform0.25 runtime density. Trading sack explicitly uses0.5 instance scale. Neutral unmarked round barrel/sack share one source across cardinal views. No texture mirroring, background removal or per-axis fit. Contact shadows are separate cached geometry. Measured lower visible supports/base anchor original gameplay positions; other maps and baked facade decorations remain legacy.'}
    (REPORT/'source.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n');(RUNTIME/'profile.json').write_text(json.dumps(profile,indent=2)+'\n')
    p=ROOT/'assets/game/visual_resources.json';catalog=json.loads(p.read_text())
    for key,row in rows.items():
        tid='village_trade_'+key.replace('-','_')+'_v1';catalog['textures'][tid]={'file':'res://'+row['runtime'],'pixels':row['pixels'],'sha256':row['sha256'],'layout':'standalone','import':{'compress/mode':0,'mipmaps/generate':False,'process/fix_alpha_border':True,'process/premult_alpha':False},'intent':'color_srgb'}
    for kind in KINDS:
        views={}
        for side in SIDES:
            key=key_for(kind,side);r=rows[key];w,h=r['pixels'];footprint=([96,48] if side=='south' else [48,96]) if kind=='stall' else ([48,24] if kind=='sack' else [24,24])
            views[side]={'logical_size':[w*.25,h*.25],'footprint_size':footprint,'pivot':[r['anchor'][0]/w,r['anchor'][1]/h],'variants':{'standard':{'texture':'village_trade_'+key.replace('-','_')+'_v1','source_rect':[0,0,w,h]}}}
        catalog['resources']['prop.village_trade_'+kind]={'kind':'prop','space':'world','owner':'VillageTradeVisual + VillageEventRenderer/WorldLootRenderer','task':'VPROP-007','source':{'kind':'master','file':str((REPORT/'source.json').relative_to(ROOT)),'sha256':sha(REPORT/'source.json')},'filter':'linear','sampling_family':'painted_world','default_quality':'standard','views':views}
    p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')

def verify():
    """Reject clipped alpha, stale derivatives, invented contacts and undocumented neutral views."""
    source=json.loads((REPORT/'source.json').read_text());profile=json.loads((RUNTIME/'profile.json').read_text());catalog=json.loads((ROOT/'assets/game/visual_resources.json').read_text())
    assert set(source['views'])==set(CONTACTS) and set(profile['props'])==set(KINDS) and profile['render_scale']==.25
    for key,row in source['views'].items():
        raw,expected=derive(key);assert (ROOT/row['runtime']).read_bytes()==raw and sha(ROOT/row['runtime'])==row['sha256'];assert all(row[k]==v for k,v in expected.items())
        with Image.open(ROOT/row['runtime']) as im:
            b=im.getchannel('A').getbbox();assert min(b[0],b[1],im.width-b[2],im.height-b[3])>=8
    for kind in KINDS:
        assert set(profile['props'][kind]['views'])==set(SIDES) and profile['props'][kind]['direction_independent']==(kind in ['barrel','sack'])
        for side in SIDES:
            row=source['views'][key_for(kind,side)];assert profile['props'][kind]['views'][side]=={k:row[k] for k in ['pixels','anchor','contacts']}
            entry=catalog['resources']['prop.village_trade_'+kind];view=entry['views'][side];w,h=row['pixels'];assert view['logical_size']==[w*.25,h*.25] and view['pivot']==[row['anchor'][0]/w,row['anchor'][1]/h]
    print('TRADE ASSETS: eight exact RGBA derivatives, four props, three cardinal views and explicit neutral aliases')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--build',action='store_true');args=parser.parse_args()
    if args.build:build()
    verify()
