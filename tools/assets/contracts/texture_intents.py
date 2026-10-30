#!/usr/bin/env python3
"""Проверяет назначения, точные данные импорта и сохранённую GPU-матрицу VPIPELINE-005."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
import subprocess
from pathlib import Path
from tools.common.paths import project_root
from tools.common.git import git_environment
from PIL import Image, ImageChops
from tools.assets.contracts.source_paths import current_source

ROOT = project_root(__file__)
POLICY = "assets/game/visual_texture_intents.json"
HELPER = "scripts/presentation/texture_intent_system.gd"
REPORT = "docs/reports/visual-overhaul/vpipeline-005"
MODES = {"compatibility":("gl_compatibility",False), "mobile-ldr":("mobile",False), "mobile-hdr":("mobile",True)}
DATA_IMPORT = {"compress/mode":0,"compress/normal_map":2,"compress/channel_pack":0,"mipmaps/generate":False,
    "process/channel_remap/red":0,"process/channel_remap/green":1,"process/channel_remap/blue":2,"process/channel_remap/alpha":3,
    "process/fix_alpha_border":False,"process/premult_alpha":False,"process/normal_map_invert_y":False,
    "process/hdr_as_srgb":False,"process/size_limit":0,"detect_3d/compress_to":0}
COLOR_IMPORT = {"compress/mode":0,"mipmaps/generate":False,"process/fix_alpha_border":True,"process/premult_alpha":False}


def digest(path: Path) -> str:
    """Фиксирует конкретный файл реализации или доказательства без времени изменения."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> dict:
    """Читает собственные структурированные настройки и доказательства."""
    return json.loads(path.read_text())


def write(path: Path, data: dict) -> None:
    """Сохраняет читаемые числовые результаты с настоящими переводами строк."""
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")


def validate(root: Path) -> list[str]:
    """Не допускает изменённую числовую политику и пропущенную роль в игровом паспорте."""
    errors=[]
    try:
        policy=read(root/POLICY)
        expected={"schema_version":1,"profiles":{
            "color_srgb":{"role":"color","transfer":"srgb","source_color":True,"import":COLOR_IMPORT},
            "data_rgba8":{"role":"data","transfer":"linear","source_color":False,"import":DATA_IMPORT}}}
        if json.dumps(policy,sort_keys=True)!=json.dumps(expected,sort_keys=True): errors.append("texture intent policy differs from explicit color/data contract")
        for key, entry in read(root/"assets/game/visual_resources.json")["textures"].items():
            if entry.get("intent")!="color_srgb": errors.append(key+": visual drawing must declare color_srgb")
            for option,value in COLOR_IMPORT.items():
                if entry.get("import",{}).get(option)!=value: errors.append(key+": color import contract mismatch: "+option)
            errors+=import_errors(root/entry["file"][6:],COLOR_IMPORT)
    except (OSError,ValueError,KeyError,TypeError) as exc: errors.append("invalid texture intent inputs: "+str(exc))
    return errors


def import_errors(path: Path, expected: dict) -> list[str]:
    """Сверяет настоящие параметры импорта, включая запрет скрытого изменения RGBA."""
    source=Path(str(path)+".import").read_text(); errors=[]
    for option,value in expected.items():
        matches=re.findall(r"^"+re.escape(option)+r"=(.+)$",source,re.M)
        if matches!=[json.dumps(value,separators=(",",":"))]: errors.append(path.name+": import mismatch: "+option)
    return errors


def pixels(name: str) -> list[list[int]]:
    """Задаёт независимые RGBA, включая разную альфу и скрытый цвет нулевой альфы."""
    result=[]
    for y in range(8):
        for x in range(16):
            n=y*16+x
            if name=="depth" or name=="negative-alpha": rgba=[n*2,(n*37)%256,255-n*2,(n*17)%256]
            elif name=="flex": rgba=[(n*53)%256,(x*17),(y*36)%256,(n*31+128)%256]
            else: rgba=[(n*17)%256,(n*37+64)%256,(n*71+128)%256,255]
            result.append(rgba)
    return result


