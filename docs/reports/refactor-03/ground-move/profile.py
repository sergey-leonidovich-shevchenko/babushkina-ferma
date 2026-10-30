"""Compare real legacy/canonical Ground CLI and parse42 moved GD plus13 actual suite consumers."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-move'
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
p = argparse.ArgumentParser()
p.add_argument('phase', choices=['before', 'after'])
p.add_argument('--attempt', default='01')
p.add_argument('--resume-cli', action='store_true')
args = p.parse_args()
phase = args.phase
prefix = phase if args.attempt == '01' else phase + '-attempt' + args.attempt
assert not (R / (prefix + '-profile.json')).exists()
plan = json.loads((R / 'baseline/move-plan.json').read_text())
mapping = {r['old_path']: r['target'] for r in plan['moves']}
families = ['axial_road', 'decoration', 'garden', 'ground_edge', 'ground_seasons',
    'meadow', 'plaza', 'road_network', 'terrain_revision']
commands = [('ground_layers', ['verify'])] + [(n + '_verify', []) for n in families]
negatives = ['test_ground_layers', 'test_axial_road', 'test_decoration_rules', 'test_garden_soil',
    'test_ground_edge', 'test_ground_seasons', 'test_meadow_ground', 'test_plaza_ground',
    'test_road_network', 'test_terrain_revision']
commands += [(n, []) for n in negatives]
commands += [('qa.ground.test_ground_context', []), ('qa.performance.test_surface_producers', [])]
assert len(commands) == 22
records = []
if args.resume_cli:
    assert phase == 'before'
    records = json.loads((R / 'before-CLI.json').read_text())
    assert len(records) == 22
    for row in records:
        assert row['exit'] == 0 and hashlib.sha256((R / row['log']).read_bytes()).hexdigest() == row['SHA256']
    (R / (prefix + '-CLI.json')).write_text(json.dumps(records, indent=2) + '\n')
with tempfile.TemporaryDirectory(prefix='Ground ' + phase + ' foreign ') as directory:
    foreign = Path(directory).resolve()
    (foreign / 'note.txt').write_text('unrelated Ground profile repository\n')
    subprocess.run(['git', 'init', '-q', str(foreign)], env=git_environment(), check=True)
    subprocess.run(['git', '-C', str(foreign), 'add', '.'], env=git_environment(), check=True)
    stable = {n: (foreign / '.git' / n).read_bytes() for n in ['index', 'config']}
    environment = dict(git_environment(), PYTHONDONTWRITEBYTECODE='1', PYTHONPATH=str(foreign),
        GIT_DIR=str(foreign / '.git'), GIT_WORK_TREE=str(foreign), GIT_INDEX_FILE=str(foreign / '.git/index'),
        GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true')
    for name, tail in ([] if args.resume_cli else commands):
        if '.' in name:
            argv = [sys.executable, str(Q / 'tools/run.py'), name, *tail]
        elif phase == 'after':
            argv = [sys.executable, str(Q / 'tools/run.py'), 'qa.ground.' + name, *tail]
        else:
            argv = [sys.executable, str(Q / 'tools' / (name + '.py')), *tail]
        log = prefix + '-CLI-%02d.txt' % (len(records) + 1)
        with (R / log).open('x') as stream:
            result = subprocess.run(argv, cwd=foreign, env=environment, stdout=stream,
                stderr=subprocess.STDOUT, timeout=600)
        raw = (R / log).read_bytes()
        text = raw.decode()
        row = {'logical': name, 'argv': argv, 'cwd': str(foreign), 'exit': result.returncode,
            'log': log, 'SHA256': hashlib.sha256(raw).hexdigest(),
            'unit_cases': [int(n) for n in re.findall(r'^Ran (\d+) tests? in ', text, re.M)]}
        records.append(row)
        (R / (prefix + '-CLI.json')).write_text(json.dumps(records, indent=2) + '\n')
        assert result.returncode == 0, (name, text[-3000:])
        assert not any(token in text for token in ['SCRIPT ERROR', 'Parse Error', '\nERROR:']), name
        print(json.dumps({'phase': phase, 'CLI': len(records), 'name': name, 'exit': 0}), flush=True)
    assert all((foreign / '.git' / n).read_bytes() == raw for n, raw in stable.items())

census = json.loads((R / 'baseline/census.json').read_text())
gd_names = sorted(n for n in mapping if n.endswith('.gd'))
gd_names += sorted(r['path'] for r in census['GD_consumers'] if r['path'] not in mapping)
assert len(gd_names) == 55 and len(set(gd_names)) == 55
godot = str(Path(os.environ['FARM_GODOT_BIN']).resolve(strict=True))
gd = []
for name in gd_names:
    physical = mapping.get(name, name) if phase == 'after' else name
    engine = R / (prefix + '-GD-%02d.engine.txt' % (len(gd) + 1))
    argv = [godot, '--headless', '--path', str(Q), '--log-file', str(engine), '--check-only', '--script', 'res://' + physical]
    result = subprocess.run(argv, cwd=Q, env=dict(git_environment(), PYTHONDONTWRITEBYTECODE='1'),
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    raw = result.stdout
    log = prefix + '-GD-%02d.txt.gz' % (len(gd) + 1)
    stored = gzip.compress(raw, mtime=0)
    (R / log).write_bytes(stored)
    row = {'logical': name, 'physical': physical, 'argv': argv, 'exit': result.returncode,
        'log': log, 'storage': 'gzip', 'raw_SHA256': hashlib.sha256(raw).hexdigest(),
        'stored_SHA256': hashlib.sha256(stored).hexdigest(),
        'source_SHA256': hashlib.sha256((Q / physical).read_bytes()).hexdigest()}
    if engine.exists():
        engine_raw = engine.read_bytes()
        engine_stored = gzip.compress(engine_raw, mtime=0)
        engine_gz = engine.with_suffix(engine.suffix + '.gz')
        engine_gz.write_bytes(engine_stored)
        engine.unlink()
        row.update(engine_log=engine_gz.name, engine_raw_SHA256=hashlib.sha256(engine_raw).hexdigest(),
            engine_stored_SHA256=hashlib.sha256(engine_stored).hexdigest())
    gd.append(row)
    (R / (prefix + '-GD.json')).write_text(json.dumps(gd, indent=2) + '\n')
    assert result.returncode == 0 and not any(t in raw.decode() for t in ['SCRIPT ERROR', 'Parse Error', 'ERROR:']), row
    print(json.dumps({'phase': phase, 'GD': len(gd), 'exit': 0}), flush=True)
profile = {'phase': phase, 'base': plan['base'], 'commands': records, 'GD': gd,
    'foreign_cwd': True, 'foreign_Git_config_index': True, 'foreign_bytes_preserved': True,
    'historical_readers': 10, 'old_negative_suites': 10, 'existing_context_and_producer_suites': 2,
    'unit_cases': sum(sum(r['unit_cases']) for r in records), 'native_frames': 0, 'FPS_admission': False,
    'CLI_reused_after_GD_log_ownership_failure': args.resume_cli}
if phase == 'after':
    before = json.loads((R / 'before-profile.json').read_text())
    assert len(before['commands']) == len(records) == 22
    for a, b in zip(before['commands'], records):
        assert a['logical'] == b['logical'] and a['exit'] == b['exit'] == 0
        assert a['unit_cases'] == b['unit_cases'], b['logical']
        if not b['unit_cases']:
            assert (R / a['log']).read_bytes() == (R / b['log']).read_bytes(), b['logical']
    profile['historical_stdout_byte_equal'] = 10
    profile['GD_logical_coverage_equal'] = [r['logical'] for r in before['GD']] == gd_names
(R / (prefix + '-profile.json')).write_text(json.dumps(profile, indent=2) + '\n')
print(json.dumps({'phase': phase, 'CLI': len(records), 'GD': len(gd), 'unit_cases': profile['unit_cases']}))
