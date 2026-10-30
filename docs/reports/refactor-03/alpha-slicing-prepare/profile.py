"""Сохраняет действительные результаты producer до перемещения, не создавая новую GPU/FPS-приёмку."""
from __future__ import annotations

import argparse
import ast
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT))
import alpha_fixtures
import alpha_audit
import slice_audit
from tools.common.git import git_environment


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def files(root):
    return {p.relative_to(root).as_posix(): sha(p.read_bytes()) for p in root.rglob('*') if p.is_file()}


def run(command, cwd, env=None, expected=0, timeout=360):
    result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
    row = {'command': list(map(str, command)), 'exit': result.returncode,
           'stdout': result.stdout, 'stderr': result.stderr}
    assert result.returncode == expected, row
    if expected == 0:
        assert not any(marker in result.stdout + result.stderr for marker in ['SCRIPT ERROR', 'Parse Error', '\nERROR:']), row
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if (args.output.exists() or args.output.is_symlink() or args.output.suffix != '.json'
            or not args.output.parent.is_dir() or args.output.resolve().is_relative_to(ROOT / 'assets')):
        parser.error('new JSON outside assets with an existing parent required')
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    for name, row in baseline['planned_assignments'].items():
        assert (ROOT / name).is_file() and not (ROOT / row['target']).exists(), name
    # Все GD/JSON/метрики до физического переноса побайтно прежние.
    fixed = {n: v for n, v in baseline['sources'].items() if Path(n).suffix in {'.gd', '.json'}
             or Path(n).name in {'alpha_metrics.py', 'slice_metrics.py'}}
    for name, row in fixed.items():
        assert sha((ROOT / name).read_bytes()) == row['sha256'], name
    git_sites = []
    for name in ['tools/alpha_audit.py', 'tools/slice_audit.py']:
        for node in ast.walk(ast.parse((ROOT / name).read_text())):
            if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                    and isinstance(node.func.value, ast.Name) and node.func.value.id == 'subprocess'
                    and node.func.attr == 'check_output'):
                keywords = {k.arg: ast.unparse(k.value) for k in node.keywords}
                assert keywords.get('cwd') == 'ROOT' and keywords.get('env') == 'git_environment()'
                git_sites.append({'source': name, 'line': node.lineno, 'call': ast.unparse(node)})
    assert len(git_sites) == 8
    native, commands = [], []
    with tempfile.TemporaryDirectory(prefix='alpha slicing before move ') as directory:
        parent = Path(directory).resolve()
        foreign = parent / 'foreign cwd'
        foreign.mkdir()
        env = dict(os.environ, PYTHONPATH=str(foreign), GIT_DIR=str(foreign / 'missing.git'),
            GIT_INDEX_FILE=str(foreign / 'wrong-index'), GIT_CONFIG_COUNT='1',
            GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true')
        controls = parent / 'controls'
        alpha_fixtures.create(controls)
        control_files = files(controls)
        assert len(control_files) == 9
        for name, digest in control_files.items():
            assert sha((ROOT / alpha_audit.REPORT / 'fixtures' / name).read_bytes()) == digest, name
        try:
            alpha_fixtures.create(controls)
        except ValueError:
            pass
        else:
            raise AssertionError('controls output overwrite accepted')
        assert files(controls) == control_files
        godot = os.environ['FARM_GODOT_BIN']
        native.append(run([godot, '--headless', '--editor', '--path', str(ROOT), '--quit'], foreign))
        for name in baseline['planned_assignments']:
            if name.endswith('.gd'):
                native.append(run([godot, '--headless', '--path', str(ROOT), '--check-only', '--script', 'res://' + name], foreign))
        native.append(run([godot, '--headless', '--path', str(ROOT), '--script', 'res://tools/slice_review.gd'], foreign))
        assert 'SLICE REVIEW: 440 passed, 0 failed' in native[-1]['stdout']
        output = parent / 'export'
        before = slice_audit.inputs(ROOT)
        old_cwd, old_environment = Path.cwd(), dict(os.environ)
        try:
            os.chdir(foreign)
            os.environ.update(env)
            slice_audit.export(ROOT, output)
        finally:
            os.chdir(old_cwd)
            os.environ.clear()
            os.environ.update(old_environment)
        assert slice_audit.inputs(ROOT) == before
        inventory = slice_audit.read(output / 'inventory.json')
        measurement = slice_audit.evaluate(output)
        assert slice_audit.check(ROOT, output, measurement) == []
        fingerprint = {key: {'signature': slice_audit.signature(frame, inventory['textures'][frame['image']]),
            'png_sha256': inventory['textures'][frame['image']]['png_sha256'],
            'rgba_sha256': inventory['textures'][frame['image']]['rgba_sha256']}
            for key, frame in inventory['frames'].items()}
        archived = gzip.compress((output / 'inventory.json').read_bytes(), mtime=0)
        with (REPORT / 'baseline/export-inventory.json.gz').open('xb') as file:
            file.write(archived)
        initial = files(output)
        native.append(run([godot, '--headless', '--path', str(ROOT), '--script', 'res://tools/slice_export.gd'], foreign,
            dict(env, VSLICE_OUTPUT=str(output), VSLICE_PROFILE='Codex-VPIPELINE-008-Refactor367'), expected=2))
        assert files(output) == initial
        for name in ['alpha_capture', 'slice_capture', 'slice_legacy_capture']:
            absent = parent / (name + '-headless-must-not-create')
            child_env = dict(env, VALPHA_OUTPUT=str(absent), VALPHA_FIXTURES=str(controls),
                VALPHA_PROFILE='Codex-VPIPELINE-007-Refactor367', VSLICE_OUTPUT=str(absent),
                VSLICE_PROFILE='Codex-VPIPELINE-008-Refactor367')
            native.append(run([godot, '--headless', '--path', str(ROOT), '--script', 'res://tools/' + name + '.gd'],
                              foreign, child_env, expected=2))
            assert not absent.exists()
        commands.append(run([sys.executable, str(ROOT / 'tools/run.py'), 'alpha_audit'], foreign, env))
        commands.append(run([sys.executable, str(ROOT / 'tools/run.py'), 'slice_audit', '--folder', str(output)], foreign, env))
        commands.append(run([sys.executable, str(ROOT / 'tools/run.py'), 'alpha_audit', '--init-baseline'], foreign, env, expected=1))
        assert 'initial baseline requires its exact starting commit' in commands[-1]['stderr']
        commands.append(run([sys.executable, str(ROOT / 'tools/run.py'), 'slice_audit', '--record', '--folder', str(output)], foreign, env, expected=1))
        assert 'initial slice snapshot requires exact base commit' in commands[-1]['stderr']
        for module in ['assets.alpha.test_processing_history', 'test_alpha_audit', 'test_alpha_proof', 'test_slice_audit', 'test_slice_proof']:
            commands.append(run([sys.executable, str(ROOT / 'tools/run.py'), module], foreign, env))
        assert not (foreign / 'wrong-index').exists()
        frame_result = {'inputs_sha256': before, 'exporter_sha256': inventory['source_sha256'],
            'inventory_sha256': sha((output / 'inventory.json').read_bytes()), 'frames': fingerprint,
            'summary': measurement['summary'], 'measurement_errors': measurement['errors'],
            'actual_export_log': (output / 'export.log').read_text()}
    result = {'base': baseline['base'], 'version': (ROOT / 'VERSION').read_text().strip(),
        'physical_moves': 0, 'root_sources': 420, 'fixed_sources_SHA256': {n: v['sha256'] for n, v in fixed.items()},
        'Git_call_sites_AST': git_sites, 'actual_foreign_CLI': commands,
        'actual_control_files_equal_original': control_files, 'native': native,
        'actual_export_before_move': frame_result, 'temporary_projects_removed': True,
        'actual_Git_calls_in_default_and_record_refusal': 4,
        'later_record_branches_executed': False, 'native_game_frame_accepted': False, 'GPU_FPS_admission': False}
    with args.output.open('x') as file:
        file.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'native_commands': len(native), 'foreign_CLI': len(commands),
        'before_frames': len(fingerprint), 'controls': len(control_files), 'Git_sites': len(git_sites)}))


if __name__ == '__main__':
    main()
