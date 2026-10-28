"""Сравнивает настоящие old/new producer и исполняет legacy URI в свежем внешнем Godot-проекте."""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment
from tools.assets.migration import migration_fixture as fixture

PHASES = ('baseline', 'dual', 'unadapted', 'retired', 'rollback')
PREPARED = '6af72b44ddd62109ba4765638b79ab86736d5eae'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def files(root):
    return {p.relative_to(root).as_posix(): sha(p.read_bytes()) for p in root.rglob('*') if p.is_file()}


def run(arguments, cwd, env=None, expected=0, timeout=240):
    result = subprocess.run(arguments, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
    row = {'command': list(map(str, arguments)), 'exit': result.returncode,
           'stdout': result.stdout, 'stderr': result.stderr}
    assert result.returncode == expected, row
    if expected == 0:
        assert not any(marker in result.stdout + result.stderr for marker in
                       ['SCRIPT ERROR', 'Parse Error', '\nERROR:']), row
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists() or args.output.suffix != '.json' or not args.output.parent.is_dir():
        parser.error('new JSON with an existing parent required')
    old_raw = subprocess.check_output(['git', '-C', str(ROOT), 'show',
        PREPARED + ':tools/migration_fixture.py'], env=git_environment())
    before, after = ast.parse(old_raw), ast.parse(Path(fixture.__file__).read_bytes())
    old_functions = {n.name: n for n in before.body if isinstance(n, ast.FunctionDef)}
    new_functions = {n.name: n for n in after.body if isinstance(n, ast.FunctionDef)}
    assert set(old_functions) == set(new_functions) == {'closure', 'create', 'phase'}
    assert all(ast.dump(old_functions[n]) == ast.dump(new_functions[n]) for n in old_functions)
    namespace = dict(vars(fixture))
    exec(compile(ast.Module(body=[old_functions['create']], type_ignores=[]),
                 '<exact create AST from ' + PREPARED + '>', 'exec'), namespace)
    godot = os.environ['FARM_GODOT_BIN']
    cli = []
    captures, native = {}, []
    with tempfile.TemporaryDirectory(prefix='refactor366 real producer ') as directory:
        parent = Path(directory).resolve()
        old, current, foreign = parent / 'old', parent / 'current', parent / 'foreign cwd'
        foreign.mkdir()
        old_case = namespace['create'](ROOT, old)
        current_case = fixture.create(ROOT, current)
        assert old_case == current_case and files(old) == files(current)
        producer_files = files(current)
        probe = current / 'tools/migration_capture.gd'
        assert probe.read_bytes() == Path(fixture.__file__).with_name('migration_capture.gd').read_bytes()
        assert not (current / 'tools/assets').exists()
        original_project = (current / 'project.godot').read_bytes()
        # Только QA-логирование временного проекта: producer и его исходный project не меняются.
        (current / 'project.godot').write_bytes(original_project + b'\n[debug]\nfile_logging/enable_file_logging=false\n')
        draft_sha, probe_sha = sha((current / 'saved-draft.json').read_bytes()), sha(probe.read_bytes())
        profile = 'Codex-VPIPELINE-009-Refactor366-' + uuid.uuid4().hex[:12]
        old_uids, new_uids = None, None
        for phase in PHASES:
            fixture.phase(current, phase)
            native.append(run([godot, '--headless', '--editor', '--path', str(current), '--quit'], foreign))
            if phase == 'baseline':
                native.append(run([godot, '--headless', '--path', str(current), '--check-only',
                    '--script', 'res://tools/migration_capture.gd'], foreign))
            output = parent / 'captures' / phase
            env = dict(os.environ, VMIGRATION_OUTPUT=str(output), VMIGRATION_PROFILE=profile)
            native.append(run([godot, '--headless', '--path', str(current), '--script',
                'res://tools/migration_capture.gd'], foreign, env))
            capture = json.loads((output / 'capture.json').read_text())
            assert capture['phase'] == phase and capture['errors'] == []
            assert capture['source_sha256'] == probe_sha and capture['draft_sha256'] == draft_sha
            assert capture['display_server'] == 'headless' and capture['frames'] == {}
            assert capture['performance_eligible'] is False
            assert capture['missing_old_paths'] == (3 if phase == 'retired' else 0)
            assert capture['unadapted_old_paths'] == (3 if phase == 'unadapted' else 0)
            assert capture['document']['validation']['valid'] == (phase != 'retired')
            assert [r['side'] for r in capture['rows']] == fixture.SIDES
            uids = [r['uid'] for r in capture['rows']]
            assert len(set(uids)) == 3 and all(u.startswith('uid://') for u in uids)
            if phase == 'baseline':
                old_uids = uids
            elif phase == 'dual':
                new_uids = uids
                assert not set(old_uids).intersection(new_uids)
            else:
                assert uids == (old_uids if phase == 'rollback' else new_uids)
            for row in capture['rows']:
                side = row['side']
                assert row['old_path'] == current_case['paths'][side]
                assert row['old_exists'] == (phase != 'retired')
                assert row['png_sha256'] == producer_files[current_case['paths'][side].removeprefix('res://')]
            captures[phase] = capture
        existing = parent / 'captures/rollback'
        expected = files(existing)
        command = [godot, '--headless', '--path', str(current), '--script', 'res://tools/migration_capture.gd']
        native.append(run(command, foreign, dict(os.environ, VMIGRATION_OUTPUT=str(existing),
                                                VMIGRATION_PROFILE=profile), expected=2))
        assert files(existing) == expected
        absent = parent / 'must-not-create'
        native.append(run(command, foreign, dict(os.environ, VMIGRATION_OUTPUT=str(absent),
                                                VMIGRATION_PROFILE=''), expected=2))
        assert not absent.exists()
        (current / 'project.godot').write_bytes(original_project)
        assert sha((current / 'saved-draft.json').read_bytes()) == draft_sha
        assert sha(probe.read_bytes()) == probe_sha
        assert (current / 'project.godot').read_bytes() == (old / 'project.godot').read_bytes()
        hostile = dict(os.environ, PYTHONPATH=str(foreign), GIT_DIR=str(foreign / 'missing.git'),
            GIT_INDEX_FILE=str(foreign / 'wrong-index'), GIT_CONFIG_COUNT='1',
            GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true')
        for module in ['assets.migration.test_migration_fixture', 'assets.migration.test_migration_proof',
                       'assets.migration.test_asset_migration']:
            cli.append(run([sys.executable, str(ROOT / 'tools/run.py'), module], foreign, hostile))
        assert not (foreign / 'wrong-index').exists()
    result = {'version': (ROOT / 'VERSION').read_text().strip(),
        'prepared_commit': PREPARED, 'prepared_source_sha256': sha(old_raw),
        'source_sha256': sha(Path(fixture.__file__).read_bytes()), 'exact_function_AST_equal': sorted(old_functions),
        'old_exact_create_AST_with_actual_unchanged_closure_Git_copy': True,
        'producer_files_equal': producer_files, 'producer_file_count': len(producer_files),
        'native': native, 'headless_actual_capture_phases': captures,
        'actual_foreign_CLI': cli, 'QA_only_debug_logging_disabled': True, 'producer_project_restored': True,
        'temporary_projects_removed': True, 'native_game_frame_accepted': False, 'GPU_FPS_admission': False}
    with args.output.open('x') as file:
        file.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'functions': 3, 'real_old_new_file_count': len(producer_files),
        'headless_phases': len(captures), 'negative_capture_controls': 2, 'foreign_CLI': len(cli)}))


if __name__ == '__main__':
    main()
