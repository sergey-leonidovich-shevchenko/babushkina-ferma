#!/usr/bin/env python3
"""Числовая диагностика возможного matte; исходные изображения не изменяет."""
from __future__ import annotations
from collections import deque
from PIL import Image, ImageChops, ImageFilter

VERSION=1
TARGETS={'white':(255,255,255),'magenta':(255,0,255)}
OFFSETS=[(dx*d,dy*d) for d in [2,3,4,6] for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)]]


def threshold(channel: Image.Image, low: int, high: int=255) -> Image.Image:
    """Строит двоичную диагностическую маску без изменения каналов источника."""
    return channel.point([255 if low<=v<=high else 0 for v in range(256)])


def colour_mask(image: Image.Image, name: str) -> Image.Image:
    """Выделяет светлый нейтральный либо насыщенный пурпурный цвет, а не все светлые детали."""
    r,g,b,_=image.split()
    if name=='white':
        low=ImageChops.darker(ImageChops.darker(r,g),b);high=ImageChops.lighter(ImageChops.lighter(r,g),b)
        return ImageChops.darker(threshold(low,208),threshold(ImageChops.subtract(high,low),0,32))
    mask=ImageChops.darker(threshold(r,150),threshold(b,125))
    for other in [threshold(g,0,95),threshold(ImageChops.subtract(r,g),75),threshold(ImageChops.subtract(b,g),55)]:mask=ImageChops.darker(mask,other)
    return mask


def components(points: dict[tuple[int,int],dict], minimum: int=3) -> list[dict]:
    """Группирует соседние сигналы, оставляя маленькие отдельные блики вне списка подозрительных полос."""
    remaining=set(points);result=[]
    while remaining:
        seed=remaining.pop();queue=deque([seed]);group=[]
        while queue:
            point=queue.popleft();group.append(point);x,y=point
            for yy in range(y-1,y+2):
                for xx in range(x-1,x+2):
                    if (xx,yy) in remaining:remaining.remove((xx,yy));queue.append((xx,yy))
        if len(group)<minimum:continue
        x=[p[0] for p in group];y=[p[1] for p in group]
        result.append({'pixels':len(group),'bbox':[min(x),min(y),max(x)+1,max(y)+1],
                       'sample':sorted(group,key=lambda p:(p[1],p[0]))[:4],
                       'kinds':sorted({points[p]['kind'] for p in group})})
    return sorted(result,key=lambda e:(-e['pixels'],e['bbox']))


def analyse(source: Image.Image, intent: str='color_srgb') -> dict:
    """Ищет цветовой сдвиг края относительно плотного внутреннего участка; числа масок не считает цветом."""
    if intent=='data_rgba8':return {'classification':'data_mask','findings':[]}
    if intent!='color_srgb':raise ValueError('unknown texture intent')
    image=source.convert('RGBA');alpha=image.getchannel('A');hist=alpha.histogram();w,h=image.size
    result={'classification':'transparent_sprite','pixels':[w,h],'alpha_zero':hist[0],
            'alpha_soft':sum(hist[1:240]),'alpha_dense':sum(hist[240:]),'findings':[],'invisible_rgb':{}}
    if hist[255]==w*h:result['classification']='opaque_surface';return result
    if hist[0]==w*h:result['classification']='empty_alpha';return result
    visible=threshold(alpha,16);border=ImageChops.subtract(visible,visible.filter(ImageFilter.MinFilter(5)))
    core=threshold(alpha,240).filter(ImageFilter.MinFilter(3));dense=core.load();values=image.load()
    for name,target in TARGETS.items():
        colour=colour_mask(image,name)
        result['invisible_rgb'][name]=ImageChops.darker(colour,threshold(alpha,0,0)).histogram()[255]
        candidates=ImageChops.darker(colour,border).tobytes();near_target=colour.load();points={}
        index=candidates.find(b'\xff')
        while index>=0:
            x,y=index%w,index//w;r,g,b,a=values[x,y];inner=None
            for dx,dy in OFFSETS:
                xx,yy=x+dx,y+dy
                if 0<=xx<w and 0<=yy<h and dense[xx,yy]:inner=(xx,yy);break
            if inner is not None and not near_target[inner]:
                rgb=(r,g,b);inside=values[inner][:3]
                clean=sum(abs(v-f) for v,f in zip(rgb,inside))
                distance=lambda c:sum(abs(v-t) for v,t in zip(c,target))
                if clean>=100 and distance(inside)-distance(rgb)>=100:
                    predicted=[f*a/255+t*(1-a/255) for f,t in zip(inside,target)]
                    mixed=sum(abs(v-p) for v,p in zip(rgb,predicted))
                    if a<240 and mixed<clean*.65:points[x,y]={'kind':'soft_matte'}
                    elif a>=240:points[x,y]={'kind':'opaque_colour_rim'}
            index=candidates.find(b'\xff',index+1)
        groups=components(points)
        if groups:result['findings'].append({'colour':name,'candidate_pixels':sum(e['pixels'] for e in groups),'components':len(groups),'regions':groups[:16]})
    return result
