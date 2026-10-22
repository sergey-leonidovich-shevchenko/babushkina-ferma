#!/usr/bin/env python3
"""Build the reviewed VSHADOW-001 inventory; this never modifies game artwork."""
import csv,hashlib,io,json,re,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'docs/reports/visual-overhaul/vshadow-001'
OWNERS={'benches':'village_bench_visual.gd','street_props':'village_street_visual.gd','lamps':'village_lamp_visual.gd','boards':'village_board_visual.gd','trade':'village_trade_visual.gd','fences':'village_fence_visual.gd'}
RULES=[
 ('scripts/systems/render_system.gd','draw','World order; no global projected solar pass.'),
 ('scripts/systems/tree_occlusion_system.gd','draw_packet','Opacity/depth only; does not create ground shadows.'),
 ('scripts/systems/interior_renderer.gd','draw_textured_shell','Floor-wall AO band and room perimeter retained; not solar projection.'),
 ('scripts/systems/hero_visual_system.gd','draw_actor','One existing separate contact ellipse; raster material shading stays.'),
 ('scripts/systems/resident_visual_system.gd','draw_actor','Common actor contact; do not stack another per-resident overlay.'),
 ('scripts/systems/directional_character_system.gd','draw_soft_shadow','Fixed ellipse, no calendar-dependent direction.'),
 ('scripts/systems/livestock_visual_system.gd','draw','Two soft ellipse passes form one contact effect; do not add a third.'),
 ('scripts/systems/wildlife_visual_system.gd','draw_contact_shadow','Existing contact; full animation catalogue not visually reaccepted.'),
 ('scripts/systems/cave_renderer.gd','_draw_shadow','Existing contact ellipses; context inventory, no cave redesign.'),
 ('scripts/systems/cave_boss_renderer.gd','shadow','Existing boss/minion contact; outside first-map implementation.'),
 ('scripts/systems/village_terrain_renderer.gd','draw_banks','Bank material/edge contrast is not a solar caster.'),
 ('scripts/systems/atmosphere_renderer.gd','draw','Screen darkness and lamp glow, not projected solar geometry.'),
 ('scripts/presentation/village_bench_visual.gd','draw_shadow','One cached mesh, four contact points.'),
 ('scripts/presentation/village_street_visual.gd','draw_shadow','Cached contacts at base/wheels.'),
 ('scripts/presentation/village_board_visual.gd','draw_shadow','Cached contacts at posts.'),
 ('scripts/presentation/village_lamp_visual.gd','draw_shadow','Static base contact; glow separate.'),
 ('scripts/presentation/village_trade_visual.gd','draw_shadow','Existing contact per visible component.'),
 ('scripts/presentation/village_fence_visual.gd','draw_section','Posts/rails body only, no shadow helper.')]

def sha(path):
    """Bind exact bytes, including the immutable source art."""
    return hashlib.sha256(path.read_bytes()).hexdigest()

def paths():
    """Cover every registered village prop/view and the existing adjacent raster families."""
    data=json.loads((ROOT/'assets/game/visual_resources.json').read_text());result=[]
    for name,r in data['resources'].items():
        if name.startswith(('prop.village','part.village')):
            for view in r['views'].values():
                for v in view['variants'].values():
                    p=data['textures'][v['texture']]['file'].removeprefix('res://')
                    if p not in result:result.append(p)
    result+=sorted(str(p.relative_to(ROOT)) for p in (ROOT/'assets/game/buildings/exteriors').glob('*.png'))
    result+=['assets/game/environment/'+n for n in ['village_ambient_atlas_v1.png','forest_tree_growth_atlas_v1.png','forest_tree.png','seasons/tree_spring.png','seasons/tree_summer.png','seasons/tree_autumn.png','seasons/tree_winter.png']]
    return result+['assets/game/interiors/village_interior_atlas_v2.png']

