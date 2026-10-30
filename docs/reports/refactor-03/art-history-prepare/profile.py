"""Сравнивает настоящие старые/new readers и проверяет их на disposable Git clone."""
import argparse
import ast
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import types

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

REPORT = Path(__file__).resolve().parent
BASE = '832964d4de4a0a0207500dd185039642738874e7'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


class Addresses(ast.NodeTransformer):
    """Нормализует только задекларированные root/import/pin/Git-env изменения."""
    def __init__(self, pins):
        self.pins = pins

    def visit_ImportFrom(self, node):
        if node.module in {'common.paths', 'common.git', 'common.history'}:
            return None
        return node

    def visit_Assign(self, node):
        if any(isinstance(t, ast.Name) and t.id in self.pins for t in node.targets):
            return None
        return self.generic_visit(node)

    def visit_Call(self, node):
        if ast.unparse(node) == 'project_root(__file__)':
            return ast.parse('Path(__file__).resolve().parents[1]', mode='eval').body
        if isinstance(node.func, ast.Name) and node.func.id == 'pinned_sha':
            assert len(node.args) == 2 and isinstance(node.args[1], ast.Starred)
            name = node.args[1].value.id
            return ast.parse("sha(ROOT / " + repr(self.pins[name][0]) + ")", mode='eval').body
        if ast.unparse(node.func) in {'subprocess.run', 'subprocess.check_output'}:
            node.keywords = [k for k in node.keywords if not (k.arg == 'env' and ast.unparse(k.value) == 'git_environment()')]
        return self.generic_visit(node)


