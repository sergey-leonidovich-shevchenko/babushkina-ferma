#!/usr/bin/env python3
"""Создаёт числовые отрицательные контроли только в новом диагностическом каталоге."""
import json
from pathlib import Path
from PIL import Image,ImageDraw
from alpha_metrics import analyse


def controls() -> dict[str,Image.Image]:
    """Строит целый предмет с белыми деталями, искусственную кайму и честные белый/пурпурный материалы."""
    canvas=Image.new('RGBA',(384,384));draw=ImageDraw.Draw(canvas)
    draw.rounded_rectangle((100,60,284,324),radius=44,fill=(105,68,39,255))
    draw.rectangle((144,144,240,204),fill=(250,245,230,255))
    draw.ellipse((160,224,224,288),fill=(235,230,220,255))
    clean=canvas.resize((96,96),Image.Resampling.LANCZOS)
    result={'clean-white-details':clean}
    for name,matte in [('white',(255,255,255)),('magenta',(255,0,255))]:
        image=clean.copy();px=image.load()
        for y in range(96):
            for x in range(96):
                r,g,b,a=px[x,y]
                if 0<a<240:px[x,y]=tuple(round(c*a/255+m*(1-a/255)) for c,m in zip((r,g,b),matte))+(a,)
        result[name+'-soft-matte']=image
        image=Image.new('RGBA',(96,96));draw=ImageDraw.Draw(image)
        draw.rectangle((24,14,72,82),fill=(105,68,39,255),outline=matte+(255,),width=1)
        draw.rectangle((36,36,60,50),fill=(250,245,230,255))
        result[name+'-opaque-rim']=image
    for name,colour in [('white-material',(244,240,231)),('magenta-material',(220,35,200))]:
        image=clean.copy();px=image.load()
        for y in range(96):
            for x in range(96):px[x,y]=colour+(px[x,y][3],)
        result[name]=image
    image=clean.copy();px=image.load()
    for y in range(96):
        for x in range(96):
            if px[x,y][3]==0:px[x,y]=((255,255,255,0) if x<48 else (255,0,255,0))
    result['invisible-rgb']=image
    return result


def create(destination: Path) -> None:
    """Отказывается перезаписывать папку или писать тестовые картинки в игровые assets."""
    destination=destination.resolve()
    if destination.exists() or 'assets' in destination.parts:raise ValueError('new diagnostic directory outside assets required')
    destination.mkdir(parents=True);rows=[]
    for name,image in controls().items():
        image.save(destination/(name+'.png'));rows.append({'id':name,'file':name+'.png','metrics':analyse(image)})
    (destination/'fixtures.json').write_text(json.dumps(rows,indent=2)+'\n')


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('directory',type=Path);create(parser.parse_args().directory)
