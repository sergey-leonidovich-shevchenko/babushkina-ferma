"""Сравнивает настоящий after-export с5603 before-signatures367 и проверяет публичные producer."""
from __future__ import annotations
import ast
import gzip
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.assets.alpha import alpha_audit, alpha_fixtures
from tools.assets.slicing import slice_audit
from tools.common.git import git_environment


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def files(root):
    return {p.relative_to(root).as_posix(): sha(p.read_bytes()) for p in root.rglob('*') if p.is_file()}


def run(command, cwd, env=None, expected=0, timeout=360):
    result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
    row = {'command': list(map(str, command)), 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
    assert result.returncode == expected, row
    if expected == 0:
        assert not any(m in result.stdout + result.stderr for m in ['SCRIPT ERROR', 'Parse Error', '\nERROR:']), row
    return row


def fingerprint(inventory):
    return {key: {'signature': slice_audit.signature(frame, inventory['textures'][frame['image']]),
        'png_sha256': inventory['textures'][frame['image']]['png_sha256'],
        'rgba_sha256': inventory['textures'][frame['image']]['rgba_sha256']}
        for key, frame in inventory['frames'].items()}


def source_comparison(baseline, mapping):
    imports = runpy.run_path(str(REPORT.parent / 'assets-build-move/move.py'), run_name='accepted_import_helper')['python_imports']
    result = {'Python_AST': [], 'GD_exact_URI_and_metadata_only': [], 'JSON_and_metrics_byte_exact': []}
    for old, target in mapping.items():
        original = gzip.decompress((REPORT / 'baseline' / (old.replace('/', '--') + '.gz')).read_bytes())
        current = (ROOT / target).read_bytes()
        if old.endswith('.gd'):
            expected = original.decode()
            for before, after in mapping.items():
                expected = expected.replace('"res://' + before + '"', '"res://' + after + '"')
            if old == 'tools/slice_export.gd':
                expected = expected.replace('"performance_eligible":false,"export_seconds"',
                    '"performance_eligible":false,"tool_source_paths":'+json.dumps(slice_audit.PACKAGED_EXPORTERS,separators=(',',':'))+',"export_seconds"')
            assert current == expected.encode(), old
            result['GD_exact_URI_and_metadata_only'].append(old)
        elif old.endswith('.json') or old.endswith('_metrics.py'):
            assert original == current, old
            result['JSON_and_metrics_byte_exact'].append(old)
        elif old.endswith('.py') and not Path(old).name.startswith('test_'):
            expected = imports(original.decode(), mapping)
            if old in {'tools/alpha_audit.py', 'tools/slice_audit.py'}:
                expected = expected.replace('from tools.common.launch import prepare_imports\n', '').replace('prepare_imports(project_root(__file__))\n', '')
            if old == 'tools/slice_audit.py':
                expected = expected.replace('before=inputs(root)', 'before=inputs(root, source_paths=PACKAGED_EXPORTERS)')
                expected = expected.replace("'res://tools/slice_export.gd'", "'res://tools/assets/slicing/slice_export.gd'")
                expected = expected.replace('if before!=inputs(root):', 'if before!=inputs(root, source_paths=PACKAGED_EXPORTERS):')
                expected = expected.replace("inventory=read(destination/'inventory.json');inventory['inputs_sha256']=before",
                    "inventory=read(destination/'inventory.json')\n    if inventory.get('tool_source_paths')!=PACKAGED_EXPORTERS:raise ValueError('slice exporter paths differ')\n    inventory['inputs_sha256']=before")
            assert ast.dump(ast.parse(expected)) == ast.dump(ast.parse(current)), old
            result['Python_AST'].append(old)
    return result


def main():
    output = REPORT / 'profile.json'
    assert not output.exists()
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    mapping = {n: r['target'] for n, r in baseline['assignments'].items()}
    comparison = source_comparison(baseline, mapping)
    before = json.loads((REPORT.parent / 'alpha-slicing-prepare/profile.json').read_text())
    for row in baseline['local_UID']:
        assert not (ROOT / row['old_path']).exists()
        assert sha((ROOT / row['target']).read_bytes()) == row['sha256']
    native, commands = [], []
    with tempfile.TemporaryDirectory(prefix='alpha slicing after move ') as directory:
        parent = Path(directory).resolve()
        foreign = parent / 'foreign cwd'; foreign.mkdir()
        env = dict(os.environ, PYTHONPATH=str(foreign), GIT_DIR=str(foreign / 'missing.git'),
            GIT_INDEX_FILE=str(foreign / 'wrong-index'), GIT_CONFIG_COUNT='1',
            GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true')
        controls = parent / 'controls'; alpha_fixtures.create(controls)
        control_files = files(controls)
        assert control_files == before['actual_control_files_equal_original']
        try: alpha_fixtures.create(controls)
        except ValueError: pass
        else: raise AssertionError('controls overwrite accepted')
        assert files(controls) == control_files
        godot = os.environ['FARM_GODOT_BIN']
        native.append(run([godot, '--headless', '--editor', '--path', str(ROOT), '--quit'], foreign))
        for target in mapping.values():
            if target.endswith('.gd'):
                native.append(run([godot, '--headless', '--path', str(ROOT), '--check-only', '--script', 'res://' + target], foreign))
        native.append(run([godot, '--headless', '--path', str(ROOT), '--script', 'res://tools/assets/slicing/slice_review.gd'], foreign))
        assert 'SLICE REVIEW: 440 passed, 0 failed' in native[-1]['stdout']
        exported = parent / 'export'
        cwd, environment = Path.cwd(), dict(os.environ)
        try:
            os.chdir(foreign); os.environ.update(env); slice_audit.export(ROOT, exported)
        finally:
            os.chdir(cwd); os.environ.clear(); os.environ.update(environment)
        inventory = slice_audit.read(exported / 'inventory.json')
        actual = fingerprint(inventory)
        assert actual == before['actual_export_before_move']['frames'] and len(actual) == 5603
        assert inventory['tool_source_paths'] == slice_audit.PACKAGED_EXPORTERS
        measurement = slice_audit.evaluate(exported)
        assert slice_audit.check(ROOT, exported, measurement) == []
        with (REPORT / 'after-inventory-02.json.gz').open('xb') as file:
            file.write(gzip.compress((exported / 'inventory.json').read_bytes(), mtime=0))
        stable = files(exported)
        native.append(run([godot, '--headless', '--path', str(ROOT), '--script', 'res://tools/assets/slicing/slice_export.gd'], foreign,
            dict(env, VSLICE_OUTPUT=str(exported), VSLICE_PROFILE='Codex-VPIPELINE-008-Refactor368'), expected=2))
        assert files(exported) == stable
        for name in ['alpha_capture', 'slice_capture', 'slice_legacy_capture']:
            absent = parent / (name + '-headless-must-not-create')
            child_env = dict(env, VALPHA_OUTPUT=str(absent), VALPHA_FIXTURES=str(controls), VALPHA_PROFILE='Codex-VPIPELINE-007-Refactor368',
                VSLICE_OUTPUT=str(absent), VSLICE_PROFILE='Codex-VPIPELINE-008-Refactor368')
            old = 'tools/' + name + '.gd'
            native.append(run([godot, '--headless', '--path', str(ROOT), '--script', 'res://' + mapping[old]], foreign, child_env, expected=2))
            assert not absent.exists()
        launcher = [sys.executable, str(ROOT / 'tools/run.py')]
        for module, options, expected in [
            ('assets.alpha.alpha_audit', [], 0), ('assets.slicing.slice_audit', ['--folder', str(exported)], 0),
            ('assets.alpha.alpha_audit', ['--init-baseline'], 1),
            ('assets.slicing.slice_audit', ['--record', '--folder', str(exported)], 1)]:
            commands.append(run(launcher + [module] + options, foreign, env, expected=expected))
        assert 'initial baseline requires its exact starting commit' in commands[2]['stderr']
        assert 'initial slice snapshot requires exact base commit' in commands[3]['stderr']
        report = parent / 'public report'
        commands.append(run(launcher + ['assets.slicing.slice_audit', '--report', str(report)], foreign, env))
        assert set(files(report)) == {'inventory.json', 'measurements.json', 'export.log'}
        assert fingerprint(slice_audit.read(report / 'inventory.json')) == actual
        saved = files(report)
        commands.append(run(launcher + ['assets.slicing.slice_audit', '--report', str(report)], foreign, env, expected=1))
        assert 'report requires a new directory outside assets' in commands[-1]['stderr'] and files(report) == saved
        commands.append(run([sys.executable, str(ROOT / 'tools/village_street_verify.py')], foreign, env))
        for module in ['assets.alpha.test_processing_history', 'assets.alpha.test_alpha_audit', 'assets.alpha.test_alpha_proof',
                       'assets.slicing.test_slice_audit', 'assets.slicing.test_slice_proof', 'assets.contracts.test_source_paths', 'assets.alpha.test_street_consumer']:
            commands.append(run(launcher + [module], foreign, env))
        assert not (foreign / 'wrong-index').exists()
        frame_result = {'inputs_sha256': inventory['inputs_sha256'], 'exporter_sha256': inventory['source_sha256'],
            'inventory_sha256': sha((exported / 'inventory.json').read_bytes()), 'frames': actual,
            'summary': measurement['summary'], 'measurement_errors': measurement['errors'], 'actual_export_log': (exported / 'export.log').read_text()}
    result = {'base': baseline['base'], 'version': (ROOT / 'VERSION').read_text().strip(), 'physical_source_moves': 17,
        'JSON_moves': 2, 'ignored_UID_moves': 6, 'root_sources': 403, 'source_comparison': comparison,
        'actual_before_reference': 'alpha-slicing-prepare/profile.json', 'all5603_frame_signatures_and_RGBA_PNG_equal_before': True,
        'actual_after_export': frame_result, 'after_inventory_file': 'after-inventory-02.json.gz', 'actual_control_files_equal_before': control_files,
        'native': native, 'actual_foreign_CLI': commands, 'public_report_and_repeat_refusal_passed': True,
        'temporary_projects_removed': True, 'native_game_frame_accepted': False, 'GPU_FPS_admission': False}
    with output.open('x') as stream: stream.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'native': len(native), 'foreign_CLI': len(commands), 'frames_equal': len(actual), 'controls_equal': len(control_files)}))


if __name__ == '__main__':
    main()
