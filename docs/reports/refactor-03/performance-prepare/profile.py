"""Compare real performance tools before/after source-root/Git preparation."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

REPORT = Path(__file__).resolve().parent
ROOT = next(parent for parent in REPORT.parents if (parent / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def json_copy(source, destination):
    """Copy only immutable JSON inputs; every generated summary lives in the temporary copy."""
    signatures = {}
    for path in sorted(source.rglob('*.json')):
        if path.name == 'summary.json':
            continue
        relative = path.relative_to(source)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        signatures[str(relative)] = digest(path.read_bytes())
    return signatures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=['before', 'after'])
    parser.add_argument('--attempt', type=int, default=1)
    arguments = parser.parse_args()
    phase = arguments.phase
    prefix = phase if arguments.attempt == 1 else phase + '-attempt%02d' % arguments.attempt
    result_path = REPORT / (phase + '-profile.json')
    assert not result_path.exists()
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    commands = []

    def run(arguments, cwd, environment, expected=0, timeout=360):
        """Keep exact stdout/stderr in a fresh log; expected refusal never becomes exit0."""
        name = prefix + '-%02d.txt' % (len(commands) + 1)
        with (REPORT / name).open('x') as stream:
            process = subprocess.run(arguments, cwd=cwd, env=environment, stdout=stream,
                stderr=subprocess.STDOUT, timeout=timeout)
        row = {'command': list(map(str, arguments)), 'cwd': str(cwd), 'expected': expected,
            'exit': process.returncode, 'log': name, 'sha256': digest((REPORT / name).read_bytes())}
        commands.append(row)
        (REPORT / (prefix + '-commands.json')).write_text(json.dumps(commands, indent=2) + '\n')
        output = (REPORT / name).read_text()
        assert process.returncode == expected, row
        if expected == 0:
            assert not any(marker in output for marker in ['SCRIPT ERROR', 'Parse Error', '\nERROR:']), output
        print(json.dumps({'phase': phase, 'command': len(commands), 'exit': process.returncode}), flush=True)
        return output

    with tempfile.TemporaryDirectory(prefix='performance preparation ' + phase + ' ') as directory:
        parent = Path(directory).resolve()
        foreign = parent / 'foreign cwd'
        foreign.mkdir()
        home = parent / 'isolated home'
        home.mkdir()
        clean = dict(git_environment(), PYTHONPATH=str(foreign), FARM_MIN_FPS='50',
            HOME=str(home), XDG_DATA_HOME=str(home / 'data'))
        environment = dict(clean)
        if phase == 'after':
            environment.update(GIT_DIR=str(foreign / 'absent.git'), GIT_WORK_TREE=str(foreign),
                GIT_INDEX_FILE=str(foreign / 'foreign-index'), GIT_CONFIG_COUNT='1',
                GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true')
        inputs, outputs = {}, {}
        for short, script, original in [
            ('optimization', 'analyze_optimization_audit.py', 'optimization-audit-2026-10-14'),
            ('storage', 'analyze_storage_perf.py', 'storage-perf-2026-10-14'),
        ]:
            folder = parent / short
            folder.mkdir()
            inputs[short] = json_copy(ROOT / 'docs/reports' / original, folder)
            run([sys.executable, str(ROOT / 'tools' / script), '--folder', str(folder)], foreign, environment)
            raw = (folder / 'summary.json').read_bytes()
            outputs[short] = json.loads(raw)
            (REPORT / (prefix + '-' + short + '.json.gz')).write_bytes(gzip.compress(raw, mtime=0))

        assets = parent / 'asset-graph.json'
        run([sys.executable, str(ROOT / 'tools/optimization_asset_audit.py'), '--output', str(assets)],
            foreign, environment)
        outputs['asset_graph'] = json.loads(assets.read_text())
        (REPORT / (prefix + '-asset-graph.json.gz')).write_bytes(gzip.compress(assets.read_bytes(), mtime=0))

        control_folder = ROOT / 'docs/reports/visual-overhaul/vperf-001/controls'
        for name, options in [('contract', []), ('controls', ['--controls', '--output', str(control_folder)])]:
            text = run([sys.executable, str(ROOT / 'tools/perf_contract.py'), *options], foreign, environment)
            outputs[name] = json.loads(text)
            (REPORT / (prefix + '-' + name + '.json.gz')).write_bytes(gzip.compress(text.encode(), mtime=0))

        outputs['gate_help'] = run([sys.executable, str(ROOT / 'tools/performance_gate.py'), '--help'],
            foreign, environment)
        outputs['collector_help'] = run([sys.executable, str(ROOT / 'tools/perf_contract_collect.py'), '--help'],
            foreign, environment)
        previous = parent / 'existing output'
        previous.mkdir()
        sentinel = previous / 'keep.txt'
        sentinel.write_text('pre-existing evidence must not change')
        stable = sentinel.read_bytes()
        for script, expected_message in [
            ('performance_gate.py', 'new output directory required'),
            ('perf_contract_collect.py', 'fresh collection output required'),
        ]:
            text = run([sys.executable, str(ROOT / 'tools' / script), '--output', str(previous)],
                foreign, environment, expected=1)
            assert expected_message in text and list(previous.iterdir()) == [sentinel]
            assert sentinel.read_bytes() == stable

        crash = parent / 'crash-boundaries.json'
        run([sys.executable, str(ROOT / 'tools/audit_save_crashes.py'), '--godot',
            os.environ['FARM_GODOT_BIN'], '--output', str(crash)], foreign, environment, timeout=600)
        outputs['actual_headless_crash_workers'] = json.loads(crash.read_text())
        assert len(outputs['actual_headless_crash_workers']['cases']) == 14
        assert all(case['exit_code'] == -9 for case in outputs['actual_headless_crash_workers']['cases'])
        (REPORT / (prefix + '-crash-boundaries.json')).write_bytes(crash.read_bytes())

        # Old shell requires its own cwd. After preparation the same public shell must ignore foreign Git/cwd.
        shell_cwd = ROOT if phase == 'before' else foreign
        outputs['actual_headless_smoke'] = run(['zsh', str(ROOT / 'tools/smoke_test.sh')],
            shell_cwd, environment, timeout=360)
        assert '180' in outputs['actual_headless_smoke']
        outputs['shell_gate_help'] = run(['zsh', str(ROOT / 'tools/performance_gate.sh'), '--help'],
            shell_cwd, environment)

        if phase == 'after':
            for command in ['qa.performance.test_performance_context', 'test_optimization_audit',
                'test_storage_perf', 'test_performance_gate', 'test_perf_contract', 'test_redraw_output']:
                run([sys.executable, str(ROOT / 'tools/run.py'), command], foreign, environment)

        assert not (foreign / 'foreign-index').exists()
        before = None
        if phase == 'after':
            before = json.loads((REPORT / 'before-profile.json').read_text())
            assert before['input_json_SHA256'] == inputs
            assert before['outputs'] == outputs
            raw_test = (ROOT / 'tools/qa/performance/test_performance_context.py').read_bytes()
            assert digest(raw_test) == digest((REPORT / 'baseline/performance-context-test.py').read_bytes())
        result = {'phase': phase, 'attempt': arguments.attempt, 'base': baseline['base'], 'commands': commands,
            'input_json_SHA256': inputs, 'outputs': outputs,
            'actual_before_after_equal': phase == 'after',
            'old_shell_cwd': 'own source checkout' if phase == 'before' else 'foreign cwd/Git overrides',
            'new_GPU_FPS_admission': False, 'window_opened': False,
            'native_claim': '14 actual isolated SIGKILL workers + headless main smoke180; old native FPS data audited offline only'}
        result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({'phase': phase, 'commands': len(commands), 'actual_crash_workers': 14,
            'actual_smoke_frames': 180, 'equal_before': phase == 'after'}), flush=True)


if __name__ == '__main__':
    main()
