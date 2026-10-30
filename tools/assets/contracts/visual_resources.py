#!/usr/bin/env python3
"""Проверяет единый паспорт графики и реальные PNG до загрузки игрой."""
from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import Path
from tools.common.paths import project_root
from PIL import Image, ImageChops

ROOT = project_root(__file__)
MANIFEST = "assets/game/visual_resources.json"
REPORT = ROOT / "docs/reports/visual-overhaul/vpipeline-002"
SIDES = {"south", "west", "east"}
ALL_SIDES = SIDES | {"north", "southwest", "northwest", "northeast", "southeast", "front"}


def unique_pairs(pairs: list) -> dict:
    """Запрещает скрытую перезапись одинаковых ID при чтении JSON."""
    result={}
    for key,value in pairs:
        if key in result: raise ValueError("duplicate JSON key: "+key)
        result[key]=value
    return result


def parse(text: str) -> dict:
    """Читает паспорт без потери повторяющихся ключей при ошибке автора."""
    return json.loads(text,object_pairs_hook=unique_pairs)


def vector(value, count: int, minimum: float = 0, positive: bool = False) -> bool:
    """Отклоняет нечисловые, бесконечные и неполные координаты до любой геометрии."""
    return isinstance(value,list) and len(value)==count and all(
        type(x) in [int,float] and math.isfinite(x) and (x>minimum if positive else x>=minimum) for x in value)


def validate(root: Path, data: dict) -> list[str]:
    """Проверяет схему, ID, ракурсы, качества, альфу, целостность, импорт и отделение исходников."""
    errors, images, used = [], {}, set()
    if not isinstance(data,dict) or data.get("schema_version")!=1: return ["schema_version must be 1"]
    textures, resources = data.get("textures"), data.get("resources")
    if not isinstance(textures,dict) or not isinstance(resources,dict) or not resources:
        return ["textures/resources must be nonempty objects"]
    for key, texture in textures.items():
        label=f"textures.{key}"
        if not re.fullmatch(r"[a-z][a-z0-9_.-]+",key): errors.append(label+": invalid texture ID"); continue
        if not isinstance(texture,dict): errors.append(label+": expected object"); continue
        path=texture.get("file","")
        if not isinstance(path,str) or not path.startswith("res://assets/game/") or ".." in Path(path[6:]).parts:
            errors.append(label+": invalid runtime file"); continue
        file=(root/path[6:]).resolve()
        if not file.is_relative_to(root.resolve()): errors.append(label+": path escapes project"); continue
        if any((parent/".gdignore").exists() for parent in file.parents if parent.is_relative_to(root.resolve())):
            errors.append(label+": source is hidden by .gdignore"); continue
        try:
            raw=file.read_bytes()
            if hashlib.sha256(raw).hexdigest()!=texture.get("sha256"): errors.append(label+": SHA256 mismatch")
            with Image.open(file) as image:
                image.verify()
            with Image.open(file) as image:
                if image.format!="PNG" or image.mode not in ["RGB","RGBA"]: errors.append(label+": expected RGB/RGBA PNG")
                if list(image.size)!=texture.get("pixels"): errors.append(label+": pixel dimensions mismatch")
                images[key]=image.convert("RGBA").getchannel("A")
            if texture.get("layout") not in ["standalone","atlas"]: errors.append(label+": invalid layout")
            expected=texture.get("import",{})
            if not isinstance(expected,dict) or not {"compress/mode","mipmaps/generate","process/fix_alpha_border","process/premult_alpha"}<=expected.keys():
                errors.append(label+": missing import contract")
            else:
                source=Path(str(file)+".import").read_text()
                if 'source_file="'+path+'"' not in source: errors.append(label+": import source path mismatch")
                for option, value in expected.items():
                    match=re.search(r"^"+re.escape(option)+r"=(.+)$",source,re.M)
                    if not match or match[1]!=json.dumps(value,separators=(",",":")):
                        errors.append(label+": import mismatch: "+option)
        except (OSError,ValueError,SyntaxError) as exc:
            errors.append(label+": invalid image/import: "+str(exc))
    for id, record in resources.items():
        label=f"resources.{id}"
        if not re.fullmatch(r"[a-z][a-z0-9_.-]+",id) or not isinstance(record,dict): errors.append(label+": invalid ID/record"); continue
        if record.get("kind") not in ["prop","icon","tile","actor_frame"] or record.get("space") not in ["world","ui"]:
            errors.append(label+": invalid kind/space")
        if record.get("filter") not in ["nearest","linear"]: errors.append(label+": invalid filter")
        if not record.get("owner") or not record.get("task"): errors.append(label+": missing owner/task")
        source=record.get("source",{})
        if not isinstance(source,dict): errors.append(label+": invalid provenance"); source={}
        if source.get("kind")=="legacy_runtime":
            if not re.fullmatch(r"[a-f0-9]{40}",str(source.get("commit",""))): errors.append(label+": missing legacy commit")
        elif source.get("kind")=="master":
            master=(root/str(source.get("file",""))).resolve()
            if not master.is_relative_to(root.resolve()) or not any((parent/".gdignore").exists() for parent in master.parents if parent.is_relative_to(root.resolve())):
                errors.append(label+": master must stay in an ignored source tree")
            elif not master.is_file() or hashlib.sha256(master.read_bytes()).hexdigest()!=source.get("sha256"):
                errors.append(label+": master SHA256/file mismatch")
        else: errors.append(label+": missing source provenance")
        views=record.get("views",{})
        if not isinstance(views,dict) or not views: errors.append(label+": missing views"); continue
        if record.get("kind")=="prop" and set(views)!=SIDES: errors.append(label+": props require south/west/east only")
        if set(views)-ALL_SIDES: errors.append(label+": unknown direction")
        quality_set=None
        for side, view in views.items():
            place=label+"."+side
            if not isinstance(view,dict): errors.append(place+": invalid view"); continue
            for field in ["logical_size","footprint_size","pivot"]:
                if not vector(view.get(field),2,positive=field=="logical_size"): errors.append(place+": invalid "+field)
            if vector(view.get("pivot"),2) and max(view["pivot"])>1: errors.append(place+": pivot outside normalized bounds")
            if record.get("kind")=="prop" and record.get("space")=="world" and vector(view.get("footprint_size"),2):
                footprint=view["footprint_size"]
                if any(not math.isclose(x%24,0,abs_tol=1e-6) for x in footprint) or (min(footprint)==0 and max(footprint)>0):
                    errors.append(place+": footprint must match the 24-unit grid or be empty")
            variants=view.get("variants",{})
            if not isinstance(variants,dict) or not isinstance(record.get("default_quality"),str) or record.get("default_quality") not in variants:
                errors.append(place+": missing default quality"); continue
            if quality_set is not None and set(variants)!=quality_set: errors.append(place+": inconsistent qualities across views")
            quality_set=set(variants); aspect=None
            for quality, variant in variants.items():
                address=place+"."+quality
                if not isinstance(variant,dict): errors.append(address+": invalid variant"); continue
                if set(variant)!={"texture","source_rect"}: errors.append(address+": unexpected variant fields")
                key=variant.get("texture")
                if not isinstance(key,str): errors.append(address+": invalid texture ID"); continue
                used.add(key)
                if key not in textures: errors.append(address+": missing texture ID"); continue
                rect=variant.get("source_rect")
                if not vector(rect,4) or any(x!=int(x) for x in rect) or min(rect[2:])<=0:
                    errors.append(address+": invalid source rect"); continue
                if key not in images: continue
                x,y,w,h=map(int,rect); alpha=images[key]
                if x+w>alpha.width or y+h>alpha.height: errors.append(address+": source rect outside texture"); continue
                crop=alpha.crop((x,y,x+w,y+h))
                if crop.getbbox() is None: errors.append(address+": empty alpha frame")
                bounds=alpha.getbbox()
                if textures[key].get("layout")=="standalone" and bounds and not (x<=bounds[0] and y<=bounds[1] and x+w>=bounds[2] and y+h>=bounds[3]):
                    errors.append(address+": source rect clips visible alpha")
                if aspect is not None and not math.isclose(w/h,aspect,rel_tol=1e-6): errors.append(address+": quality changes aspect ratio")
                aspect=w/h
    for key in textures.keys()-used: errors.append("unused texture ID: "+key)
    return errors


