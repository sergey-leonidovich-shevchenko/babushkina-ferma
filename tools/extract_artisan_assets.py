"""Создаёт только метаданные нарезки; исходные RGBA-пиксели остаются неизменными."""
import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / 'docs/design/artisan-expansion-2026-10-13'
OUTPUT = ROOT / 'assets/game/artisan'


def cuts(projection, count):
    """Ищет прозрачные промежутки возле ожидаемых границ регулярной сетки."""
    size = len(projection)
    result = [0]
    for index in range(1, count):
        center = size * index / count
        radius = size / count * .23
        candidates = range(int(center-radius), int(center+radius)+1)
        result.append(min(candidates, key=lambda v: (projection[v], abs(v-center))))
    return result + [size]


def regions(path, rows, columns):
    """Измеряет силуэты каждого ряда по настоящей альфе, сохраняя прозрачное поле."""
    image = Image.open(path)
    alpha = image.getchannel('A')
    mask = alpha.point(lambda value: 255 if value >= 8 else 0)
    width, height = image.size
    ys = cuts([sum(mask.crop((0,y,width,y+1)).getdata()) for y in range(height)], rows)
    result = []
    for row in range(rows):
        xs = cuts([sum(mask.crop((x,ys[row],x+1,ys[row+1])).getdata()) for x in range(width)], columns)
        for col in range(columns):
            cell = (xs[col],ys[row],xs[col+1],ys[row+1])
            bounds = mask.crop(cell).getbbox()
            if not bounds: raise ValueError((path,row,col,'empty cell'))
            left,top,right,bottom = bounds
            rect = [max(cell[0],cell[0]+left-3),max(cell[1],cell[1]+top-3),min(cell[2],cell[0]+right+3),min(cell[3],cell[1]+bottom+3)]
            # Модель иногда немного сдвигает столбцы и удлиняет боковой ракурс.
            # Доращиваем регион до первого прозрачного края, не меняя ни одного пикселя.
            for edge in range(4):
                for _step in range(80):
                    x0,y0,x1,y1=rect
                    line=[(x0,y0,x1,y0+1),(x0,y1-1,x1,y1),(x0,y0,x0+1,y1),(x1-1,y0,x1,y1)][edge]
                    if alpha.crop(line).getextrema()[1]<8: break
                    if edge==0 and y0>0: rect[1]-=1
                    elif edge==1 and y1<height: rect[3]+=1
                    elif edge==2 and x0>0: rect[0]-=1
                    elif edge==3 and x1<width: rect[2]+=1
                    else: break
            result.append([rect[0],rect[1],rect[2]-rect[0],rect[3]-rect[1]])
    return result


def resource(name, atlas, rect):
    """Записывает целочисленную область и фильтрацию против соседних спрайтов."""
    text = '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
    text += f'[ext_resource type="Texture2D" path="res://assets/game/artisan/{atlas}" id="1"]\n\n'
    text += '[resource]\natlas = ExtResource("1")\n'
    text += 'region = Rect2(%s)\nfilter_clip = true\n' % ', '.join(map(str,rect))
    (OUTPUT/f'{name}.tres').write_text(text)


def main():
    """Собирает воспроизводимые ресурсы, реестр ракурсов и самостоятельные иконки."""
    OUTPUT.mkdir(parents=True,exist_ok=True)
    catalog = json.loads((DESIGN/'catalog.json').read_text())
    metadata = {}
    sprites = {}
    directions = ['south','west','north','east']
    for kind in catalog['stations']:
        source = DESIGN/f'{kind}-a.png'
        atlas = f'{kind}_atlas_a.png'
        shutil.copyfile(source,OUTPUT/atlas)
        measured = regions(source,4,4)
        metadata[atlas] = measured
        sprites[kind] = []
        for tier in range(4):
            row = []
            for index,direction in enumerate(directions):
                name = f'{kind}_{tier+1}_{direction}'
                resource(name,atlas,measured[tier*4+index]); row.append(f'preload("res://assets/game/artisan/{name}.tres")')
            sprites[kind].append('['+','.join(row)+']')
    icons = {}
    keys = list(catalog['items'])
    for board,side in [(0,4),(1,4),(2,3)]:
        source = DESIGN/f'items-{board}-a.png'; atlas = f'items_{board}_atlas_a.png'
        shutil.copyfile(source,OUTPUT/atlas)
        measured = regions(source,side,side); metadata[atlas] = measured
        for kind,rect in zip(keys[board*16:(board+1)*16],measured):
            resource(kind,atlas,rect); icons[kind] = f'preload("res://assets/game/artisan/{kind}.tres")'
    (DESIGN/'atlas-regions.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
    text = 'extends RefCounted\n\nconst SPRITES := {\n'
    text += ''.join('\t"'+kind+'":['+','.join(rows)+'],\n' for kind,rows in sprites.items())+'}\n'
    text += 'const ITEMS := {\n'+''.join('\t"'+kind+'":'+value+',\n' for kind,value in icons.items())+'}\n'
    (ROOT/'scripts/presentation/artisan_visual_system.gd').write_text(text)
    print('128 station regions + 41 item regions; source pixels unchanged')


if __name__ == '__main__':
    main()
