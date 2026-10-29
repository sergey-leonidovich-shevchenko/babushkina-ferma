"""Replay actual World/plant-depth CLI, compile44 moved GD plus2 consumers, and compare owned Water outputs."""
import argparse
from contextlib import redirect_stdout
import hashlib
import importlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from unittest.mock import patch

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT = ROOT / 'docs/reports/refactor-03/world-core-move'
sys.path[:0] = [str(ROOT), str(ROOT / 'tools')]
from tools.common.git import git_environment

parser = argparse.ArgumentParser()
parser.add_argument('phase', choices=['before', 'after'])
parser.add_argument('--attempt', default='01')
args = parser.parse_args()
phase = args.phase
prefix = phase if args.attempt == '01' else phase + '-attempt' + args.attempt
assert not (REPORT / (phase + '-profile.json')).exists()
plan = json.loads((REPORT / 'baseline/move-plan.json').read_text())
mapping = {row['old_path']: row['target'] for row in plan['moves']}
readers = ['render_order', 'object_command_verify', 'village_bench_verify', 'village_street_verify',
           'village_board_verify', 'village_trade_verify', 'pilot_static_audit', 'pilot_static_verify',
           'pilot_pass_verify', 'post_motion_verify', 'transient_save_verify', 'shadow_inventory_verify',
           'village_fence_verify', 'village_lamp_verify', 'shore_kit', 'plant_depth_verify']
assets = ['village_' + name + '_assets' for name in ['bench', 'board', 'fence', 'lamp', 'street', 'trade']]
negatives = ['test_' + name for name in ['render_order', 'object_command', 'village_bench', 'village_street',
             'village_board', 'village_trade', 'pilot_static', 'pilot_pass', 'post_motion', 'transient_save',
             'shadow_inventory', 'village_fence', 'village_lamp', 'shore_kit', 'water_audit', 'plant_depth']]
rows = []
with tempfile.TemporaryDirectory(prefix='world core ' + phase + ' foreign ') as directory:
    foreign = Path(directory).resolve()
    (foreign / 'note.txt').write_text('foreign World core profile\n')
    subprocess.run(['git', 'init', '-q', str(foreign)], env=git_environment(), check=True)
    subprocess.run(['git', '-C', str(foreign), 'add', '.'], env=git_environment(), check=True)
    state = {name: (foreign / '.git' / name).read_bytes() for name in ['index', 'config']}
    environment = dict(git_environment(), PYTHONDONTWRITEBYTECODE='1', PYTHONPATH=str(foreign))
    if phase == 'after':
        environment.update(GIT_DIR=str(foreign / '.git'), GIT_WORK_TREE=str(foreign),
            GIT_INDEX_FILE=str(foreign / '.git/index'), GIT_CONFIG_COUNT='1',
            GIT_CONFIG_KEY_0='core.bare', GIT_CONFIG_VALUE_0='true')
    for name in readers + assets + negatives:
        logical = 'tools/' + name + '.py'
        argv = [sys.executable, str(ROOT / logical)]
        if phase == 'after' and logical in mapping:
            argv = [sys.executable, str(ROOT / 'tools/run.py'), 'qa.world.' + name]
        log = prefix + '-%02d.txt' % (len(rows) + 1)
        with (REPORT / log).open('x') as stream:
            result = subprocess.run(argv, cwd=foreign, env=environment, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=600)
        output = (REPORT / log).read_text()
        row = {'logical_command': name, 'command': argv, 'cwd': str(foreign), 'exit': result.returncode,
               'log': log, 'sha256': hashlib.sha256((REPORT / log).read_bytes()).hexdigest()}
        rows.append(row)
        (REPORT / (prefix + '-commands.json')).write_text(json.dumps(rows, indent=2) + '\n')
        assert result.returncode == 0, (row, output[-3500:])
        assert not any(token in output for token in ['SCRIPT ERROR', 'Parse Error', '\nERROR:'])
        print(json.dumps({'phase': phase, 'actual_CLI': len(rows), 'exit': result.returncode}), flush=True)
    assert all((foreign / '.git' / name).read_bytes() == raw for name, raw in state.items())

