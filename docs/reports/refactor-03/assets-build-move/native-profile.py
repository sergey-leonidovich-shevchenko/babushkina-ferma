"""Исполняет оба настоящих fixed-input collector и parse-only, не создавая игровые кадры/FPS."""
from __future__ import annotations

import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, cwd=ROOT, timeout=180, expected=0):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    row = {'command': list(command), 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
    assert result.returncode == expected, row
    if expected == 0:
        assert not any(token in result.stdout + result.stderr for token in ['SCRIPT ERROR:', 'Parse Error:', '\nERROR:']), row
    return row


def collect():
    from tools.assets.contracts.preview_portability import validate_inputs, validate_report

    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    godot = os.environ['FARM_GODOT_BIN']
    native = [run([godot, '--headless', '--path', str(ROOT), '--editor', '--quit'], timeout=180)]
    scripts = [r['target'] for r in baseline['assignments'].values() if r['target'].endswith('.gd')]
    scripts += [p for p in baseline['consumers'] if p.endswith('.gd')]
    for name in scripts:
        native.append(run([godot, '--headless', '--path', str(ROOT), '--check-only', '--script', 'res://' + name]))
    with tempfile.TemporaryDirectory(prefix='assets native old new ') as directory:
        parent = Path(directory)
        foreign = parent / 'foreign cwd'
        foreign.mkdir()
        records = {}
        for version in ['old', 'new']:
            fixture = parent / version
            fixture.mkdir()
            shutil.copytree(ROOT / 'tests/fixtures/preview_portability', fixture / 'tests/fixtures/preview_portability')
            for old in ['tools/item_ui_fitter.gd', 'tools/preview_portability_capture.gd']:
                relative = old if version == 'old' else baseline['assignments'][old]['target']
                path = fixture / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                raw = (gzip.decompress((REPORT / 'inputs' / (old.replace('/', '--') + '.gz')).read_bytes())
                       if version == 'old' else (ROOT / relative).read_bytes())
                path.write_bytes(raw)
            (fixture / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Asset move fixed inputs"\n[debug]\nfile_logging/enable_file_logging=false\n')
            source_files = {str(p.relative_to(fixture)): sha(p) for p in fixture.rglob('*') if p.is_file()}
            script = 'tools/preview_portability_capture.gd'
            if version == 'new':
                script = baseline['assignments'][script]['target']
            output = fixture / 'result'
            command = [godot, '--headless', '--path', str(fixture), '--script', 'res://' + script,
                       '--', '--output=' + str(output)]
            executed = run(command, cwd=foreign)
            report = json.loads((output / 'report.json').read_text())
            files = {str(p.relative_to(output)): sha(p) for p in output.rglob('*') if p.is_file()}
            refusal = run(command, cwd=foreign, expected=2)
            assert {str(p.relative_to(output)): sha(p) for p in output.rglob('*') if p.is_file()} == files
            assert all(sha(fixture / p) == digest for p, digest in source_files.items())
            records[version] = {'execution': executed, 'overwrite_refusal': refusal, 'report': report,
                                'files': files, 'fixed_input_files_unchanged': True,
                                'exact_script_sha256': sha(fixture / script)}
        assert records['old']['report']['cases'] == records['new']['report']['cases']
        assert records['old']['report']['collector_sha256'] == records['old']['exact_script_sha256']
        assert records['new']['report']['collector_sha256'] == records['new']['exact_script_sha256']
        assert records['old']['report']['collector_sha256'] == baseline['capture_pins']['tools/preview_portability_capture.gd']['sha256']
        for name, digest in records['old']['files'].items():
            if name.endswith('.png'):
                assert records['new']['files'][name] == digest
        new_fixture = parent / 'new'
        assert validate_inputs(new_fixture) == []
        assert validate_report(parent / 'old/result', new_fixture) == []
        assert validate_report(parent / 'new/result', new_fixture) == []
        mutations = []
        path = new_fixture / 'result/report.json'
        original = path.read_bytes()
        for kind in ['missing-map', 'partial-map', 'old-sha-on-current-map', 'unknown-map']:
            data = json.loads(original)
            if kind == 'missing-map':
                data.pop('source_paths')
            elif kind == 'partial-map':
                data['source_paths'].pop('tools/item_ui_fitter.gd')
            elif kind == 'old-sha-on-current-map':
                data['collector_sha256'] = records['old']['exact_script_sha256']
            else:
                data['source_paths'] = {'outside': '../other'}
            path.write_text(json.dumps(data))
            errors = validate_report(path.parent, new_fixture)
            assert errors, kind
            mutations.append({'kind': kind, 'errors': errors})
        path.write_bytes(original)
        assert validate_report(path.parent, new_fixture) == []
    return {'fresh_editor_import_and_parse_only': native, 'GD_parse_count': len(scripts),
            'actual_fixed_input_old_and_new': records, 'all_four_PNG_and_case_metrics_equal': True,
            'actual_current_metadata_mutations_rejected': mutations, 'temporary_projects_removed': True,
            'native_game_frame_accepted': False, 'GPU_FPS_admission': False}