def fixtures(destination: Path, root: Path=ROOT) -> None:
    """Создаёт свежий отдельный проект с точными масками и копией действующей фабрики."""
    if destination.exists(): raise ValueError("fixture destination must be new")
    destination.mkdir(parents=True)
    for relative in [POLICY,HELPER]:
        target=destination/relative; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(root/relative,target)
    shutil.copyfile(current_source(root, 'tools/texture_data_probe.gd'),destination/"probe.gd")
    (destination/"project.godot").write_text('config_version=5\n[application]\nconfig/name="Codex VPIPELINE005 numeric fixture"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Codex-VPIPELINE005-numeric"\n[display]\nwindow/size/viewport_width=640\nwindow/size/viewport_height=360\n[rendering]\nrenderer/rendering_method="mobile"\n')
    entries=[]
    for name,intent in [("depth","data_rgba8"),("flex","data_rgba8"),("color","color_srgb"),("negative-alpha","negative_alpha")]:
        path=destination/(name+".png"); image=Image.new("RGBA",(16,8)); image.putdata([tuple(p) for p in pixels(name)]); image.save(path)
        params=dict(COLOR_IMPORT if intent=="color_srgb" else DATA_IMPORT)
        if intent=="negative_alpha": params["process/fix_alpha_border"]=True
        Path(str(path)+".import").write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://'+path.name+'"\n[params]\n'+"\n".join(k+"="+json.dumps(v) for k,v in params.items())+"\n")
        entries.append({"name":name,"intent":intent,"file":path.name,"sha256":digest(path),"pixels":[16,8]})
    write(destination/"fixtures.json",{"schema_version":1,"textures":entries,"production":{p:digest(current_source(root,p)) for p in [POLICY,HELPER,"tools/texture_data_probe.gd"]}})


def linear(value: float) -> float:
    """Вычисляет ожидаемое преобразование sRGB только для RGB цветового sampler."""
    return value/12.92 if value<=0.04045 else ((value+0.055)/1.055)**2.4


def numeric_errors(data: dict, mode: str) -> tuple[list[str],dict]:
    """Проверяет все импортированные каналы и GPU-texel, отдельно измеряя негативные контроли."""
    errors=[]; measurements={}; method,hdr=MODES[mode]
    if data.get("method")!=method or data.get("requested_hdr")!=hdr: errors.append(mode+": wrong rendering configuration")
    if not data.get("guard_refused_wrong"): errors.append(mode+": factory allowed wrong source_color")
    if data.get("performance_eligible") is not False: errors.append(mode+": capture is not a performance measurement")
    cpu=data.get("cpu",[])
    if [e.get("name") for e in cpu]!=["depth","flex","color","negative-alpha"]: errors.append(mode+": incomplete CPU matrix")
    for entry in cpu:
        expected=[v for row in pixels(entry["name"]) for v in row]
        actual=entry.get("rgba",[])
        if entry.get("format")!=5 or entry.get("mipmaps"): errors.append(mode+": import must be RGBA8 without mipmaps")
        if entry["name"]=="negative-alpha":
            if len(actual)!=len(expected) or actual==expected: errors.append(mode+": alpha-border negative control failed to alter hidden RGB")
            measurements["alpha_border_changed_bytes"]=sum(a!=b for a,b in zip(actual,expected))
        elif actual!=expected: errors.append(mode+": imported RGBA changed: "+entry["name"])
    gpu=data.get("gpu",[])
    if [(e.get("name"),e.get("wrong")) for e in gpu]!=[(n,w) for n in ["depth","flex","color"] for w in [False,True]]: errors.append(mode+": incomplete GPU matrix")
    for entry in gpu:
        key=entry["name"]+("-wrong" if entry["wrong"] else "-correct")
        expected=[[v/255 for v in row] for row in pixels(entry["name"])]
        # LDR canvas keeps values in sRGB space; HDR canvas stores linear float RGBA.
        apply_transfer=hdr and ((entry["name"]=="color")!=entry["wrong"])
        if apply_transfer: expected=[[linear(v) if c<3 else v for c,v in enumerate(row)] for row in expected]
        actual=entry.get("pixels",[])
        if len(actual)!=128 or any(len(row)!=4 or any(type(v) not in [int,float] or not math.isfinite(v) for v in row) for row in actual): errors.append(mode+": invalid GPU values: "+key); continue
        delta=max(abs(a-b) for row,exp in zip(actual,expected) for a,b in zip(row,exp))
        alpha_delta=max(abs(row[3]-exp[3]) for row,exp in zip(actual,expected))
        if entry.get("hdr")!=hdr or entry.get("format")!=(15 if hdr else 5): errors.append(mode+": wrong framebuffer format: "+key)
        # Data проверяется строже отдельного приближённого sRGB-декодера GPU.
        tolerance=(0.0025 if apply_transfer else 0.0005) if hdr else 0.0000002
        if delta>tolerance: errors.append(mode+": numeric GPU mismatch: "+key+" "+str(delta))
        if alpha_delta>(0.0005 if hdr else 0.0000002): errors.append(mode+": alpha changed: "+key)
        measurements[key]={"max_error":delta,"alpha_error":alpha_delta}
    if hdr and len(gpu)==6:
        correct=gpu[0]["pixels"]; wrong=gpu[1]["pixels"]
        transfer_delta=max(abs(a-b) for row,exp in zip(correct,wrong) for a,b in zip(row[:3],exp[:3]))
        if transfer_delta<0.28: errors.append(mode+": wrong source_color negative control was not visible")
        measurements["wrong_hint_max_change"]=transfer_delta
    return errors,measurements


