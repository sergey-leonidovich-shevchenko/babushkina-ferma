#!/usr/bin/env python3
"""Проверяет возможные белые/пурпурные края; не содержит исправления игровых пикселей."""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path
from PIL import Image
from alpha_metrics import analyse,VERSION
from common.launch import prepare_imports
from common.paths import project_root

prepare_imports(project_root(__file__))
from tools.assets.contracts.visual_pipeline import ignored
from tools.assets.contracts.visual_resources import parse
from tools.assets.contracts.texture_intents import DATA_IMPORT, import_errors
from tools.assets.contracts.source_paths import current_source
from tools.common.git import git_environment

ROOT=project_root(__file__)
POLICY='tools/alpha_policy.json'
REPORT='docs/reports/visual-overhaul/vpipeline-007'
BASELINE=REPORT+'/legacy-baseline.json'


def read(path: Path) -> dict:
    """Читает JSON без скрытой перезаписи одинаковых ключей."""
    return parse(path.read_text())


def sha(data: bytes) -> str:
    """Фиксирует неизменность файла независимо от времени изменения."""
    return hashlib.sha256(data).hexdigest()


def paths(root: Path) -> list[str]:
    """Обходит runtime PNG с настоящими барьерами исходников и без предположения об использовании каждого файла."""
    policy=read(current_source(root, 'tools/visual_asset_policy.json'));result=[]
    for file in (root/'assets/game').rglob('*.png'):
        relative=file.relative_to(root).as_posix()
        if ignored(relative,policy) or any((parent/'.gdignore').exists() for parent in file.parents if parent.is_relative_to(root)):continue
        if not file.resolve().is_relative_to(root.resolve()):raise ValueError('runtime source escapes root')
        result.append(relative)
    return sorted(result)


def inspect(path: Path, intent: str='color_srgb') -> dict:
    """Читает один реальный источник и проверяет, что диагностика не поменяла ни одного его байта."""
    before=path.read_bytes()
    with Image.open(path) as image:result=analyse(image,intent)
    if before!=path.read_bytes():raise ValueError('source changed during read-only audit: '+str(path))
    return {'sha256':sha(before),'metrics':result}


def scan(root: Path) -> dict:
    """Записывает все кандидаты, не объявляя их подтверждёнными дефектами и не исправляя изображения."""
    policy=read(current_source(root, POLICY));entries={};start=time.monotonic()
    for path in paths(root):entries[path]=inspect(root/path,policy.get('data_masks',{}).get(path,'color_srgb'))
    return {'schema_version':1,'algorithm':VERSION,'algorithm_sha256':sha(current_source(root, 'tools/alpha_metrics.py').read_bytes()),
            'baseline_commit':policy['baseline_commit'],'entries':entries,
            'summary':{'files':len(entries),'files_with_candidates':sum(bool(v['metrics']['findings']) for v in entries.values()),
                       'candidate_pixels':sum(f['candidate_pixels'] for v in entries.values() for f in v['metrics']['findings'])},
            'scan_seconds':round(time.monotonic()-start,3),'read_only':True}


def write_report(root: Path, destination: Path, data: dict) -> None:
    """Пишет только новый диагностический JSON вне игрового дерева, исключая случайную перезапись PNG."""
    destination=destination.resolve()
    if destination.suffix!='.json' or destination.is_relative_to((root/'assets').resolve()) or destination.exists():raise ValueError('report must be a new JSON outside assets')
    destination.parent.mkdir(parents=True,exist_ok=True);destination.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')


