"""Measure existing complete figures without changing any source pixel."""
import json
from pathlib import Path
from PIL import Image
from measure_hero_actions import components

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"assets/game/characters/directional"
OUT=ROOT/"docs/concepts/character-polish-2026-10-12"
KINDS=("npc_official","npc_herbalist","companion_mila","companion_borislav","companion_luna")


def main():
    result={}
    for kind in KINDS:
        image=Image.open(SOURCE/(kind+"_walk_8dir.png")).convert("RGBA")
        pixels=image.load()
        figures=sorted(components({(x,y) for y in range(image.height) for x in range(image.width) if pixels[x,y][3]>=24}),key=len,reverse=True)[:32]
        figures.sort(key=lambda c:(min(y for x,y in c)+max(y for x,y in c))/2)
        ordered=[]
        for row in range(8):
            ordered.extend(sorted(figures[row*4:row*4+4],key=lambda c:(min(x for x,y in c)+max(x for x,y in c))/2))
        frames=[]
        for index,points in enumerate(ordered):
            x0,y0=min(x for x,y in points),min(y for x,y in points)
            x1,y1=max(x for x,y in points)+1,max(y for x,y in points)+1
            assert y1-y0>150,(kind,index)
            feet=set()
            for x,y in points:
                r,g,b,a=pixels[x,y]
                if y>=y1-28 and a>=64 and 24<r<190 and 8<g<140 and r>g*1.25 and b<g*0.95:
                    feet.add((x,y))
            blobs=sorted(components(feet),key=len,reverse=True)
            boots=[b for b in blobs if len(b)>15 and max(x for x,y in b)-min(x for x,y in b)>=5][:2]
            assert boots,(kind,index)
            boxes=[[min(x for x,y in b),min(y for x,y in b),max(x for x,y in b)+1,max(y for x,y in b)+1] for b in boots]
            pivot=[sum((b[0]+b[2])/2 for b in boxes)/len(boxes),min(y1,max(b[3] for b in boxes)+2)]
            head_top=min(y for x,y in points if abs(x-pivot[0])<30)
            scale=84/(pivot[1]-head_top)
            frames.append({"box":[x0,y0,x1-x0,y1-y0],"pivot":pivot,"head_top":head_top,"boots":boxes,"scale":scale})
        result[kind]={"source":"directional/"+kind+"_walk_8dir.png","frames":frames}
        print(kind,"head-to-boot",[round(f["pivot"][1]-f["head_top"]) for f in frames])
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/"regions.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")


if __name__=="__main__":
    main()
