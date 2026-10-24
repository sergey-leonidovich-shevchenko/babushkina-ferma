#!/usr/bin/env python3
"""Collect only the predeclared VFOLIAGE-009 native windows, preserving every partial run."""
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

REPORT = ROOT / 'docs/reports/visual-overhaul/vfoliage-009'
PLAN = REPORT / 'plan.json'


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def verify_sources(plan: dict) -> None:
    """Reject changed instrumentation before another launch; do not relabel old captures."""
    for name, expected in plan['sources'].items():
        if digest(ROOT / name) != expected:
            raise ValueError('Declared source changed: ' + name)


def collect(output: Path, plan_file: Path = PLAN) -> None:
    """Reserve one owned collection, then run the two fixed windows serially without retries."""
    plan = json.loads(plan_file.read_text())
    verify_sources(plan)
    if jobs():
        raise ValueError('Another Godot is active; no process was stopped')
    output.mkdir()
    source = {
        'task': 'VFOLIAGE-009', 'complete': False,
        'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'plan_sha256': digest(plan_file), 'sources': plan['sources'], 'runs': [],
        'purpose': 'controlled native visual verification, not FPS or hardware input',
    }
    (output / 'plan-copy.json').write_bytes(plan_file.read_bytes())
    write(output / 'source.json', source)
    for width in plan['widths']:
        verify_sources(plan)
        folder = output / str(width)
        folder.mkdir()
        profile = 'Codex-VFOLIAGE-009-' + uuid.uuid4().hex
        command = [
            '/usr/bin/open', '-n', '-W', '-a', str(ROOT / 'tools/Godot.app'), '--args',
            '--path', str(ROOT), '--windowed', '--audio-driver', 'Dummy',
            '--rendering-method', 'gl_compatibility', '--log-file', str(folder / 'engine.txt'),
            '--script', 'res://tools/foliage_pause_capture.gd', '--',
            '--output=' + str(folder / 'native'), '--profile=' + profile, '--width=' + str(width),
        ]
        before = context()
        timeout = False
        try:
            run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
            code, launch_output = run.returncode, run.stdout.decode(errors='replace')
        except subprocess.TimeoutExpired as error:
            # Only this unique profile may be stopped; never use a broad process-name kill.
            timeout = True
            pid = native_pid(profile)
            if pid:
                os.kill(pid, signal.SIGTERM)
            code = -9
            launch_output = (error.stdout or b'').decode(errors='replace')
        after = context()
        capture_file = folder / 'native/capture.json'
        capture = json.loads(capture_file.read_text()) if capture_file.exists() else None
        log_file = folder / 'engine.txt'
        log = log_file.read_text() if log_file.exists() else ''
        clean = '\n'.join(line.lstrip() for line in ANSI_ESCAPE.sub('', log).splitlines())
        failed = bool(re.search(r'^ERROR:|SCRIPT ERROR:|Parse Error', clean, re.M))
        record = {
            'width': width, 'profile': profile, 'command': command, 'wrapper_exit': code,
            'timeout': timeout, 'launch_output': launch_output, 'before': before, 'after': after,
            'engine_errors': failed, 'capture_complete': bool(capture and capture['complete']),
            'capture_errors': capture['errors'] if capture else ['missing capture summary'],
        }
        write(folder / 'environment.json', record)
        source['runs'].append(record)
        write(output / 'source.json', source)
        verify_sources(plan)
        if code or timeout or failed or not capture or not capture['complete'] or capture['errors']:
            raise ValueError('Native capture failed; all partial files retained: ' + str(width))
        print('CAPTURED', width, len(capture['records']), flush=True)
    source['complete'] = True
    source['artifacts'] = {
        str(path.relative_to(output)): digest(path)
        for path in output.rglob('*') if path.is_file() and path.name != 'source.json'
    }
    write(output / 'source.json', source)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--plan', type=Path, default=PLAN)
    args = parser.parse_args()
    collect(args.output.resolve(), args.plan.resolve())
