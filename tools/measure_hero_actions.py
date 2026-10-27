"""Read-only pixel measurements; source images are never modified here."""
import json
from pathlib import Path
from PIL import Image

from tools.common.paths import project_root

ROOT = project_root(__file__)
SOURCE = ROOT / "docs/concepts/hero-actions-2026-10-12/v2/sources"
KINDS = ("pickaxe", "axe", "watering", "fishing", "hammer", "staff")


def components(points):
    result = []
    while points:
        start = points.pop()
        stack, found = [start], [start]
        while stack:
            x, y = stack.pop()
            for p in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if p in points:
                    points.remove(p)
                    stack.append(p)
                    found.append(p)
        result.append(found)
    return result


def measure(image, cell, selected=None):
    pixels = image.load()
    opaque = selected if selected is not None else [(x,y) for y in range(cell[1],cell[3]) for x in range(cell[0],cell[2]) if pixels[x,y][3] >= 24]
    assert opaque, cell
    x0,y0 = min(p[0] for p in opaque),min(p[1] for p in opaque)
    x1,y1 = max(p[0] for p in opaque)+1,max(p[1] for p in opaque)+1
    feet = set()
    for x,y in opaque:
        r,g,b,a = pixels[x,y]
        if y >= y0+(y1-y0)*0.66 and a >= 64 and 22 < r < 175 and 8 < g < 110 and r > g*1.34 and b < g*0.92:
            feet.add((x,y))
    blobs = sorted(components(feet),key=len,reverse=True)
    boots = [b for b in blobs if len(b) > 40 and max(p[1] for p in b)-min(p[1] for p in b) > 8][:2]
    assert len(boots)==2,(cell,[len(b) for b in blobs[:5]])
    boot_boxes = [[min(p[0] for p in b),min(p[1] for p in b),max(p[0] for p in b)+1,max(p[1] for p in b)+1] for b in boots]
    pivot = [sum((b[0]+b[2])/2 for b in boot_boxes)/2,max(b[3] for b in boot_boxes)]
    box=[x0,y0,x1,y1]
    return {"box":box,"pivot":pivot,"boots":boot_boxes,"visible":[x0,y0,x1,y1]}


def main():
    result={}
    for kind in KINDS:
        image=Image.open(SOURCE / (kind+".png")).convert("RGBA")
        rows=[0,2,1,3] if kind=="hammer" else [0,1,2,3]
        pixels=image.load()
        points={(x,y) for y in range(image.height) for x in range(image.width) if pixels[x,y][3]>=24}
        figures=sorted(components(points),key=len,reverse=True)[:16]
        figures.sort(key=lambda c:(min(p[1] for p in c)+max(p[1] for p in c))/2)
        ordered=[]
        for row in range(4):
            ordered.extend(sorted(figures[row*4:row*4+4],key=lambda c:(min(p[0] for p in c)+max(p[0] for p in c))/2))
        frames=[]
        for row in rows:
            for col in range(4):
                cell=[round(col*image.width/4),round(row*image.height/4),round((col+1)*image.width/4),round((row+1)*image.height/4)]
                value=measure(image,cell,ordered[row*4+col])
                if kind=="fishing" and col==3:
                    points=ordered[row*4+col]
                    edge=min(x for x,y in points) if row==1 else max(x for x,y in points)
                    ys=sorted(y for x,y in points if abs(x-edge)<=2)
                    value["tip"]=[edge,ys[len(ys)//2]]
                value["source"]=kind+".png"
                frames.append(value)
        if kind=="staff" and (SOURCE/"staff-charge.png").exists():
            charge=Image.open(SOURCE/"staff-charge.png").convert("RGBA")
            frames[1]=measure(charge,[0,0,charge.width,charge.height])
            frames[1]["source"]="staff-charge.png"
        # Body scale follows ready-pose head to boots, not the raised tool or FX.
        height=frames[0]["pivot"][1]-frames[0]["visible"][1]
        for i,frame in enumerate(frames):
            frame["scale"]=84/height if not(kind=="staff" and i==1) else 84/(frame["pivot"][1]-449)
        result[kind]={"frames":frames,"directions":["down","left","right","up"]}
        print(kind, image.size, "feet", [v["pivot"] for v in frames])
    (SOURCE.parent/"regions.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")


if __name__=="__main__":
    main()