def record(fixture: Path, root: Path=ROOT) -> None:
    """Архивирует только успешную свежую матрицу, настоящие readback и параметры импорта."""
    report=root/REPORT; target=report/"numeric"
    if target.exists(): raise ValueError("numeric report must be new")
    source=read(fixture/"fixtures.json"); faults=[]; measurements={}
    for relative,expected in source["production"].items():
        if digest(current_source(root,relative))!=expected or digest(fixture/("probe.gd" if relative=="tools/texture_data_probe.gd" else relative))!=expected: faults.append("stale fixture implementation: "+relative)
    for entry in source["textures"]:
        path=fixture/entry["file"]
        if digest(path)!=entry["sha256"]: faults.append("changed fixture: "+entry["name"])
        if entry["intent"]!="negative_alpha": faults+=import_errors(path,COLOR_IMPORT if entry["intent"]=="color_srgb" else DATA_IMPORT)
    for mode in MODES:
        errors,measure=numeric_errors(read(fixture/mode/"readback.json"),mode); faults+=errors; measurements[mode]=measure
        log=(fixture/(mode+".log")).read_text()
        if "ERROR:" in log or "SCRIPT ERROR:" in log: faults.append(mode+": engine errors in capture log")
    if faults: raise ValueError("\n".join(faults))
    target.mkdir(parents=True)
    for entry in source["textures"]:
        for extension in ["", ".import"]: shutil.copyfile(fixture/(entry["file"]+extension),target/(entry["file"]+extension))
    shutil.copyfile(fixture/"fixtures.json",target/"fixtures.json")
    for mode in MODES:
        shutil.copytree(fixture/mode,target/mode); shutil.copyfile(fixture/(mode+".log"),target/(mode+".log"))
    files={str(p.relative_to(target)):digest(p) for p in sorted(target.rglob("*")) if p.is_file()}
    write(report/"numeric-proof.json",{"schema_version":1,"production":source["production"],"files":files,"measurements":measurements,"baseline":"214a3d3","performance_eligible":False})


