"""Переносит четыре связанных аудио-инструмента после принятого промежуточного P2."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

REPORT = Path(__file__).resolve().parent
BASE = '5ba619a3f2ce39845b4b71eee34d267ead05201e'
ORIGIN = 'd609ab4fa6d82d6d013265183f018b8836abf7cc'
NAMES = ['audio_composer', 'audio_sound_effects', 'audit_audio_assets', 'generate_audio_assets']


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=git_environment())


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


class Addresses(ast.NodeTransformer):
    """Нормализует только согласованные импорты и адресацию корня для сравнения алгоритмов."""
    def visit_ImportFrom(self, node):
        if node.module == 'tools.common.paths':
            return None
        if node.module and node.module.startswith('tools.assets.audio.'):
            node.module = node.module.rsplit('.', 1)[-1]
        return node

    def visit_Call(self, node):
        if ast.unparse(node) == 'project_root(__file__)':
            return ast.parse('Path(__file__).resolve().parents[1]', mode='eval').body
        return self.generic_visit(node)


def prepared(name, source):
    """Сохраняет тела функций; квалифицирует собственные зависимости и общий source-root."""
    for dependency in NAMES:
        source = source.replace('from ' + dependency + ' import ',
                                'from tools.assets.audio.' + dependency + ' import ')
    if name == 'audio_composer':
        source = source.replace('import numpy as np\n', 'import numpy as np\n\nfrom tools.common.paths import project_root\n')
        source = source.replace('ROOT = Path(__file__).resolve().parents[1]', 'ROOT = project_root(__file__)')
    return source.encode()


def main():
    """Отказывает на чужом/грязном source-срезе и сохраняет все входы до первого перемещения."""
    assert git('rev-parse', 'HEAD').decode().strip() == BASE
    assert not git('diff', 'HEAD', '--name-only').strip()
    assert (ROOT / 'VERSION').read_text().strip() == '0.0.359'
    assert not (REPORT / 'migration.json').exists()
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')
    assert all(not name or name.startswith('docs/reports/refactor-03/audio-move/') for name in untracked)
    folder = ROOT / 'tools/assets/audio'
    assert not folder.exists()
    inputs = REPORT / 'inputs'
    inputs.mkdir()
    rows = []
    for name in NAMES:
        old = 'tools/' + name + '.py'
        target = 'tools/assets/audio/' + name + '.py'
        path = ROOT / old
        assert path.is_file() and not path.is_symlink()
        raw = path.read_bytes()
        assert raw == git('show', BASE + ':' + old) == git('show', ORIGIN + ':' + old)
        future = prepared(name, raw.decode())
        assert ast.dump(ast.parse(raw), include_attributes=False) == ast.dump(Addresses().visit(ast.parse(future)), include_attributes=False)
        compile(future, target, 'exec')
        (inputs / (name + '.py.txt')).write_bytes(raw)
        rows.append({'old_path': old, 'target': target, 'old_sha256': sha(raw),
                     'new_sha256': sha(future), 'mode': path.stat().st_mode & 0o777})
    ignore = ROOT / '.gitignore'
    (inputs / 'gitignore.txt').write_bytes(ignore.read_bytes())
    ignore.write_text(ignore.read_text() + '\n# REFACTOR-03: offline audio sources; cache remains ignored.\n!tools/assets/audio/\ntools/assets/audio/*\n!tools/assets/audio/*.py\n')
    folder.mkdir()
    (folder / '__init__.py').write_text('"""Подготовка и аудит аудио: офлайн-инструменты, не код игрового кадра."""\n')
    for name, row in zip(NAMES, rows):
        git('mv', '--', row['old_path'], row['target'])
        (ROOT / row['target']).write_bytes(prepared(name, (inputs / (name + '.py.txt')).read_text()))
        assert (ROOT / row['target']).stat().st_mode & 0o777 == row['mode']
    policy_path = ROOT / 'tools/asset_provenance.json'
    raw = policy_path.read_bytes()
    (inputs / 'asset-provenance.json').write_bytes(raw)
    policy = json.loads(raw)
    for name in ['generate_audio_assets', 'audio_composer', 'audio_sound_effects']:
        old = 'tools/' + name + '.py'
        assert old not in policy['evidence_history']
        policy['evidence_history'][old] = {'commit': ORIGIN, 'sha256': sha(git('show', ORIGIN + ':' + old))}
    policy_path.write_text(json.dumps(policy, ensure_ascii=False, indent=2) + '\n')
    development = ROOT / 'docs/DEVELOPMENT.md'
    before = development.read_text()
    assert 'python3 tools/generate_audio_assets.py' in before
    development.write_text(before.replace('python3 tools/generate_audio_assets.py', 'python3 tools/run.py assets.audio.generate_audio_assets'))
    with (REPORT / 'migration.json').open('x') as stream:
        json.dump({'base': BASE, 'from_version': '0.0.359', 'moves': rows,
                   'new_historical_pins': 3, 'UID_moves': 0, 'algorithms_AST_preserved': True,
                   'deferred_assignment': {'old_path': 'tools/import_pixabay_assets.py',
                                           'effective_target': 'tools/assets/authoring/import_pixabay_assets.py',
                                           'reason': 'PIL image importer belongs to authoring; separate later asset-processing package'},
                   'full_task03_accepted': False}, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps({'moved_python': len(rows), 'algorithm_AST_equal': True, 'UID_moves': 0, 'new_source_pins': 3}))


if __name__ == '__main__':
    main()