def load(name, path, raw):
    """Исполняет реальные исходные байты, сохраняя их настоящий fixture __file__."""
    module = types.ModuleType(name)
    module.__file__ = str(path)
    exec(compile(raw, str(path), 'exec'), module.__dict__)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPORT / 'profile.json')
    output = parser.parse_args().output.resolve()
    if output.exists() or output.suffix != '.json' or output.is_relative_to(ROOT / 'assets'):
        parser.error('нужен новый JSON вне assets; прежние результаты не перезаписываются')
    baseline = json.loads((REPORT / 'baseline/sources.json').read_text())
    pins = json.loads((REPORT / 'baseline/capture-pins.json').read_text())
    old, new = {}, {}
    for relative, digest in baseline['sources'].items():
        before = gzip.decompress((REPORT / 'inputs' / (Path(relative).name + '.gz')).read_bytes())
        assert sha(before) == digest
        after = (ROOT / relative).read_bytes()
        constants = {n.targets[0].id: ast.literal_eval(n.value) for n in ast.parse(after).body
                     if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name)
                     and n.targets[0].id in {'CAPTURE_SOURCE', 'ADAPTER_SOURCE'}}
        for value in constants.values():
            assert any(value == (r['source'], pins['base'], r['sha256']) for r in pins['rows'])
        assert ast.dump(ast.parse(before), include_attributes=False) == ast.dump(Addresses(constants).visit(ast.parse(after)), include_attributes=False)
        old[relative], new[relative] = before, after
    protected = {r['source']: sha((ROOT / r['source']).read_bytes()) for r in pins['rows']}
    protected.update({r['capture']: sha((ROOT / r['capture']).read_bytes()) for r in pins['rows']})
    results, cli = [], []
    with tempfile.TemporaryDirectory(prefix='art history real clone ') as temporary:
        parent = Path(temporary)
        project = (parent / 'project with spaces').resolve()
        subprocess.run(['git', 'clone', '-q', '--shared', '--no-checkout', str(ROOT), str(project)],
                       env=git_environment(), check=True)
        for relative in ['VERSION', 'project.godot', 'tools/__init__.py',
                         *[str(p.relative_to(ROOT)) for p in (ROOT / 'tools/common').glob('*.py')],
                         'docs/epics/visual-overhaul-2026-10/backlog.json']:
            target = project / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        for row in pins['rows']:
            target = project / row['source']
            target.write_bytes((ROOT / row['source']).read_bytes())
        sys.path.insert(0, str(project / 'tools'))
        families = [('density', 'vart-006'), ('light', 'vart-007'), ('modules', 'vart-008'), ('reuse', 'vart-009')]
        modules = {}
        for mode, sources in [('old', old), ('new', new)]:
            modules[mode] = {}
            for family, task in families:
                relative = 'tools/visual_' + family + '.py'
                target = project / relative
                target.write_bytes(sources[relative])
                module = load(mode + '_' + family, target, sources[relative])
                assert module.ROOT == project
                module.REPORT = ROOT / 'docs/reports/visual-overhaul' / task
                assert module.verify() == []
                modules[mode][family] = module
        for row in pins['rows']:
            target = project / 'tools/qa/art' / Path(row['source']).name
            target.parent.mkdir(parents=True, exist_ok=True)
            (project / row['source']).rename(target)
        for family, _ in families:
            try:
                errors = modules['old'][family].verify()
            except FileNotFoundError as error:
                errors = [str(error)]
            assert errors, 'legacy reader unexpectedly survived missing live source'
            assert modules['new'][family].verify() == []
            results.append({'family': family, 'legacy_after_fixture_move': errors,
                            'prepared_before_and_after_fixture_move': 'pass'})
        # Подмена сохранённого source SHA должна отклоняться настоящими readers, а не одной HTML-синхронизацией.
        corrupt = []
        original_density = modules['new']['density']
        data = original_density.read(original_density.REPORT / 'density-profile.json')
        proof = original_density.read(original_density.REPORT / 'native/capture.json')
        proof['capture_script_sha256'] = '0' * 64
        assert 'native configuration' in original_density.native_errors(proof, data)
        corrupt.append('density: native configuration')
        mirrors = parent / 'mirrored reports'
        mirrors.mkdir()
        for path in (ROOT / 'docs/reports/visual-overhaul').glob('vart-00*'):
            (mirrors / path.name).symlink_to(path, target_is_directory=True)
        for family, task in families[1:]:
            destination = mirrors / task
            destination.unlink()
            shutil.copytree(ROOT / 'docs/reports/visual-overhaul' / task, destination,
                            copy_function=lambda source, target: Path(target).symlink_to(Path(source).resolve()))
            capture = destination / 'native/capture.json'
            changed = json.loads(capture.read_text())
            changed['script_sha256'] = '0' * 64
            capture.unlink()
            capture.write_text(json.dumps(changed))
            module = modules['new'][family]
            original_report = module.REPORT
            module.REPORT = destination
            expected = 'capture code hash' if family == 'reuse' else 'script hash'
            assert expected in module.verify()
            corrupt.append(family + ': ' + expected)
            module.REPORT = original_report
        # Отсутствующая история отказывает даже при наличии точных рабочих копий всех пяти source.
        unavailable = parent / 'no historical commit'
        unavailable.mkdir()
        subprocess.run(['git', '-C', str(unavailable), 'init', '-q'], env=git_environment(), check=True)
        for row in pins['rows']:
            target = unavailable / row['source']
            target.parent.mkdir(exist_ok=True)
            target.write_bytes((ROOT / row['source']).read_bytes())
        denied = []
        for family, _ in families:
            module = modules['new'][family]
            original_root = module.ROOT
            module.ROOT = unavailable
            try:
                module.verify()
            except ValueError as error:
                denied.append({'family': family, 'error': str(error)})
            else:
                raise AssertionError('missing history was accepted')
            finally:
                module.ROOT = original_root
        assert len(denied) == 4
        foreign = parent / 'foreign cwd'
        for package in ['tools', 'common']:
            (foreign / package).mkdir(parents=True, exist_ok=True)
            (foreign / package / '__init__.py').write_text("raise RuntimeError('foreign package imported')\n")
        hostile = dict(os.environ, PYTHONPATH=str(foreign), GIT_DIR=str(foreign / 'missing.git'))
        for relative in new:
            command = [sys.executable, str(ROOT / relative)] + (['verify'] if relative.endswith('visual_scale.py') else [])
            run = subprocess.run(command, cwd=foreign, env=hostile, capture_output=True, text=True, timeout=180)
            assert run.returncode == 0, run.stdout + run.stderr
            cli.append({'command': command, 'cwd': str(foreign), 'exit': run.returncode,
                        'stdout': run.stdout, 'stderr': run.stderr})
        assert all(sha((ROOT / p).read_bytes()) == digest for p, digest in protected.items())
    assert not parent.exists()
    result = {'base': BASE, 'version': (ROOT / 'VERSION').read_text().strip(), 'physical_moves': 0,
              'root_sources': 504, 'AST_algorithms_except_declared_addresses_equal': True,
              'actual_readers': results, 'corrupt_capture_SHA_rejected': corrupt,
              'unavailable_history_without_live_fallback': denied, 'foreign_CLI': cli,
              'five_GD_and_frozen_capture_SHA_unchanged': protected,
              'temporary_clone_removed': True, 'real_GPU_capture_not_run': True,
              'full_task03_accepted': False}
    with output.open('x') as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'readers': 4, 'pins': 5, 'corrupt': len(corrupt), 'missing_history': len(denied), 'foreign_CLI': len(cli)}))


if __name__ == '__main__':
    main()
