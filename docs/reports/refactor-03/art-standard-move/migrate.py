"""Переносит art-standard по принятой ведомости; исторические декларации не переписывает."""
import ast
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment
REPORT = Path(__file__).resolve().parent
BASE = '47d0edc5e9a24dc028b6c91638e8dc54b87aaf9f'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=git_environment())


def main():
    assert git('rev-parse', 'HEAD').decode().strip() == BASE
    assert not git('diff', 'HEAD', '--name-only').strip()
    inventory = json.loads((REPORT / 'baseline/inventory.json').read_text())
    assert not (ROOT / 'tools/qa/art').exists()
    rows = inventory['moves']
    for row in rows:
        raw = (ROOT / row['old_path']).read_bytes()
        assert raw == gzip.decompress((REPORT / 'inputs' / (Path(row['old_path']).name + '.gz')).read_bytes())
        assert hashlib.sha256(raw).hexdigest() == row['sha256']
    ignore = ROOT / '.gitignore'
    (REPORT / 'inputs/gitignore.gz').write_bytes(gzip.compress(ignore.read_bytes(), mtime=0))
    ignore.write_text(ignore.read_text() + '\n# REFACTOR-03: art QA sources; caches and other UID remain ignored.\n!tools/qa/\ntools/qa/*\n!tools/qa/__init__.py\n!tools/qa/art/\ntools/qa/art/*\n!tools/qa/art/*.py\n!tools/qa/art/*.gd\n' +
                      ''.join('!' + r['target'] + '\n' for r in rows if r['old_path'].endswith('.uid')))
    (ROOT / 'tools/qa/art').mkdir(parents=True)
    (ROOT / 'tools/qa/__init__.py').write_text('"""Профильные проверки проекта по подсистемам."""\n')
    (ROOT / 'tools/qa/art/__init__.py').write_text('"""Художественные стандарты и их сохранённые доказательства."""\n')
    stems = {Path(r['old_path']).stem for r in rows if r['old_path'].endswith('.py')}
    for row in rows:
        git('mv', '--', row['old_path'], row['target'])
        path = ROOT / row['target']
        text = path.read_text()
        if path.suffix == '.py':
            text = text.replace('from common.', 'from tools.common.')
            for stem in stems:
                text = re.sub(r'(?m)^from ' + re.escape(stem) + r' import ', 'from tools.qa.art.' + stem + ' import ', text)
                text = re.sub(r'(?m)^import ' + re.escape(stem) + r' as ', 'from tools.qa.art import ' + stem + ' as ', text)
            if path.name == 'visual_scale.py':
                text = text.replace('from tools.common.paths import project_root', 'from tools.common.paths import project_root\nfrom tools.qa.art.current_paths import captured_paths, recorded_paths, source_path')
                text = text.replace("'sources':{p:digest(ROOT/p) for p in SOURCES},'artifacts':{}", "'sources':{p:digest(source_path(ROOT,p)) for p in SOURCES},'source_paths':captured_paths(SOURCES),'artifacts':{}")
                text = text.replace('digest(ROOT/path)!=sha', 'digest(source_path(ROOT,path))!=sha')
                needle = "    if source.get('runtime_patch')!=''"
                position = text.index(needle)
                text = text[:position] + "    try: recorded_paths(SOURCES,source.get('source_paths',{}))\n    except ValueError: errors.append('source path mapping')\n" + text[position:]
                text = text.replace("'res://tools/visual_scale_capture.gd'", "'res://tools/qa/art/visual_scale_capture.gd'")
            compile(text, row['target'], 'exec')
        elif path.suffix == '.gd':
            for peer in rows:
                text = text.replace('res://' + peer['old_path'], 'res://' + peer['target'])
        path.write_text(text)
        assert path.stat().st_mode & 0o777 == row['mode']
        row['after_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    ignored = []
    for row in rows:
        if not row['old_path'].endswith('.gd'):
            continue
        old_uid = ROOT / (row['old_path'] + '.uid')
        if old_uid.exists():
            target = ROOT / (row['target'] + '.uid')
            raw = old_uid.read_bytes()
            old_uid.rename(target)
            assert target.read_bytes() == raw and git('check-ignore', '--', str(target.relative_to(ROOT))).strip()
            ignored.append({'old_path': str(old_uid.relative_to(ROOT)), 'target': str(target.relative_to(ROOT)), 'sha256': hashlib.sha256(raw).hexdigest()})
    quality = ROOT / 'tools/quality/check_architecture.sh'
    text = quality.read_text()
    for row in rows:
        if row['old_path'].endswith('.py'):
            text = text.replace('python3 ' + row['old_path'], 'python3 tools/run.py qa.art.' + Path(row['old_path']).stem)
    text = text.replace('python3 tools/run.py common.test_history\n', 'python3 tools/run.py common.test_history\npython3 tools/run.py qa.art.test_current_paths\n')
    quality.write_text(text)
    (REPORT / 'migration.json').write_text(json.dumps({'base': BASE, 'moves': rows, 'ignored_UID_moves': ignored,
                                                     'root_before': 504, 'root_after': 481, 'source_moves': 23,
                                                     'tracked_UID_moves': 3, 'full_task03_accepted': False}, indent=2) + '\n')
    print(json.dumps({'sources': 23, 'tracked_UID': 3, 'ignored_UID': len(ignored), 'root_after': 481}))


if __name__ == '__main__':
    main()
