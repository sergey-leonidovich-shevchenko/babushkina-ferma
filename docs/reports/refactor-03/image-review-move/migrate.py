"""Переносит PIL-импорт и самостоятельный дизайн-review без изменения рисунков и алгоритмов."""
import ast
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

REPORT = Path(__file__).resolve().parent
BASE = 'd27f688fa3ec2670a757acd14019f8ae35e0f693'
MOVES = {
    'tools/import_pixabay_assets.py': 'tools/assets/authoring/import_pixabay_assets.py',
    'tools/check_art_review.py': 'tools/dev/art_review/check_art_review.py',
    'tools/test_art_review.py': 'tools/dev/art_review/test_art_review.py',
    'tools/art_review_export.gd': 'tools/dev/art_review/art_review_export.gd',
    'tools/art_review_export.gd.uid': 'tools/dev/art_review/art_review_export.gd.uid',
    'tools/art_review_serve.mjs': 'tools/dev/art_review/art_review_serve.mjs',
}


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=git_environment())


def prepared(name, raw):
    """Меняет только источник ROOT, собственный импорт и глубину Node-ссылок на Wiki."""
    text = raw.decode()
    if name.endswith('import_pixabay_assets.py'):
        text = text.replace('from PIL import Image\n', 'from PIL import Image\n\nfrom tools.common.paths import project_root\n')
        text = text.replace('Path(__file__).resolve().parents[1]', 'project_root(__file__)')
    elif name.endswith('check_art_review.py'):
        text = text.replace('from pathlib import Path\n', 'from pathlib import Path\n\nfrom tools.common.paths import project_root\n')
        text = text.replace('Path(__file__).resolve().parents[1]', 'project_root(__file__)')
    elif name.endswith('test_art_review.py'):
        text = text.replace('from check_art_review import ', 'from tools.dev.art_review.check_art_review import ')
    elif name.endswith('.mjs'):
        text = text.replace('"../wiki/scripts/', '"../../../wiki/scripts/')
    return text.encode()


class Addresses(ast.NodeTransformer):
    """Доказывает тождество Python-алгоритмов за исключением адресов."""
    def visit_ImportFrom(self, node):
        if node.module == 'tools.common.paths':
            return None
        if node.module == 'tools.dev.art_review.check_art_review':
            node.module = 'check_art_review'
        return node

    def visit_Call(self, node):
        if ast.unparse(node) == 'project_root(__file__)':
            return ast.parse('Path(__file__).resolve().parents[1]', mode='eval').body
        return self.generic_visit(node)


def main():
    """Требует точную принятую промежуточную базу и сохраняет исходники до первого git mv."""
    assert git('rev-parse', 'HEAD').decode().strip() == BASE
    assert not git('diff', 'HEAD', '--name-only').strip()
    assert (ROOT / 'VERSION').read_text().strip() == '0.0.360'
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')
    assert all(not name or name.startswith('docs/reports/refactor-03/image-review-move/') for name in untracked)
    assert not (ROOT / 'tools/dev').exists()
    inputs = REPORT / 'inputs'
    inputs.mkdir()
    rows = []
    for old, target in MOVES.items():
        path = ROOT / old
        assert path.is_file() and not path.is_symlink() and not (ROOT / target).exists()
        raw = path.read_bytes()
        assert raw == git('show', BASE + ':' + old)
        new = prepared(old, raw)
        if old.endswith('.py'):
            assert ast.dump(ast.parse(raw), include_attributes=False) == ast.dump(Addresses().visit(ast.parse(new)), include_attributes=False)
            compile(new, target, 'exec')
        elif old.endswith(('.gd', '.uid')):
            assert raw == new
        (inputs / (Path(old).name + '.gz')).write_bytes(gzip.compress(raw, mtime=0))
        rows.append({'old_path': old, 'target': target, 'before_sha256': hashlib.sha256(raw).hexdigest(),
                     'after_sha256': hashlib.sha256(new).hexdigest(), 'mode': path.stat().st_mode & 0o777})
    ignore = ROOT / '.gitignore'
    (inputs / 'gitignore.txt.gz').write_bytes(gzip.compress(ignore.read_bytes(), mtime=0))
    ignore.write_text(ignore.read_text() + '\n# REFACTOR-03: independent art review tools and one original tracked UID.\n!tools/dev/\ntools/dev/*\n!tools/dev/__init__.py\n!tools/dev/art_review/\ntools/dev/art_review/*\n!tools/dev/art_review/*.py\n!tools/dev/art_review/*.gd\n!tools/dev/art_review/*.mjs\n!tools/dev/art_review/art_review_export.gd.uid\n')
    (ROOT / 'tools/dev/art_review').mkdir(parents=True)
    (ROOT / 'tools/dev/__init__.py').write_text('"""Ручные офлайн-стенды разработки."""\n')
    (ROOT / 'tools/dev/art_review/__init__.py').write_text('"""Проверка и локальный просмотр прежнего художественного каталога."""\n')
    for row in rows:
        raw = gzip.decompress((inputs / (Path(row['old_path']).name + '.gz')).read_bytes())
        git('mv', '--', row['old_path'], row['target'])
        (ROOT / row['target']).write_bytes(prepared(row['old_path'], raw))
        assert (ROOT / row['target']).stat().st_mode & 0o777 == row['mode']
    with (REPORT / 'migration.json').open('x') as stream:
        json.dump({'base': BASE, 'from_version': '0.0.360', 'moves': rows, 'root_after': 504,
                   'tracked_UID_moves': 1, 'ignored_UID_moves': 0,
                   'assignment_override': {'old_path': 'tools/import_pixabay_assets.py',
                                           'historical_target': 'tools/assets/audio/import_pixabay_assets.py',
                                           'actual_target': MOVES['tools/import_pixabay_assets.py'],
                                           'reason': 'PIL image importer; no audio processing'},
                   'full_task03_accepted': False}, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps({'source_moves': 5, 'tracked_assignments': len(rows), 'tracked_UID': 1, 'AST_and_mode_preserved': True}))


if __name__ == '__main__':
    main()
