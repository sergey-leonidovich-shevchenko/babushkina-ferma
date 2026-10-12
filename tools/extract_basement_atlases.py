# coding: utf-8
"""Copies unchanged approved pixels; records measured AtlasTexture regions."""
from pathlib import Path
from PIL import Image
import shutil, json
root=Path(__file__).resolve().parents[1]
out=root/'assets/game/basement'; out.mkdir(parents=True,exist_ok=True)
sources=root/'docs/design/cellar-workshop'
cuts={
 'pottery':([0,378,696,1055,1402],[0,304,580,859,1122]),
 'sawmill':([0,377,699,1059,1402],[0,320,589,864,1122]),
 'glassblowing':([0,379,703,1052,1402],[0,327,623,899,1122]),
 'forge':([0,393,729,1105,1470],[0,281,536,823,1070]),
 'alchemy':([0,408,706,1096,1448],[0,242,516,824,1086]),
 'workbench':([0,396,700,1055,1402],[0,286,580,855,1122]),
 'furnace':([0,336,639,959,1292],[0,295,597,947,1218]),
 'cauldron':([0,398,707,1068,1408],[0,271,559,866,1117]),
 'study':([0,448,764,1190,1536],[0,270,535,806,1024]),
 'recycling':([0,427,767,1179,1536],[0,255,514,799,1024])}
metadata={'choice':'A','grid':24,'directions':['south','west','north','east'],'sprites':{}}
preloads={}
# Сохраняет полный измеренный силуэт в отдельном ресурсе без изменения исходных пикселей.
def resource(name,source,bounds):
 im=Image.open(source); mask=im.getchannel('A').point(lambda a:255 if a>8 else 0)
 box=mask.crop(bounds).getbbox()
 assert box is not None,name
 x=max(bounds[0],bounds[0]+box[0]-3); y=max(bounds[1],bounds[1]+box[1]-3)
 right=min(bounds[2],bounds[0]+box[2]+3); bottom=min(bounds[3],bounds[1]+box[3]+3)
 width,height=right-x,bottom-y
 atlas=out/source.name
 shutil.copy2(source,atlas)
 text='[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://assets/game/basement/'+source.name+'" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, %d, %d)\nfilter_clip = true\n'%(x,y,width,height)
 (out/(name+'.tres')).write_text(text)
 metadata['sprites'][name]={'atlas':atlas.name,'region':[x,y,width,height],'pivot':[width/2,height],'alpha_corners':[im.getchannel('A').getpixel((i,j)) for i,j in [(x,y),(right-1,y),(x,bottom-1),(right-1,bottom-1)]]}
 return 'preload("res://assets/game/basement/'+name+'.tres")'
for kind,(xs,ys) in cuts.items():
 src=sources/'sprites'/(kind+('-4dir-alpha.png' if kind in ['study','recycling'] else '-4dir.png'))
 target=sources/'sprites'/(kind+'_atlas_a.png'); shutil.copy2(src,target)
 rows=[]
 for r in range(4):
  row=[]
  for c,direction in enumerate(metadata['directions']):
   name=kind+'_'+str(r+1)+'_'+direction
   row.append(resource(name,target,(xs[c],ys[r],xs[c+1],ys[r+1])))
  rows.append('['+','.join(row)+']')
 preloads[kind]='['+','.join(rows)+']'
shutil.copy2(sources/'shell-a.png',sources/'shell_atlas_a.png')
shell=['wall','corner_left','corner_right','post','lantern','blueprint','stairs_up','stairs_down','crates','barrel','materials','beam']
shell_preloads={}
for r in range(3):
 xs=[[0,430,735,1080,1448],[0,350,715,1080,1448],[0,350,650,1020,1448]][r]; ys=[0,355,732,1086]
 for c in range(4):
  name=shell[r*4+c]; shell_preloads[name]=resource(name,sources/'shell_atlas_a.png',(xs[c],ys[r],xs[c+1],ys[r+1]))
shutil.copy2(sources/'floor-a.png',out/'floor_a.png')
(out/'sprites.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
code='extends RefCounted\n\nconst SPRITES := {\n'+''.join('\t"'+k+'":'+v+',\n' for k,v in preloads.items())+'}\nconst SHELL := {\n'+''.join('\t"'+k+'":'+v+',\n' for k,v in shell_preloads.items())+'}\n\n## Выбирает отдельный ракурс нужного уровня либо собственной строительной кучи.\nstatic func texture(kind: String, level: int, direction: int, pile: bool=false) -> AtlasTexture:\n\treturn SPRITES[kind][3 if pile else clampi(level,1,3)-1][posmod(direction,4)]\n\n## Совмещает полный силуэт с нижней опорой основания без растяжения или растровых поворотов.\nstatic func destination(item: Dictionary, pile: bool=false) -> Rect2:\n\tvar bounds:=preload("res://scripts/systems/basement_layout_system.gd").rect(item)\n\tvar size:=texture(item.kind,int(item.get("level",1)),int(item.direction),pile).get_size()\n\tvar width:=maxf(bounds.size.x,72)+24; var height:=120.0 if pile else 168.0\n\tsize*=minf(width/size.x,height/size.y)\n\treturn Rect2(Vector2(bounds.get_center().x-size.x/2,bounds.end.y-size.y),size)\n'
(root/'scripts/presentation/basement_visual_system.gd').write_text(code)
print('172 measured resources and 12 unchanged source textures extracted')
