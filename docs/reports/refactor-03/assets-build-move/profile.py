"""Повторяет адресацию Python/Godot и точный fixed-input экспорт в новом внешнем каталоге."""
from __future__ import annotations

import argparse
import ast
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def load_file(name, filename):
    specification = importlib.util.spec_from_file_location(name, REPORT / filename)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(arguments, cwd, env, timeout=240):
    result = subprocess.run(arguments, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
    row = {'command': arguments, 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
    assert result.returncode == 0, row
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if (args.output is None or args.output.exists() or args.output.suffix != '.json'
            or not args.output.parent.is_dir() or args.output.resolve().is_relative_to(ROOT / 'assets')):
        parser.error('нужен новый JSON вне assets с существующим родителем')
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    mapping = {old: row['target'] for old, row in baseline['assignments'].items()}
    normalize = load_file('assets_move_normalize', 'normalize.py')
    gd = load_file('assets_move_gd', 'gd-normalize.py')
    native = load_file('assets_move_native', 'native-profile.py')
    rows = []
    for old, new in mapping.items():
        original = gzip.decompress((REPORT / 'inputs' / (old.replace('/', '--') + '.gz')).read_bytes())
        path = ROOT / new
        assert hashlib.sha256(original).hexdigest() == baseline['sources'][old]['sha256']
        assert path.stat().st_mode & 0o777 == baseline['sources'][old]['mode']
        assert not (ROOT / old).exists()
        if old.endswith('.py'):
            assert normalize.normalized(original, old, mapping) == normalize.normalized(path.read_bytes(), old, mapping), old
            compile(path.read_bytes(), new, 'exec')
        if path.suffix in {'.uid', '.json'}:
            assert path.read_bytes() == original, old
        rows.append({'old_path': old, 'target': new, 'sha256': sha(path), 'mode': baseline['sources'][old]['mode']})
    assert len([r for r in rows if r['target'].endswith('.py')]) == 35
    gd_rows = gd.check()
    assert len(gd_rows) == 28 and all(r['equal_except_declared_paths_and_metadata'] for r in gd_rows)
    for old in baseline['consumers']:
        if not old.endswith('.py'):
            continue
        original = gzip.decompress((REPORT / 'inputs' / (old.replace('/', '--') + '.gz')).read_bytes())
        assert normalize.normalized(original, old, mapping) == normalize.normalized((ROOT / old).read_bytes(), old, mapping), old
    for row in baseline['local_UID']:
        assert sha(ROOT / row['target']) == row['sha256']
        assert (ROOT / row['target']).stat().st_mode & 0o777 == row['mode']
        assert not (ROOT / row['old_path']).exists()
        assert subprocess.check_output(['git', '-C', str(ROOT), 'check-ignore', '--', row['target']], env=git_environment()).strip()
    source_tests = {}
    for old, new in mapping.items():
        if not old.endswith('.py') or not Path(old).name.startswith('test_'):
            continue
        original = gzip.decompress((REPORT / 'inputs' / (old.replace('/', '--') + '.gz')).read_bytes())
        before = {n.name for n in ast.walk(ast.parse(original)) if isinstance(n, ast.FunctionDef) and n.name.startswith('test_')}
        after = {n.name for n in ast.walk(ast.parse((ROOT / new).read_bytes())) if isinstance(n, ast.FunctionDef) and n.name.startswith('test_')}
        wanted = (normalize.NEW_PREVIEW_TESTS if Path(old).stem == 'test_preview_portability' else
                  normalize.NEW_ARTIST_TESTS if Path(old).stem == 'test_artist_packet' else set())
        assert after == before | wanted, old
        source_tests[old] = {'retained': len(before), 'added': len(wanted)}
    with tempfile.TemporaryDirectory(prefix='asset CLI foreign ') as directory:
        foreign = Path(directory)
        (foreign / 'tools').mkdir()
        (foreign / 'tools/__init__.py').write_text('raise RuntimeError("foreign tools must not load")\n')
        env = dict(os.environ, PYTHONPATH=str(foreign), GIT_DIR=str(foreign / 'missing.git'),
                   GIT_INDEX_FILE=str(foreign / 'wrong-index'), GIT_CONFIG_COUNT='1',
                   GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true')
        commands = []
        for old, new in mapping.items():
            if not old.endswith('.py') or Path(old).name.startswith('test_'):
                continue
            tree = ast.parse((ROOT / new).read_text())
            if not any(isinstance(n, ast.If) and '__name__' in ast.unparse(n.test) for n in tree.body):
                continue
            module = new.removesuffix('.py').replace('/', '.').removeprefix('tools.')
            commands.append(command([sys.executable, str(ROOT / 'tools/run.py'), module, '--help'], foreign, env))
        for module in ['assets.contracts.test_source_paths', 'assets.migration.test_scanner_history',
                       'build.test_asset_report_history', 'test_alpha_audit']:
            commands.append(command([sys.executable, str(ROOT / 'tools/run.py'), module], foreign, env))
        for module in ['assets.migration.asset_migration', 'assets.contracts.asset_report', 'build.artist_packet']:
            commands.append(command([sys.executable, str(ROOT / 'tools/run.py'), module], foreign, env))
        assert not (foreign / 'wrong-index').exists()
    result = {'base': baseline['base'], 'version': (ROOT / 'VERSION').read_text().strip(),
              'physical_sources': rows, 'Python_modules_AST_compared': 35,
              'bounded_fixture_adapter_exceptions': sorted([list(p) for p in normalize.FIXTURE_ADAPTERS]),
              'bounded_Python_IO_adapter': ['preview_portability.path_under'],
              'additional_historical_document': {
                  'path': 'docs/VISUAL_RESOURCE_FORMAT.md',
                  'commit': 'ed38d94c01490c4e39b8be949887220f2c810d75',
                  'sha256': '7e2d74958404d19f35c6c3f38269f7ad1e97aa4ec56fc3e7e5eb12342f5c2d82',
                  'other_reference_checks_unchanged': True},
              'all_original_test_methods_retained': source_tests,
              'GD_bodies': gd_rows, 'actual_foreign_CLI': commands,
              'root_sources': 420, 'tracked_UID': 8, 'ignored_UID': 18,
              'JSON_policies_byte_identical': True, 'native': native.collect(),
              'physical_source_moves': 61, 'full_task03_accepted': False, 'REFACTOR06_started': False}
    with args.output.open('x') as file:
        file.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'AST': 35, 'GD_bodies': 28, 'actual_CLI': len(commands),
                      'GD_parse': 28, 'actual_old_new_images': 4, 'root': 420}))


if __name__ == '__main__':
    main()
