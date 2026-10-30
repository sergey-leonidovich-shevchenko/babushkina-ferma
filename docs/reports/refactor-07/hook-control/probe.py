"""Reproduce the real pre-commit rejection in an owned clone; never commit to the game repo."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    root, output = args.root.resolve(), args.output.resolve()
    if not (root/'project.godot').is_file() or output.exists() or output.is_relative_to(root):
        parser.error('owning project and new external output required')
    output.mkdir(parents=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
    records = []

    def run(label, argv, cwd):
        start = time.monotonic()
        result = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, text=True, timeout=120)
        records.append({'label': label, 'argv': argv, 'code': result.returncode,
                        'seconds': round(time.monotonic()-start, 3),
                        'stdout': result.stdout, 'stderr': result.stderr})
        (output/'commands.json').write_text(json.dumps(records, indent=2)+'\n')
        return result

    def require(label, argv, cwd):
        result = run(label, argv, cwd)
        if result.returncode:
            raise RuntimeError(label)
        return result.stdout

    with tempfile.TemporaryDirectory(prefix='farm real hook control ') as tmp:
        parent = Path(tmp)
        clone = parent/'owned clone'
        require('clone', ['git', 'clone', '--shared', '--no-checkout', '-q', str(root), str(clone)], parent)
        require('checkout', ['git', 'checkout', 'HEAD', '--', 'tools', 'VERSION', 'project.godot'], clone)
        names = require('current-inputs', ['git', '-C', str(root), 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], parent).split('\0')
        for name in names:
            if name.startswith('tools/') and (root/name).is_file():
                target = clone/name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(root/name, target)
        for name in ['pyproject.toml', '.gdlintrc', '.githooks/pre-commit', 'docs/reports/refactor-07/baseline/legacy-sources.json']:
            target = clone/name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root/name, target)
            shutil.copymode(root/name, target)
        path = clone/'tools/quality/new nested/probe.py'
        path.parent.mkdir()
        path.write_text('value: int = "wrong"\n')
        require('stage-real-bad-source', ['git', 'add', '-f', str(path.relative_to(clone))], clone)
        head = require('head-before', ['git', 'rev-parse', 'HEAD'], clone)
        entries = require('index-before', ['git', 'ls-files', '--stage', '-z'], clone)
        version = (clone/'VERSION').read_bytes()
        result = run('actual-git-commit', ['git', '-c', 'core.hooksPath=.githooks', '-c', 'user.name=Quality Control', '-c', 'user.email=quality@example.invalid', 'commit', '-m', 'negative quality control'], clone)
        if result.returncode == 0 or 'Incompatible types in assignment' not in result.stdout+result.stderr:
            raise RuntimeError('actual pre-commit failed to reject the real type error')
        if require('head-after', ['git', 'rev-parse', 'HEAD'], clone) != head:
            raise RuntimeError('negative hook unexpectedly committed')
        if require('index-after', ['git', 'ls-files', '--stage', '-z'], clone) != entries:
            raise RuntimeError('negative hook changed staged blobs/modes')
        if (clone/'VERSION').read_bytes() != version:
            raise RuntimeError('version bump ran before quality rejection')
        result = {'commit_rejected': True, 'type_error_seen': True, 'head_unchanged': True,
                  'index_entries_unchanged': True, 'version_unchanged': True,
                  'version_sha256': hashlib.sha256(version).hexdigest()}
    result['owned_temp_removed'] = not parent.exists()
    (output/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
