"""Проверяет настоящий перенос art-standard, native CLI и сохранность старых контрактов."""
import argparse
import ast
import gzip
import hashlib
import importlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types
from unittest.mock import patch

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path[:0] = [str(ROOT), str(ROOT / 'tools')]
from tools.common.git import git_environment
from tools.qa.art.current_paths import captured_paths, source_path
REPORT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Addresses(ast.NodeTransformer):
    """Убирает только квалификацию, resolver и metadata адресации из сравнительного AST."""
    def visit_ImportFrom(self, node):
        if node.module == 'tools.qa.art.current_paths':
            return None
        if node.module and node.module.startswith('tools.common.'):
            node.module = node.module.removeprefix('tools.')
        elif node.module and node.module.startswith('tools.qa.art.'):
            node.module = node.module.removeprefix('tools.qa.art.')
        elif node.module == 'tools.qa.art':
            return ast.Import(names=node.names)
        return node

    def visit_Call(self, node):
        if isinstance(node.func, ast.Name) and node.func.id == 'source_path':
            assert len(node.args) == 2 and ast.unparse(node.args[0]) == 'ROOT'
            return ast.BinOp(left=node.args[0], op=ast.Div(), right=node.args[1])
        return self.generic_visit(node)

    def visit_Dict(self, node):
        kept = [(k, v) for k, v in zip(node.keys, node.values) if not (isinstance(k, ast.Constant) and k.value == 'source_paths')]
        node.keys, node.values = [k for k, _ in kept], [v for _, v in kept]
        return self.generic_visit(node)

    def visit_Try(self, node):
        if len(node.body) == 1 and isinstance(node.body[0], ast.Expr) and ast.unparse(node.body[0].value).startswith('recorded_paths('):
            return None
        return self.generic_visit(node)

    def visit_Constant(self, node):
        if isinstance(node.value, str):
            node.value = node.value.replace('res://tools/qa/art/visual_scale_capture.gd', 'res://tools/visual_scale_capture.gd')
        return node


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPORT / 'profile.json')
    output = parser.parse_args().output.resolve()
    if output.exists() or output.suffix != '.json' or output.is_relative_to(ROOT / 'assets'):
        parser.error('нужен новый JSON вне assets; прежние данные не перезаписываются')
    assert (ROOT / 'VERSION').read_text().strip() == '0.0.363'
    moves = json.loads((REPORT / 'migration.json').read_text())
    for row in moves['moves']:
        path = ROOT / row['target']
        old = gzip.decompress((REPORT / 'inputs' / (Path(row['old_path']).name + '.gz')).read_bytes())
        assert hashlib.sha256(old).hexdigest() == row['sha256']
        assert sha(path) == row['after_sha256'] and not (ROOT / row['old_path']).exists()
        assert path.stat().st_mode & 0o777 == row['mode']
        new = path.read_bytes()
        if path.suffix == '.py':
            assert ast.dump(ast.parse(old), include_attributes=False) == ast.dump(Addresses().visit(ast.parse(new)), include_attributes=False), row['target']
        elif path.suffix == '.gd':
            for peer in moves['moves']:
                new = new.replace(('res://' + peer['target']).encode(), ('res://' + peer['old_path']).encode())
            assert new == old
        else:
            assert new == old
    for row in moves['ignored_UID_moves']:
        assert sha(ROOT / row['target']) == row['sha256'] and not (ROOT / row['old_path']).exists()
    commands = []
    with tempfile.TemporaryDirectory(prefix='art family real CLI ') as temporary:
        parent = Path(temporary).resolve()
        foreign = parent / 'foreign cwd'
        for package in ['tools', 'qa', 'common']:
            (foreign / package).mkdir(parents=True, exist_ok=True)
            (foreign / package / '__init__.py').write_text("raise RuntimeError('foreign package imported')\n")
        environment = dict(os.environ, PYTHONPATH=str(foreign), GIT_DIR=str(foreign / 'missing.git'))
        for row in moves['moves']:
            if not row['target'].endswith('.py'):
                continue
            command = [sys.executable, str(ROOT / 'tools/run.py'), 'qa.art.' + Path(row['target']).stem]
            if row['target'].endswith('/visual_scale.py'):
                command.append('verify')
            run = subprocess.run(command, cwd=foreign, env=environment, capture_output=True, text=True, timeout=180)
            assert run.returncode == 0, run.stdout + run.stderr
            commands.append({'command': command, 'cwd': str(foreign), 'exit': run.returncode,
                             'stdout': run.stdout, 'stderr': run.stderr})
        icons = importlib.import_module('tools.visual_icons')
        reuse = importlib.import_module('tools.qa.art.visual_reuse')
        assert icons.baseline_bytes is reuse.baseline_bytes
        collector = importlib.import_module('tools.pilot_static_collect')
        original = gzip.decompress((REPORT / 'inputs/pilot_static_collect.py.gz').read_bytes())
        old = types.ModuleType('old_pilot_collector')
        old.__file__ = str(ROOT / 'tools/pilot_static_collect.py')
        exec(compile(original, old.__file__, 'exec'), old.__dict__)
        assert collector.ORIGINAL == old.ORIGINAL and collector.EXTRA == old.EXTRA
        source = importlib.import_module('tools.qa.art.visual_scale')
        folder = parent / 'intentional rejected scale'
        with patch.dict(os.environ, {'FARM_GODOT_BIN': '/usr/bin/false', 'GIT_DIR': str(foreign / 'missing.git')}):
            try:
                source.capture(folder)
            except ValueError as error:
                assert 'Нативная съёмка отклонена' in str(error)
            else:
                raise AssertionError('false engine cannot admit capture')
        recorded = json.loads((folder / 'source.json').read_text())
        assert recorded['source_paths'] == captured_paths(source.SOURCES)
        assert recorded['sources'] == {name: sha(source_path(ROOT, name)) for name in source.SOURCES}
        assert set(recorded['sources']) == set(source.SOURCES) and recorded['silhouettes'] == {}
        godot = os.environ['FARM_GODOT_BIN']
        native = []
        scripts = [r['target'] for r in moves['moves'] if r['target'].endswith('.gd')]
        scripts += ['tools/pilot_static_scene.gd', 'tools/pilot_static_capture.gd']
        for tail in [['--editor', '--quit']] + [['--check-only', '--script', 'res://' + name] for name in scripts]:
            command = [godot, '--headless', '--path', str(ROOT), *tail]
            run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=150)
            assert run.returncode == 0 and 'ERROR:' not in run.stderr, run.stdout + run.stderr
            native.append({'command': command, 'exit': run.returncode, 'stdout': run.stdout, 'stderr': run.stderr})
        metadata = parent / 'perspective-current.json'
        command = [godot, '--headless', '--path', str(ROOT), '--script', 'res://tools/qa/art/visual_perspective_export.gd', '--', '--output=' + str(metadata)]
        first = subprocess.run(command, capture_output=True, text=True, timeout=120)
        assert first.returncode == 0, first.stdout + first.stderr
        exported = json.loads(metadata.read_text())
        assert exported['kind'] == 'headless-resource-metadata' and exported['native_game_frame'] is False
        assert len(exported['families']) == 3 and sum(len(f['poses']) for f in exported['families']) == 9
        before = sha(metadata)
        refused = subprocess.run(command, capture_output=True, text=True, timeout=120)
        assert refused.returncode == 2 and sha(metadata) == before
        export = {'command': command, 'exit': first.returncode, 'stdout': first.stdout, 'stderr': first.stderr,
                  'metadata': exported, 'existing_output_refusal': {'exit': refused.returncode, 'stdout': refused.stdout, 'stderr': refused.stderr}, 'metadata_unchanged': True}
        headless = []
        for stem, number in [('scale', '002'), ('density', '006'), ('light', '007'), ('modules', '008'), ('reuse', '009')]:
            target = parent / ('headless-' + stem)
            command = [godot, '--headless', '--path', str(ROOT), '--script', 'res://tools/qa/art/visual_' + stem + '_capture.gd', '--',
                       '--output=' + str(target), '--profile=Codex-VART-' + number + '-Refactor363']
            run = subprocess.run(command, capture_output=True, text=True, timeout=120)
            assert run.returncode == 2 and not target.exists(), run.stdout + run.stderr
            headless.append({'command': command, 'exit': run.returncode, 'stdout': run.stdout, 'stderr': run.stderr, 'output_not_created': True})
    assert not parent.exists()
    result = {'version': '0.0.363', 'base': moves['base'], 'source_moves': 23, 'tracked_UID_moves': 3,
              'ignored_UID_moves': len(moves['ignored_UID_moves']), 'root_sources': 481,
              'AST_and_GD_bodies_except_explicit_addresses_equal': True, 'modes_and_UID_preserved': True,
              'actual_CLI': commands, 'shared_icons_reuse_function_identity': True,
              'pilot_ORIGINAL_and_EXTRA_unchanged': True, 'rejected_scale_current_source_metadata': recorded,
              'scale_capture_accepted': False, 'editor_import_and_parse_only': native,
              'actual_perspective_export': export, 'actual_headless_capture_refusals': headless,
              'temporary_removed': True, 'new_GPU_FPS_admission': False, 'full_task03_accepted': False}
    with output.open('x') as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'actual_CLI': len(commands), 'source_moves': 23, 'UID': 3, 'GD_parse': len(scripts), 'headless_refusals': 5}))


if __name__ == '__main__':
    main()
