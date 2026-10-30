"""Проверяет ранний отказ профиля365 до запуска экспортёров и записи output."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def main():
    original = (REPORT / 'profile.json').read_bytes()
    env = dict(os.environ, FARM_GODOT_BIN='/usr/bin/false')
    rows = []
    with tempfile.TemporaryDirectory(prefix='assets profile refusal ') as directory:
        temporary = Path(directory)
        asset_target = ROOT / 'assets/refactor03-must-not-create.json'
        assert not asset_target.exists()
        attempts = [[], ['--output', str(REPORT / 'profile.json')],
                    ['--output', str(asset_target)], ['--output', str(temporary / 'bad.txt')],
                    ['--output', str(temporary / 'missing/output.json')]]
        for arguments in attempts:
            result = subprocess.run([sys.executable, str(REPORT / 'profile.py'), *arguments],
                cwd=temporary, env=env, capture_output=True, text=True, timeout=20)
            assert result.returncode == 2 and 'error:' in result.stderr, result
            assert (REPORT / 'profile.json').read_bytes() == original
            assert not asset_target.exists() and not list(temporary.iterdir())
            rows.append({'arguments': arguments, 'exit': result.returncode,
                         'stdout': result.stdout, 'stderr': result.stderr})
    output = {'actual_early_refusals': rows, 'existing_profile_unchanged': True,
              'profile_sha256': hashlib.sha256(original).hexdigest(),
              'requested_outputs_not_created': True, 'temporary_removed': True}
    with (REPORT / 'output-refusals.json').open('x') as file:
        file.write(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'early_refusals': len(rows), 'existing_profile_unchanged': True}))


if __name__ == '__main__':
    main()
