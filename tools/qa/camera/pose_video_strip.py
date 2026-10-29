#!/usr/bin/env python3
"""Builds a scientific contact sheet from decoded native video pixels, without scaling."""
import argparse
import json
from pathlib import Path
from tools.assets.contracts.source_paths import current_source
from PIL import Image, ImageDraw, ImageFont
from tools.qa.camera.presentation_pose import ROOT, REPORT, read, sha, require


def build(folder, output):
    """Keeps the selected pixels at 1:1 and records frame times and media provenance."""
    require(not output.exists(),'fresh review folder required'); output.mkdir(parents=True)
    rows=read(folder/'frames.json'); require(len(rows)==16,'sixteen decoded frames required')
    crop=(530,220,660,365); tile=(130,145)
    sheet=Image.new('RGB',(120+8*138,32+2*180),'#f7f0db'); draw=ImageDraw.Draw(sheet)
    try: font=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',12)
    except OSError: font=ImageFont.load_default()
    draw.text((10,8),'VCAMERA-003 | MP4 frames 90-97 | native pixels 1:1 | A physical / B shared',font=font,fill='#332e26')
    for index,row in enumerate(rows):
        mode='physical' if index<8 else 'shared'; frame=90+index%8
        require(row['mode']==mode and row['frame']==frame and abs(row['seconds']-frame/60)<1e-5,'decoded frame order/time')
        image=Image.open(folder/row['file']).convert('RGB'); require(image.size==(1152,648),'native base video size')
        x=120+(index%8)*138; y=32+(index//8)*180
        if index%8==0: draw.text((8,y+70),'A physical' if index<8 else 'B shared',font=font,fill='#332e26')
        draw.text((x,y),'f%d'%frame,font=font,fill='#332e26')
        sheet.paste(image.crop(crop),(x,y+22)); draw.rectangle((x,y+22,x+tile[0],y+22+tile[1]),outline='#8d876e')
    sheet.save(output/'frames-90-97.png')
    proof={'task':'VCAMERA-003','kind':'decoded-video-contact-sheet','native_crop':list(crop),'rescaled':False,
        'frames':rows,'mp4_sha256':{mode:sha(REPORT/'native'/('base-'+mode)/'walk.mp4') for mode in ['physical','shared']},
        'sheet_sha256':sha(output/'frames-90-97.png'),
        'decoder_sha256':sha(current_source(ROOT, 'tools/pose_video_frames.swift')),'plot_sha256':sha(Path(__file__))}
    (output/'source.json').write_text(json.dumps(proof,indent=2)+'\n')
    print('VIDEO REVIEW: 16 exact decoded frames, crop without rescaling')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('frames',type=Path); parser.add_argument('output',type=Path)
    args=parser.parse_args(); build(args.frames.resolve(),args.output.resolve())
