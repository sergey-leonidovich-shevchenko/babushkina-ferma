#!/usr/bin/env python3
"""Fresh, bounded VFOLIAGE-010 collection; every failed/partial launch remains intact."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import uuid

from perf_contract_collect import ROOT, context, jobs, native_pid
from performance_protocol import ANSI_ESCAPE

REPORT = ROOT / 'docs/reports/visual-overhaul/vfoliage-010'


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def verify_sources(plan: dict) -> None:
    """Reject any changed source/configuration, before and after the native run."""
    for name, expected in plan['sources'].items():
        if digest(ROOT / name) != expected:
            raise ValueError('Changed declared source: ' + name)


def collect(output: Path, plan_file: Path) -> None:
    """Run the two declared window sizes serially; never select only successful frames or retry silently."""
    plan = json.loads(plan_file.read_text())
    verify_sources(plan)
    if jobs():
        raise ValueError('Another Godot is active; no process was stopped')
    output.mkdir()
    (output / 'plan-copy.json').write_bytes(plan_file.read_bytes())
    source = {'task': 'VFOLIAGE-010', 'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'complete': False, 'plan_sha256': digest(plan_file), 'runs': []}
    write(output / 'source.json', source)
    for width in plan['widths']:
        verify_sources(plan)
        folder = output / str(width)
        folder.mkdir()
        profile = 'Codex-VFOLIAGE-010-' + uuid.uuid4().hex
        command = ['/usr/bin/open', '-n', '-W', '-a', str(ROOT / 'tools/Godot.app'), '--args', '--path', str(ROOT), '--windowed', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--log-file', str(folder / 'engine.txt'), '--script', 'res://tools/foliage_visibility_capture.gd', '--', '--output=' + str(folder / 'native'), '--profile=' + profile, '--width=' + str(width)]
        before = context()
        timeout = False
        try:
            run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
            code, raw = run.returncode, run.stdout.decode(errors='replace')
        except subprocess.TimeoutExpired as error:
            timeout = True
            pid = native_pid(profile)
            if pid:
                os.kill(pid, signal.SIGTERM)
            code, raw = -9, (error.stdout or b'').decode(errors='replace')
        capture_path = folder / 'native/capture.json'
        capture = json.loads(capture_path.read_text()) if capture_path.exists() else None
        log_path = folder / 'engine.txt'
        log = log_path.read_text() if log_path.exists() else ''
        clean = '\n'.join(line.lstrip() for line in ANSI_ESCAPE.sub('', log).splitlines())
        record = {'width': width, 'profile': profile, 'command': command, 'before': before, 'after': context(), 'exit': code, 'timeout': timeout, 'stdout': raw, 'engine_errors': bool(re.search(r'^ERROR:|SCRIPT ERROR:|Parse Error', clean, re.M)), 'capture_complete': bool(capture and capture['complete']), 'capture_errors': capture['errors'] if capture else ['missing capture']}
        source['runs'].append(record)
        write(folder / 'environment.json', record)
        write(output / 'source.json', source)
        verify_sources(plan)
        if code or timeout or record['engine_errors'] or not record['capture_complete'] or record['capture_errors']:
            raise ValueError('Failed native run retained: ' + str(folder))
        print('CAPTURED', width, len(capture['records']), flush=True)
    source['complete'] = True
    source['artifacts'] = {str(p.relative_to(output)): digest(p) for p in output.rglob('*') if p.is_file() and p.name != 'source.json'}
    write(output / 'source.json', source)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--plan', type=Path, default=REPORT / 'plan.json')
    args = parser.parse_args()
    collect(args.output.resolve(), args.plan.resolve())