def classify(name):
    """Encode manual review decisions; dark pixels alone never establish a cast mask."""
    if '/locations/overworld/' in name:
        family=Path(name).parent.name
        return family,'none_visible_outside_body','none_visible','existing_contact_mesh' if family!='fences' else 'none',OWNERS[family],'preserve_material_shading_and_existing_contact'
    if '/buildings/' in name:
        return 'facades','painted_base_edge_and_step_ao','no_extended_ground_cast_visible','none','building_visual_system.gd','retain_step_ao_do_not_treat_dark_roof_as_ground_cast'
    if '/seasons/' in name or '/forest_tree' in name:
        return 'trees','painted_root_base_and_ground_fragments','no_independent_mask','none','environment_visual_system.gd / game_renderer.gd','separate_or_redraw_base_before_projected_cast_do_not_alpha_cut_roots'
    if '/interiors/' in name:
        return 'interior_context','painted_object_base_ao','no_independent_mask','floor_wall_band_only','interior_renderer.gd / interior_visual_system.gd','retain_raster_ao_no_interior_implementation'
    return 'ambient_atlas','painted_turf_stone_and_object_base','no_independent_mask','none','village_ambient_renderer.gd','per_cell_review_do_not_treat_lilies_or_turf_as_cast'

def build():
    """Export a source-bound inventory, CSV and review sheets separately from runtime."""
    rows=[]
    for name in paths():
        p=ROOT/name
        with Image.open(p) as image:size=list(image.size)
        family,contact,solar,separate,owner,decision=classify(name)
        rows.append({'file':name,'sha256':sha(p),'pixels':size,'family':family,'material_shading':'retain','baked_contact':contact,'baked_solar':solar,'separate_runtime_contact':separate,'owner':owner,'decision':decision})
    rules=[]
    for name,function,rule in RULES:
        p=ROOT/name;text=p.read_text();anchor='func '+function+'('
        if anchor not in text:raise ValueError('missing owner: '+name+':'+function)
        rules.append({'file':name,'sha256':sha(p),'function':function,'line':text[:text.index(anchor)].count('\n')+1,'rule':rule})
    data={'schema':1,'task':'VSHADOW-001','base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'runtime_changed':False,'dynamic_solar_implemented':False,'performance_eligible':False,'full_map_accepted':False,'scope':'All registered village prop PNG/views plus eight existing facades, six tree/growth rasters, ambient and legacy interior atlases. Actors/crops/fallbacks remain under renderer ownership; this is not a full animation catalogue acceptance.','review_method':'Manual RGBA review on checkerboard; distinguish material self shading, baked base/ground fragments and separately drawn contact. No dark-pixel extraction.','raster_gate':'Unreviewed or changed source cannot receive a new cast under this inventory. Keep material shading; separate or redraw inseparable base before adding projected cast.','assets':rows,'renderer_rules':rules,'followups':{'VSHADOW-002':'Reuse/replace existing contacts; never stack duplicates.','VSHADOW-003':'Separate ground/wall receivers from raster self shading.','VSHADOW-004':'Upper-left sun agreed; add separately disableable cast only after base review.','VSHADOW-005':'One presented-ground actor contact; inspect complete animation masks before projected cast.','VSHADOW-006':'Three views, same contact ownership.','VSHADOW-007':'Retain interior wall band; no new interior work here.','VSHADOW-008':'Bank AO separate from water/bridge receiver.','VSHADOW-009':'Bound active casts; no frame budget accepted here.','VSHADOW-010':'Final day/evening shadow acceptance remains open.'}}
    (REPORT/'inventory.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    fields=['file','sha256','family','baked_contact','baked_solar','separate_runtime_contact','owner','decision'];buf=io.StringIO();writer=csv.DictWriter(buf,fieldnames=fields,extrasaction='ignore');writer.writeheader();writer.writerows(rows);(REPORT/'inventory.csv').write_text(buf.getvalue())
    font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',12)
    for start in range(0,len(rows),16):
        sheet=Image.new('RGB',(1200,1000),'#eee6d4');draw=ImageDraw.Draw(sheet)
        for k,row in enumerate(rows[start:start+16]):
            x=(k%4)*300;y=(k//4)*250
            for xx in range(x,x+300,16):
                for yy in range(y,y+218,16):draw.rectangle((xx,yy,xx+15,yy+15),fill='#bcb4a2' if ((xx-x)//16+(yy-y)//16)%2 else '#eee6d4')
            with Image.open(ROOT/row['file']) as source:
                preview=source.convert('RGBA');preview.thumbnail((280,204));sheet.paste(preview,(x+(300-preview.width)//2,y+6),preview)
            draw.text((x+4,y+222),Path(row['file']).parent.name+'/'+Path(row['file']).name,fill='black',font=font)
        sheet.save(REPORT/f'rgba-review-{start//16}.png')
    print('SHADOW INVENTORY:',len(rows),'RGBA sources;',len(rules),'renderer owners')

if __name__=='__main__':build()