godot = str(Path(os.environ['FARM_GODOT_BIN']).resolve(strict=True))
gd = []
names = sorted(name for name in mapping if name.endswith('.gd')) + ['tools/plant_depth_capture.gd', 'tools/plant_depth_game.gd']
assert len(names) == 46
for logical in names:
    physical = mapping.get(logical, logical) if phase == 'after' else logical
    argv = [godot, '--headless', '--path', str(ROOT), '--check-only', '--script', 'res://' + physical]
    log = prefix + '-gd-%02d.txt' % (len(gd) + 1)
    with (REPORT / log).open('x') as stream:
        result = subprocess.run(argv, cwd=ROOT, env=dict(git_environment(), PYTHONDONTWRITEBYTECODE='1'),
                                stdout=stream, stderr=subprocess.STDOUT, timeout=120)
    output = (REPORT / log).read_text()
    gd.append({'logical': logical, 'physical': physical, 'command': argv, 'exit': result.returncode,
               'log': log, 'raw_SHA256': hashlib.sha256((REPORT / log).read_bytes()).hexdigest(),
               'source_SHA256': hashlib.sha256((ROOT / physical).read_bytes()).hexdigest()})
    (REPORT / (prefix + '-GD.json')).write_text(json.dumps(gd, indent=2) + '\n')
    assert result.returncode == 0 and not any(token in output for token in ['SCRIPT ERROR', 'Parse Error', 'ERROR:']), (gd[-1], output[-2000:])
    print(json.dumps({'phase': phase, 'actual_GD_parse': len(gd), 'exit': result.returncode}), flush=True)

water = importlib.import_module('tools.qa.world.analyze_water_audit' if phase == 'after' else 'analyze_water_audit')
raw_names = ['before/native-1152.json', 'before/native-1920.json', 'before/native-3584.json', 'before-f10/native-1152.json']
original = ROOT / 'docs/reports/water-2026-10'
signatures = {name: hashlib.sha256((original / name).read_bytes()).hexdigest() for name in raw_names}
with tempfile.TemporaryDirectory(prefix='owned Water writer ' + phase + ' ') as directory:
    owned = Path(directory).resolve()
    for name in raw_names:
        target = owned / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original / name, target)
        retained = REPORT / name
        retained.parent.mkdir(parents=True, exist_ok=True)
        if retained.exists():
            assert hashlib.sha256(retained.read_bytes()).hexdigest() == signatures[name]
        else:
            shutil.copyfile(original / name, retained)
    stdout = io.StringIO()
    with patch.object(water, 'FOLDER', owned), redirect_stdout(stdout):
        water.main()
    assert stdout.getvalue().strip() == 'WATER BASELINE: 48 verified diagnostic repeats; OPT/GPU acceptance: not claimed'
    (REPORT / (prefix + '-water-writer.txt')).write_text(stdout.getvalue())
    analysis = json.loads((owned / 'baseline-analysis.json').read_text())
    assert len(analysis) == 4 and sum(len(row['measurements']) for row in analysis) == 48
    outputs = {}
    for name in ['baseline-analysis.json', 'native-summary.md']:
        target = prefix + '-water-' + name
        shutil.copyfile(owned / name, REPORT / target)
        outputs[name] = {'file': target, 'sha256': hashlib.sha256((REPORT / target).read_bytes()).hexdigest()}
assert all(hashlib.sha256((original / name).read_bytes()).hexdigest() == digest for name, digest in signatures.items())
writer = {'real_module_main': True, 'owned_raw_mirror': True, 'raw_input_SHA256': signatures,
          'outputs': outputs, 'diagnostic_old_repeats': 48, 'native_frames_new': 0,
          'Game_new': False, 'GPU_FPS_admission': False}
(REPORT / (prefix + '-water-writer.json')).write_text(json.dumps(writer, indent=2) + '\n')
result = {'phase': phase, 'base': plan['base'], 'commands': rows, 'GD_parse': gd,
          'foreign_cwd': True, 'foreign_Git_overrides': phase == 'after',
          'foreign_Git_index_config_unchanged': True, 'historical_verifier_commands': 16,
          'asset_verifier_commands': 6, 'old_negative_suites': 16,
          'actual_owned_Water_writer': writer, 'Game_new': False, 'native_sessions': 0,
          'GPU_FPS_admission': False, 'input_reports_unmodified': True}
if phase == 'after':
    before = json.loads((REPORT / 'before-profile.json').read_text())
    assert len(before['commands']) == len(rows) == 38
    for left, right in zip(before['commands'], rows):
        assert left['logical_command'] == right['logical_command']
        if not right['logical_command'].startswith('test_'):
            assert (REPORT / left['log']).read_bytes() == (REPORT / right['log']).read_bytes(), right['logical_command']
    for name in outputs:
        assert (REPORT / before['actual_owned_Water_writer']['outputs'][name]['file']).read_bytes() == (REPORT / outputs[name]['file']).read_bytes(), name
    result.update(historical_stdout_byte_equal=22, owned_water_outputs_byte_equal=2)
(REPORT / (phase + '-profile.json')).write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'phase': phase, 'actual_commands': len(rows), 'actual_GD_parse': len(gd),
                  'actual_owned_Water_writer': True, 'native_sessions': 0, 'Game_new': False}))