def proof_errors(root: Path) -> list[str]:
    """Заново вычисляет числовую приёмку и сравнение комнаты, не доверяя сохранённому зелёному статусу."""
    errors=[]; report=root/REPORT
    try:
        proof=read(report/"numeric-proof.json"); numeric=report/"numeric"
        for relative,expected in proof["production"].items():
            if digest(current_source(root,relative))!=expected: errors.append("production proof is stale: "+relative)
        for relative,expected in proof["files"].items():
            if digest(numeric/relative)!=expected: errors.append("numeric proof file changed: "+relative)
        if read(numeric/"fixtures.json")["production"]!=proof["production"]: errors.append("fixture provenance differs from production proof")
        for mode in MODES:
            faults,measurements=numeric_errors(read(numeric/mode/"readback.json"),mode); errors+=faults
            if measurements!=proof["measurements"][mode]: errors.append("recorded measurements differ: "+mode)
            if "ERROR:" in (numeric/(mode+".log")).read_text(): errors.append(mode+": recorded engine errors")
            for entry in read(numeric/mode/"readback.json")["gpu"]:
                with Image.open(numeric/mode/entry["file"]) as image:
                    if image.size!=(128,64) or image.mode!="RGBA": errors.append("invalid GPU image: "+entry["file"]); continue
                    for y in range(64):
                        for x in range(128):
                            expected=entry["pixels"][(y//8)*16+x//8]
                            if any(abs(v-round(max(0,min(1,e))*255))>1 for v,e in zip(image.getpixel((x,y)),expected)):
                                errors.append("GPU image disagrees with numeric readback: "+entry["file"]); break
                        else: continue
                        break
        for entry in read(numeric/"fixtures.json")["textures"]:
            with Image.open(numeric/entry["file"]) as image:
                if image.mode!="RGBA" or image.size!=(16,8) or list(image.getdata())!=[tuple(p) for p in pixels(entry["name"])]: errors.append("fixture pixels differ: "+entry["name"])
            if entry["intent"]!="negative_alpha": errors+=import_errors(numeric/entry["file"],COLOR_IMPORT if entry["intent"]=="color_srgb" else DATA_IMPORT)
        room=read(report/"room-comparison.json")
        for name in ["before","after"]:
            if digest(report/name/"room.png")!=room[name+"_sha256"]: errors.append("room image changed: "+name)
            captured=read(report/name/"capture.json")
            if captured["errors"] or captured["framebuffer"]!=[1152,648]: errors.append("room capture changed state: "+name)
            if digest(report/name/"capture.json")!=room[name+"_state_sha256"]: errors.append("room state proof changed: "+name)
        before=read(report/"before/capture.json"); after=read(report/"after/capture.json")
        for key in ["state","camera","player","location","minutes","seed","weather","framebuffer","capture_sha256"]:
            if before[key]!=after[key]: errors.append("room configuration/state differs: "+key)
        # Комната — историческая пара: будущая согласованная графика не переписывает её.
        if set(room["production"])!={HELPER,POLICY,"tools/texture_data_room_capture.gd","scripts/systems/visual_resource_catalog.gd","assets/game/visual_resources.json"} or any(not re.fullmatch(r"[a-f0-9]{64}",value) for value in room["production"].values()):
            errors.append("missing room implementation provenance")
        with Image.open(report/"before/room.png") as before, Image.open(report/"after/room.png") as after:
            if before.size!=(1152,648) or before.mode!="RGBA" or ImageChops.difference(before,after).getbbox(alpha_only=False): errors.append("native room must match every RGBA pixel")
    except (OSError,ValueError,KeyError,TypeError) as exc: errors.append("invalid numeric proof: "+str(exc))
    return errors


def bundle_errors(root: Path, tracked: set[str]) -> list[str]:
    """Не позволяет принять локальное доказательство, чьи обязательные файлы исчезнут после клонирования."""
    required={REPORT+"/numeric/"+name for name in read(root/REPORT/"numeric-proof.json")["files"]}
    required.update(REPORT+"/"+name for name in ["README.md","numeric-proof.json","room-comparison.json","verification.json","browser.json","wiki.png","before.log","after.log","contract.log","before/room.png","before/capture.json","after/room.png","after/capture.json"])
    return ["proof input is not in Git index: "+name for name in sorted(required-tracked)]


def main() -> None:
    """Выбирает создание изолированного стенда, архивацию либо обязательную проверку проекта."""
    parser=argparse.ArgumentParser(); parser.add_argument("--fixtures",type=Path); parser.add_argument("--record",type=Path); args=parser.parse_args()
    if args.fixtures: fixtures(args.fixtures); print("TEXTURE FIXTURES: "+str(args.fixtures)); return
    if args.record: record(args.record); print("TEXTURE NUMERIC PROOF: recorded"); return
    tracked=set(subprocess.check_output(["git","-C",str(ROOT),"ls-files","-z"],env=git_environment()).decode().split("\0"))
    errors=validate(ROOT)+proof_errors(ROOT)+bundle_errors(ROOT,tracked)
    if errors: raise SystemExit("\n".join(errors))
    print("TEXTURE INTENTS: color/data imports, full RGBA and native GPU matrix are valid")


if __name__=="__main__": main()