def check(root: Path) -> list[str]:
    """Удерживает известные кандидаты как явный старый долг; новые и изменённые края требуют отдельной оценки."""
    errors=[];policy=read(current_source(root, POLICY));base=read(root/BASELINE)
    if policy.get('schema_version')!=1 or not isinstance(policy.get('reviews'),dict) or not isinstance(policy.get('data_masks'),dict):return ['invalid alpha policy']
    sources=paths(root)
    for path,intent in policy['data_masks'].items():
        if path not in sources or intent!='data_rgba8':errors.append('invalid data-mask declaration: '+path)
        else:errors+=import_errors(root/path,DATA_IMPORT)
    if base.get('read_only') is not True or base.get('algorithm')!=VERSION or base.get('baseline_commit')!=policy['baseline_commit']:return ['invalid legacy alpha baseline']
    if base.get('algorithm_sha256')!=sha(current_source(root, 'tools/alpha_metrics.py').read_bytes()):return ['alpha algorithm changed: revalidate the baseline and controls']
    for path in sources:
        raw=(root/path).read_bytes();old=base['entries'].get(path,{})
        if sha(raw)==old.get('sha256'):continue
        entry=inspect(root/path,policy.get('data_masks',{}).get(path,'color_srgb'))
        if entry['metrics']['findings']:
            review=policy.get('reviews',{}).get(path,{})
            if not isinstance(review,dict) or review.get('sha256')!=entry['sha256'] or not review.get('reason') or not review.get('evidence'):
                errors.append('new alpha candidates require review: '+path)
    for path,review in policy.get('reviews',{}).items():
        if not isinstance(review,dict) or not isinstance(review.get('reason'),str) or not review['reason'].strip() or not isinstance(review.get('evidence'),list) or not review['evidence']:
            errors.append('invalid alpha review: '+path);continue
        file=root/path
        if path not in sources or not file.is_file() or sha(file.read_bytes())!=review.get('sha256'):errors.append('stale alpha review: '+path)
        for evidence in review.get('evidence',[]):
            if not isinstance(evidence,dict) or not isinstance(evidence.get('file'),str):errors.append('invalid alpha review evidence: '+path);continue
            target=(root/evidence.get('file','')).resolve()
            if not target.is_relative_to(root.resolve()) or not target.is_file() or sha(target.read_bytes())!=evidence.get('sha256'):errors.append('missing or changed alpha review evidence: '+path)
    return errors


def main() -> None:
    """Выбирает безопасный отчёт, первое основание либо контроль новых изменений до публикации."""
    parser=argparse.ArgumentParser();parser.add_argument('--scan',type=Path);parser.add_argument('--init-baseline',action='store_true');parser.add_argument('--inspect',type=Path);parser.add_argument('--intent',default='color_srgb');args=parser.parse_args()
    if args.inspect:
        print(json.dumps(inspect(args.inspect,args.intent),ensure_ascii=False,indent=2));return
    if args.scan or args.init_baseline:
        if args.init_baseline:
            expected=read(current_source(ROOT, POLICY))['baseline_commit'];actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,env=git_environment(),text=True).strip()
            if actual!=expected:raise SystemExit('initial baseline requires its exact starting commit')
            # Снимок долга относится только к исходным зафиксированным в этой базе байтам.
            changed=subprocess.check_output(['git','diff','HEAD','--name-only','--','assets/game'],cwd=ROOT,env=git_environment(),text=True)
            if changed:raise SystemExit('runtime changes cannot enter initial legacy baseline')
            tree=subprocess.check_output(['git','ls-tree','-rz',expected,'--','assets/game'],cwd=ROOT,env=git_environment()).split(b'\0');known={}
            for row in tree:
                if row:
                    header,path=row.split(b'\t',1);known[path.decode()]=header.split()[2].decode()
            for path in paths(ROOT):
                raw=(ROOT/path).read_bytes();blob=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
                if known.get(path)!=blob:raise SystemExit('uncommitted PNG cannot enter legacy baseline: '+path)
        data=scan(ROOT);write_report(ROOT,ROOT/BASELINE if args.init_baseline else args.scan,data);print(json.dumps(data['summary']));print('SCAN SECONDS:',data['scan_seconds']);return
    from alpha_proof import validate
    errors=check(ROOT)+validate(ROOT)
    tracked=set(subprocess.check_output(['git','-C',str(ROOT),'ls-files','-z'],cwd=ROOT,env=git_environment()).decode().split('\0'))
    required=set(read(ROOT/REPORT/'proof.json')['files'])|{'proof.json'}
    for name in sorted(required):
        if REPORT+'/'+name not in tracked:errors.append('alpha proof input missing from Git index: '+name)
    if errors:raise SystemExit('\n'.join(errors))
    base=read(ROOT/BASELINE);print('ALPHA AUDIT: read-only; known legacy candidates '+str(base['summary']['files_with_candidates'])+'; new matte candidates require review')


if __name__=='__main__':main()
