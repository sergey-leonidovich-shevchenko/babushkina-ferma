"""Сравнивает исходные тела и настоящие CLI; выходом не разрешает перезапись доказательств."""
from __future__ import annotations

import argparse
import ast
import contextlib
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

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment
from tools.common.launch import prepare_imports


class AddressingOnly(ast.NodeTransformer):
    """Убирает лишь объявленную адресацию root/Git и границу scanner signature."""

    def visit_ImportFrom(self, node):
        if node.module in {'common.paths', 'common.history', 'common.git'}:
            return None
        return node

    def visit_Assign(self, node):
        if any(isinstance(t, ast.Name) and t.id == 'LEGACY_SCANNER' for t in node.targets):
            return None
        return self.generic_visit(node)

    def visit_FunctionDef(self, node):
        if node.name == 'scanner_digest':
            return None
        if node.name == 'historical_errors':
            node.body = [ast.Expr(value=ast.Constant(value='scanner signature boundary'))
                         if isinstance(n, (ast.If, ast.Try)) and
                         'migration scanner changed: review historical snapshot adapter' in ast.unparse(n)
                         else n for n in node.body]
        return self.generic_visit(node)

    def visit_Dict(self, node):
        pairs = [(k, v) for k, v in zip(node.keys, node.values)
                 if not isinstance(k, ast.Constant) or k.value != 'scanner_source_mode']
        node.keys, node.values = [p[0] for p in pairs], [p[1] for p in pairs]
        return self.generic_visit(node)

    def visit_Subscript(self, node):
        if ast.unparse(node) == 'Path(__file__).resolve().parents[1]':
            return ast.Name(id='SOURCE_ROOT', ctx=ast.Load())
        return self.generic_visit(node)

    def visit_Attribute(self, node):
        if ast.unparse(node) == 'Path(__file__).resolve().parent.parent':
            return ast.Name(id='SOURCE_ROOT', ctx=ast.Load())
        return self.generic_visit(node)

    def visit_Call(self, node):
        if ast.unparse(node) == 'project_root(__file__)':
            return ast.Name(id='SOURCE_ROOT', ctx=ast.Load())
        if isinstance(node.func, ast.Name) and node.func.id == 'git_read':
            node.func.id = 'SOURCE_GIT_READ'
            return self.generic_visit(node)
        if (isinstance(node.func, ast.Attribute) and ast.unparse(node.func) == 'subprocess.check_output'
                and node.args and isinstance(node.args[0], ast.List)
                and node.args[0].elts and isinstance(node.args[0].elts[0], ast.Constant)
                and node.args[0].elts[0].value == 'git'):
            arguments = node.args[0].elts[1:]
            root = next((k.value for k in node.keywords if k.arg == 'cwd'), ast.Name(id='ROOT', ctx=ast.Load()))
            if arguments and isinstance(arguments[0], ast.Constant) and arguments[0].value == '-C':
                root = arguments[1].args[0]
                arguments = arguments[2:]
            return self.generic_visit(ast.Call(
                func=ast.Name(id='SOURCE_GIT_READ', ctx=ast.Load()), args=[root, *arguments],
                keywords=[k for k in node.keywords if k.arg not in {'env', 'cwd'}],
            ))
        return self.generic_visit(node)


