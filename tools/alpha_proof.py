#!/usr/bin/env python3
"""Повторно проверяет числовые контроли и неизменность белых деталей в нативных кадрах."""
import json
from pathlib import Path
from PIL import Image,ImageChops
from alpha_metrics import analyse
from alpha_audit import ROOT,REPORT,BASELINE,read,sha
from tools.assets.contracts.source_paths import current_source
from tools.common.history import pinned_sha

LEGACY_CAPTURE = ('tools/alpha_capture.gd', 'd609ab4fa6d82d6d013265183f018b8836abf7cc',
                  '0a5dce5a6f558f21cb03bcdf47a0189d2639d3ebf7ed5ee0a7c6e8aba57fc81a')


def capture_sha(root: Path) -> str:
    """Сверяет текущую копию source отдельно от точного Git collector исторического proof."""
    name, commit, expected = LEGACY_CAPTURE
    if current_source(root, name).read_bytes() != current_source(ROOT, name).read_bytes():
        raise ValueError('native alpha capture implementation differs')
    return pinned_sha(ROOT, name, commit, expected)

BACKGROUNDS={'light':(241,234,216),'dark':(25,35,43),'green':(97,118,75),'purple':(116,85,118)}
CASES=['clean-white-details','white-soft-matte','white-opaque-rim','magenta-soft-matte','magenta-opaque-rim','white-material','magenta-material','invisible-rgb']


def measurements(folder: Path) -> dict:
    """Измеряет непрозрачные детали и видимую разницу испорченного края на каждом контрольном фоне."""
    result={}
    for background in BACKGROUNDS:
        with Image.open(folder/('controls-'+background+'.png')) as image:
            clean=image.crop((67,100,259,292));damaged=[image.crop(box) for box in [(347,100,539,292),(907,100,1099,292),(907,360,1099,552)]]
            result[background]={'background':list(image.getpixel((0,0))),
                'white_detail':list(image.getpixel((163,184))),
                'white_material':list(image.getpixel((443,444))),
                'magenta_material':list(image.getpixel((723,444))),
                'changed_pixels':{name:sum(v!=(0,0,0,0) for v in ImageChops.difference(clean,other).getdata()) for name,other in zip(['white_soft','magenta_soft','invisible_rgb'],damaged)}}
    return result


def validate(root: Path) -> list[str]:
    """Сверяет всю матрицу, контролируемые ошибки, сохранённые RGB и происхождение неизменённых runtime-файлов."""
    report=root/REPORT;errors=[]
    try:
        proof=read(report/'proof.json');data=read(report/'native/capture.json')
        required={'legacy-baseline.json','fixtures/fixtures.json','native/capture.json','native.log','scan.log'}
        required.update('fixtures/'+case+'.png' for case in CASES)
        required.update('native/'+page+'-'+background+'.png' for page in ['controls','sources'] for background in BACKGROUNDS)
        if set(proof['files'])!=required:errors.append('incomplete alpha proof file inventory')
        if proof.get('schema_version')!=1 or proof.get('performance_eligible') is not False:errors.append('invalid alpha proof contract')
        if data['source_sha256']!=capture_sha(root):errors.append('native alpha capture implementation differs')
        if data['method']!='gl_compatibility' or data['driver']!='opengl3' or not data['engine'].startswith('4.7.1-') or not data['profile'].startswith('Codex-VPIPELINE-007-'):errors.append('native alpha configuration differs')
        for name,expected in proof['files'].items():
            if sha((report/name).read_bytes())!=expected:errors.append('alpha proof file changed: '+name)
        baseline=read(root/BASELINE)
        if proof['baseline_commit']!=baseline['baseline_commit']:errors.append('alpha proof baseline commit differs')
        if baseline['summary']['files']!=len(baseline['entries']) or baseline['summary']['files_with_candidates']!=sum(bool(e['metrics']['findings']) for e in baseline['entries'].values()):errors.append('legacy alpha summary differs')
        aggregate=sha(json.dumps({p:e['sha256'] for p,e in baseline['entries'].items()},sort_keys=True).encode())
        if proof['runtime_before_sha256']!=aggregate or proof['runtime_after_sha256']!=aggregate:errors.append('runtime source preservation proof differs')
        fixtures=read(report/'fixtures/fixtures.json')
        if [e['id'] for e in fixtures]!=CASES:errors.append('incomplete alpha control set')
        for entry in fixtures:
            with Image.open(report/'fixtures'/entry['file']) as image:
                expected=json.loads(json.dumps(analyse(image)))
            if expected!=entry['metrics']:errors.append('control metrics differ: '+entry['id'])
            findings=expected['findings']
            if entry['id'] in ['white-soft-matte','white-opaque-rim','magenta-soft-matte','magenta-opaque-rim']:
                colour=entry['id'].split('-')[0]
                if not findings or any(f['colour']!=colour for f in findings) or sum(f['candidate_pixels'] for f in findings)<50:errors.append('negative matte control not detected: '+entry['id'])
            elif findings:errors.append('legitimate/transparent control incorrectly classified: '+entry['id'])
        expected_frames={page+'-'+background for page in ['controls','sources'] for background in BACKGROUNDS}
        if set(data['frames'])!=expected_frames or data['framebuffer']!=[1152,648] or data['performance_eligible'] is not False:errors.append('incomplete native alpha matrix')
        for name,expected in data['frames'].items():
            path=report/'native'/(name+'.png')
            if sha(path.read_bytes())!=expected:errors.append('native alpha image hash differs: '+name)
            with Image.open(path) as image:
                if image.mode!='RGBA' or image.size!=(1152,648):errors.append('invalid alpha framebuffer: '+name)
        if [s['id'] for s in data['sources']]!=['milk-preview','clean-well','clean-cart','legacy-props']:errors.append('incomplete native source matrix')
        for source in data['sources']:
            path=source['path'][6:];x,y,w,h=source['source_rect'];width,height=source['pixels']
            if min(x,y)<0 or min(w,h)<=0 or x+w>width or y+h>height:errors.append('invalid native source rect: '+source['id'])
            if baseline['entries'][path]['sha256']!=source['sha256']:errors.append('native source provenance differs: '+source['id'])
        values=measurements(report/'native')
        if values!=proof['measurements']:errors.append('native alpha measurements differ')
        for background,row in values.items():
            if row['background']!=list(BACKGROUNDS[background])+[255]:errors.append('control background differs: '+background)
            for field,expected in [('white_detail',[250,245,230,255]),('white_material',[244,240,231,255]),('magenta_material',[220,35,200,255])]:
                if row[field]!=expected:errors.append('legitimate colour was removed or modified: '+field)
            if any(value<100 for value in row['changed_pixels'].values()):errors.append('negative control is not visually different: '+background)
        if 'ERROR:' in (report/'native.log').read_text():errors.append('native alpha engine errors')
    except (OSError,ValueError,KeyError,TypeError,IndexError) as exc:errors.append('invalid alpha proof: '+str(exc))
    return errors
