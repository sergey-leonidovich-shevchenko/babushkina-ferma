#!/usr/bin/env python3
"""Проверяет паспорт света и настоящий нативный вывод, не оценивает красоту."""
import hashlib
import json
from pathlib import Path
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'docs/reports/visual-overhaul/vart-007'


def sha(path):
    """Связывает доказательство с байтами исходника."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contract_errors(data, capture):
    """Отклоняет другую камеру, противоречивую тень и неполный readback."""
    errors = []
    for key, value in {'task':'VART-007', 'status':'approved', 'selection':'a',
                       'runtime_integration':False, 'target':[1152,648],
                       'field':[960,540], 'zoom':1.2}.items():
        if data.get(key) != value: errors.append('profile: ' + key)
    if not data.get('decision_quote') or data.get('decision_source') != 'direct user reply in chat':
        errors.append('choice evidence')
    if data['variants']['a']['cast'] != [.55,.25] or data['variants']['b']['cast'] != [-.55,.25]:
        errors.append('shadow direction')
    if {p['id'] for p in data['parts']} != {'hero','tree','table'}: errors.append('subjects')
    table = next(p for p in data['parts'] if p['id']=='table')
    if len(table['contact']) != 2 or table['contact'][0][0] >= 0 or table['contact'][1][0] <= 0:
        errors.append('table foot contacts')
    for key, value in {'kind':'native-light-study', 'native_gameplay':False,
                       'performance_eligible':False, 'target':[1152,648], 'field':[960,540],
                       'texture_filter':'linear_with_mipmaps'}.items():
        if capture.get(key) != value: errors.append('capture: ' + key)
    if capture.get('display_server') in [None,'headless'] or not capture.get('profile','').startswith('Codex-VART-007-'):
        errors.append('native profile')
    if capture.get('projection') != [[1.20000004768372,0.0],[0.0,1.20000004768372],[0.0,0.0]]:
        matrix = capture.get('projection',[])
        if len(matrix)!=3 or any(abs(a-b)>1e-6 for row,expected in zip(matrix,[[1.2,0],[0,1.2],[0,0]]) for a,b in zip(row,expected)):
            errors.append('projection')
    expected = {(v,b,l) for v in ['a','b'] for b in data['backgrounds'] for l in ['combined','form','contact','cast']}
    frames = capture.get('frames',[])
    if len(frames)!=24 or {(f['variant'],f['background'],f['layer']) for f in frames} != expected:
        errors.append('coverage')
    for f in frames:
        if f.get('size') != [1152,648] or f.get('repeat_equal') is not True: errors.append('readback')
    return sorted(set(errors))


def verify():
    """Сверяет файлы, слои, источники и синхронность автономной страницы."""
    data = json.loads((REPORT/'light-profile.json').read_text())
    capture = json.loads((REPORT/'native/capture.json').read_text())
    source = json.loads((REPORT/'source.json').read_text())
    errors = contract_errors(data,capture)
    if capture['profile_sha256'] != sha(REPORT/'light-profile.json'): errors.append('profile hash')
    if capture['script_sha256'] != sha(ROOT/'tools/visual_light_capture.gd'): errors.append('script hash')
    for path, digest in {**source['references'],**capture['sources'],source['master']['path']:source['master']['sha256']}.items():
        if sha(REPORT/path) != digest: errors.append('source hash: '+path)
    if sha(REPORT/'prompt-ne.txt') != source['prompt_sha256']: errors.append('prompt hash')
    for f in capture['frames']:
        path = REPORT/'native'/f['file']
        with Image.open(path) as image:
            if sha(path)!=f['sha256'] or image.size!=(1152,648): errors.append('PNG: '+f['file'])
    for b in data['backgrounds']:
        a=REPORT/'native'/('a-'+b+'-contact.png'); other=REPORT/'native'/('b-'+b+'-contact.png')
        if a.read_bytes()!=other.read_bytes(): errors.append('contact drift')
        if len({sha(REPORT/'native'/('a-'+b+'-'+l+'.png')) for l in data['layers']})!=4: errors.append('collapsed layers')
    match=re.search(r'<script type="application/json" id="light-data">(.*?)</script>',(REPORT/'index.html').read_text(),re.S)
    if not match or json.loads(match[1])!=data: errors.append('HTML data')
    return errors


if __name__=='__main__':
    problems=verify()
    if problems: raise SystemExit('\n'.join(problems))
    print('VART-007: approved A, 24 native frames, independent form/contact/cast, hashes valid')