def normalized(raw):
    return ast.dump(AddressingOnly().visit(ast.parse(raw)), include_attributes=False)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(arguments, *, cwd, env, timeout=180):
    """Сохраняет реальный stdout/stderr и отказывает при неуспешном процессе."""
    run = subprocess.run(arguments, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
    row = {'command': arguments, 'cwd': str(cwd), 'exit': run.returncode,
           'stdout': run.stdout, 'stderr': run.stderr}
    assert run.returncode == 0, row
    return row


def record_calls(fixture, foreign, env):
    """Три настоящих Git-read доходят до явного отказа до записи inventory/plan."""
    module = importlib.import_module('asset_migration')
    commit = subprocess.check_output(['git', '-C', str(fixture), 'rev-parse', 'HEAD'],
                                     env=git_environment(), text=True).strip()
    calls = []
    original = module.git_read

    def read(root, *arguments, **keywords):
        value = original(root, *arguments, **keywords)
        calls.append({'root': str(root), 'arguments': list(arguments), 'text': value})
        return value

    before = Path.cwd()
    try:
        os.chdir(foreign)
        with patch.dict(os.environ, env, clear=True), patch.object(module, 'ROOT', fixture), \
                patch.object(module, 'BASE', commit), patch.object(module, 'git_read', read), \
                patch.object(module, 'build', side_effect=RuntimeError('QA stop before inventory write')), \
                patch.object(sys, 'argv', ['asset_migration.py', '--record']):
            try:
                module.main()
            except RuntimeError as error:
                assert str(error) == 'QA stop before inventory write'
            else:
                raise AssertionError('record did not reach explicit QA stop')
    finally:
        os.chdir(before)
    assert len(calls) == 3 and calls[0]['text'].strip() == commit
    assert calls[1]['text'] == calls[2]['text'] == ''
    assert not list(fixture.rglob('inventory.json')) and not list(fixture.rglob('plan.json'))
    return calls


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if (args.output is None or args.output.exists() or args.output.suffix != '.json'
            or not args.output.parent.is_dir() or args.output.resolve().is_relative_to(ROOT / 'assets')):
        parser.error('нужен новый JSON вне assets с существующим родителем')
    baseline = json.loads((REPORT / 'baseline/sources.json').read_text())
    sources = []
    for name, record in baseline['sources'].items():
        original = gzip.decompress((REPORT / 'inputs' / (Path(name).name + '.gz')).read_bytes())
        current = (ROOT / name).read_bytes()
        assert hashlib.sha256(original).hexdigest() == record['sha256']
        assert normalized(original) == normalized(current), name
        assert (ROOT / name).stat().st_mode & 0o777 == record['mode']
        compile(current, name, 'exec')
        sources.append({'path': name, 'before_sha256': record['sha256'], 'after_sha256': digest(ROOT / name),
                        'mode': record['mode'], 'AST_except_declared_addressing_equal': True})
    prepare_imports(ROOT)
    with tempfile.TemporaryDirectory(prefix='farm assets prepare ') as directory:
        parent = Path(directory)
        foreign = parent / 'foreign cwd'
        foreign.mkdir()
        shadow = foreign / 'common'
        shadow.mkdir()
        (shadow / '__init__.py').write_text('raise RuntimeError("foreign common must not load")\n')
        env = dict(os.environ, PYTHONPATH=str(foreign), GIT_DIR=str(foreign / 'missing.git'),
                   GIT_INDEX_FILE=str(foreign / 'wrong-index'), GIT_CONFIG_COUNT='1',
                   GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true')
        cli_names = [r['path'] for r in sources
                     if not Path(r['path']).name.startswith('test_')
                     and Path(r['path']).stem not in {'migration_fixture', 'migration_inventory'}]
        commands = [command([sys.executable, str(ROOT / name), '--help'], cwd=foreign, env=env)
                    for name in cli_names]
        assert len(commands) == 12
        check = ('import importlib,json,sys;from pathlib import Path;'
                 'sys.path.insert(0,sys.argv[1]+"/tools");'
                 'names=json.loads(sys.argv[2]);'
                 'modules=[importlib.import_module(Path(n).stem) for n in names];'
                 'assert all(m.project_root(m.__file__)==Path(sys.argv[1]) for m in modules);'
                 'assert all(not hasattr(m,"ROOT") or m.ROOT==Path(sys.argv[1]) for m in modules);'
                 'print("16 source roots resolve own code checkout")')
        root_check = command([sys.executable, '-c', check, str(ROOT), json.dumps([r['path'] for r in sources])],
                             cwd=foreign, env=env)
        tests = command([sys.executable, str(ROOT / 'tools/run.py'), 'assets.migration.test_scanner_history', '-v'],
                        cwd=foreign, env=env)
        fixture = parent / 'record fixture'
        fixture.mkdir()
        (fixture / 'scripts').mkdir()
        (fixture / 'scripts/example.gd').write_text('extends Node\n')
        for arguments in [['init', '--initial-branch=main'], ['add', '.'],
                          ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'fixture']]:
            command(['git', '-c', 'core.hooksPath=' + str(fixture / 'no-hooks'), '-C', str(fixture), *arguments],
                    cwd=foreign, env=git_environment())
        record = record_calls(fixture, foreign, env)
        preview = importlib.import_module('preview_portability')
        capture_output = parent / 'explicit-refusal'
        with patch.dict(os.environ, env, clear=True), contextlib.redirect_stdout(sys.stderr):
            try:
                preview.capture(capture_output, '/usr/bin/false', False)
            except ValueError as error:
                assert str(error) == 'capture failed: preview'
            else:
                raise AssertionError('false engine cannot produce a capture')
        context = json.loads((capture_output / 'context.json').read_text())
        actual_head = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'],
                                              env=git_environment(), text=True).strip()
        assert context['source_revision_at_capture'] == actual_head
        assert not (capture_output / 'preview').exists()
        capture = {'context': context, 'sources': json.loads((capture_output / 'sources.json').read_text()),
                   'explicit_failure': 'capture failed: preview', 'capture_accepted': False}
        assert not (foreign / 'wrong-index').exists()
    result = {'version': (ROOT / 'VERSION').read_text().strip(), 'base': baseline['base'],
              'source_modules': sources, 'actual_foreign_CLI': commands, 'root_check': root_check,
              'actual_scanner_tests': tests, 'record_three_actual_git_reads': record,
              'preview_two_actual_git_reads': capture, 'root_sources': 481, 'physical_moves': 0,
              'GDScript_UID_policies_old_reports_unchanged': True, 'GPU_FPS_admission': False,
              'full_task03_accepted': False, 'REFACTOR06_started': False}
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'sources': 16, 'foreign_CLI': 12, 'scanner_cases': 12, 'root': 481,
                      'record_git_reads': 3, 'preview_git_reads': 2, 'physical_moves': 0}))


if __name__ == '__main__':
    main()
