#!/usr/bin/env python3
"""Проверяет геометрию кадров и измеряет запас, не изменяя изображения."""
from __future__ import annotations
import math
from PIL import Image,ImageChops


def vector(value, count):
    """Отклоняет нечисловые и бесконечные координаты до операций с изображением."""
    return isinstance(value,list) and len(value)==count and all(type(x) in [int,float] and math.isfinite(x) for x in value)


def geometry(frame, size):
    """Отличает геометрическую ошибку от осознанной опоры либо прозрачного поля."""
    errors=[];rect=frame.get('rect')
    if not vector(size,2) or min(size)<=0:return ['invalid texture size']
    if not vector(rect,4) or any(v!=int(v) for v in rect):return ['invalid integer source rect']
    x,y,w,h=rect
    if min(x,y)<0 or min(w,h)<=0 or x+w>size[0] or y+h>size[1]:errors.append('source rect outside texture')
    pivot=frame.get('pivot')
    if not frame.get('resource_only',False):
        if not vector(pivot,2):errors.append('missing or invalid pivot')
        elif not (0<=pivot[0]<=w and 0<=pivot[1]<=h):errors.append('pivot outside frame')
    if type(frame.get('scale')) not in [int,float] or not math.isfinite(frame['scale']) or frame['scale']<=0:errors.append('invalid scale')
    return errors


def chain_errors(chain):
    """Проверяет каждую вложенную область атласа до конечного исходника; нулевая область означает весь атлас Godot."""
    errors=[]
    if not isinstance(chain,list) or not chain:return ['missing texture provenance chain']
    if any(not isinstance(row,dict) or not isinstance(row.get('class'),str) or not vector(row.get('pixels'),2) or min(row['pixels'])<=0 for row in chain):return ['invalid texture provenance chain']
    for index,row in enumerate(chain):
        if row['class']!='AtlasTexture':continue
        if index+1>=len(chain):errors.append('atlas has no source');continue
        rect=row.get('region')
        if vector(rect,4) and rect==[0,0,0,0]:rect=[0,0,*chain[index+1]['pixels']]
        errors.extend(geometry({'rect':rect,'resource_only':True,'scale':1.0},chain[index+1]['pixels']))
        margin=row.get('margin')
        if not vector(margin,4) or min(margin)<0 or margin[0]>margin[2] or margin[1]>margin[3]:errors.append('invalid atlas margin')
    return errors


def measure(alpha: Image.Image, rect: list) -> dict:
    """Измеряет слабую и плотную альфу, поля и продолжения через рамку; не объявляет каждое касание обрезанной фигурой."""
    x,y,w,h=map(int,rect);crop=alpha.crop((x,y,x+w,y+h));result={}
    for threshold in [1,26]:
        mask=crop.point([255 if n>=threshold else 0 for n in range(256)]);bbox=mask.getbbox()
        result['alpha'+str(threshold)]={'bbox':list(bbox) if bbox else None,'margins':[bbox[0],bbox[1],w-bbox[2],h-bbox[3]] if bbox else None}
    full=alpha.point([255 if n>=26 else 0 for n in range(256)])
    pairs=[]
    if x>0:pairs.append(((x,y,x+1,y+h),(x-1,y,x,y+h)))
    if y>0:pairs.append(((x,y,x+w,y+1),(x,y-1,x+w,y)))
    if x+w<alpha.width:pairs.append(((x+w-1,y,x+w,y+h),(x+w,y,x+w+1,y+h)))
    if y+h<alpha.height:pairs.append(((x,y+h-1,x+w,y+h),(x,y+h,x+w,y+h+1)))
    result['boundary_connections']=sum(ImageChops.darker(full.crop(a),full.crop(b)).histogram()[255] for a,b in pairs)
    return result