def main() -> None:
    """Проверяет текущий паспорт без пересоздания ресурсов или хешей при ошибке."""
    errors=validate(ROOT,parse((ROOT/MANIFEST).read_text()))
    if errors: raise SystemExit("\n".join(errors))
    verify_capture(REPORT)
    print("VISUAL RESOURCES: stable IDs, geometry, alpha, variants, imports and provenance valid")


def verify_capture(folder: Path) -> None:
    """Проверяет сохранённое нативное доказательство, не замораживая графику будущих партий."""
    proof=parse((folder/'native-comparison.json').read_text())
    if set(proof.get('frames',{}))!={'room','gallery'} or not proof.get('matching_configuration'):
        raise ValueError('incomplete native evidence')
    rows=[]
    for phase in ['before','after']:
        row=parse((folder/f'native/{phase}/capture.json').read_text())
        if row['errors'] or row['performance_eligible'] or row['framebuffer']!=[1152,648]:
            raise ValueError('invalid native capture conditions: '+phase)
        rows.append({key:value for key,value in row.items() if key!='profile'})
    if rows[0]!=rows[1] or proof['performance_eligible']: raise ValueError('native camera/configuration mismatch')
    for name,frame in proof['frames'].items():
        if not frame.get('decoded_pixel_equal'): raise ValueError('invalid native comparison claim')
        images=[]
        for phase in ['before','after']:
            file=folder/f'native/{phase}/{name}.png'
            if hashlib.sha256(file.read_bytes()).hexdigest()!=frame['sha256'][phase]: raise ValueError('native hash mismatch')
            with Image.open(file) as image: images.append(image.convert('RGBA'))
        if any(image.size!=(1152,648) for image in images) or any(channel.getbbox() for channel in ImageChops.difference(*images).split()):
            raise ValueError('native frame pixels changed: '+name)
    preview=folder/'native/after/gallery-strip.png'
    if hashlib.sha256(preview.read_bytes()).hexdigest()!=proof['preview']['sha256']: raise ValueError('compact native hash mismatch')
    with Image.open(preview) as image: strip=image.convert('RGBA')
    with Image.open(folder/'native/after/gallery.png') as image: expected=image.convert('RGBA').crop((0,260,1152,480))
    if strip.size!=(1152,220) or any(channel.getbbox() for channel in ImageChops.difference(expected,strip).split()):
        raise ValueError('compact native viewport does not match full-frame region')


if __name__=="__main__": main()
