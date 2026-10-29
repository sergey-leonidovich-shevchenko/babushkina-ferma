#!/usr/bin/env python3
"""Запускает независимые нативные повторы VBASE с паспортом машины и открытыми исходными замерами."""
from __future__ import annotations
from tools.assets.contracts.source_paths import current_source

import argparse
import hashlib
import json
import os
import platform
import subprocess
from tools.common.git import git_environment
import uuid
from datetime import datetime, timezone
from pathlib import Path

from tools.common.paths import project_root
from tools.common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)


def command(args: list[str]) -> str:
    """Читает только разрешённые сведения; недоступность помечается, а не заменяется нулём."""
    try:
        options = {"text": True, "stderr": subprocess.STDOUT, "timeout": 15}
        # Git читает проект исходника; системные запросы сохраняют контекст вызывающего процесса.
        if args and args[0] == "git":
            options.update(cwd=ROOT, env=git_environment())
        return subprocess.check_output(args, **options).strip()
    except (OSError, subprocess.SubprocessError) as error:
        return 'UNAVAILABLE: ' + type(error).__name__


def environment() -> dict:
    """Фиксирует питание и фон без командных аргументов, пользовательских путей и серийных номеров."""
    machine = {key: command(['sysctl', '-n', key]) for key in
               ('hw.model', 'machdep.cpu.brand_string', 'hw.memsize', 'hw.ncpu')} if platform.system() == 'Darwin' else {}
    raw = command(['ps', '-A', '-o', 'pid=,%cpu=,rss=,comm='])
    processes = []
    if not raw.startswith('UNAVAILABLE'):
        for line in raw.splitlines():
            fields = line.strip().split(None, 3)
            if len(fields) != 4:
                continue
            try:
                processes.append(dict(pid=int(fields[0]), cpu_percent=float(fields[1]), rss_kib=int(fields[2]),
                                      executable=Path(fields[3]).name))
            except ValueError:
                continue
    return dict(utc=datetime.now(timezone.utc).isoformat(), system=platform.system(),
                os_version=platform.mac_ver()[0] or platform.release(), architecture=platform.machine(),
                machine=machine,
                power=command(['pmset', '-g', 'batt']) if machine else 'UNAVAILABLE: non-macOS',
                power_settings=command(['pmset', '-g', 'custom']) if machine else 'UNAVAILABLE: non-macOS',
                thermal=command(['pmset', '-g', 'therm']) if machine else 'UNAVAILABLE: non-macOS',
                background=sorted(processes, key=lambda row: row['cpu_percent'], reverse=True)[:15],
                background_available=not raw.startswith('UNAVAILABLE'),
                background_note='Two boundary snapshots; CPU percentages are ps estimates, not a continuous profiler.')


def source_signature() -> dict:
    """Привязывает измерение к Git и содержимому стенда, включая ещё не закоммиченный инструмент."""
    paths = ['tools/visual_baseline.gd', 'tools/run_visual_baseline.py', 'tools/analyze_visual_baseline.py',
             'project.godot', 'main.tscn']
    return dict(commit=command(['git', 'rev-parse', 'HEAD']),
                dirty_paths=command(['git', 'status', '--short']),
                sha256={name: hashlib.sha256((current_source(ROOT, name)).read_bytes()).hexdigest() for name in paths if (current_source(ROOT, name)).exists()})


def main() -> int:
    """Проводит три запуска без параллельных тестов; не заменяет неудачный повтор тихим успешным."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repeats', type=int, choices=(1, 3), default=3)
    parser.add_argument('--fault', choices=('resize', 'pause', 'focus'), default='')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error('Нужен новый каталог: существующие исходные данные не перезаписываются')
    output.mkdir(parents=True)
    godot = Path(os.environ.get('FARM_GODOT_BIN', ROOT / 'tools/Godot.app/Contents/MacOS/Godot')).resolve()
    manifest = dict(schema=1, source=source_signature(), requested_repeats=args.repeats, runs=[], fault=args.fault)
    for repeat in range(args.repeats):
        folder = output / f'run-{repeat + 1}'
        folder.mkdir()
        profile = 'Codex-VBASE-001-' + uuid.uuid4().hex
        call = [str(godot), '--path', str(ROOT), '--windowed', '--resolution', '1152x648', '--position', '80,80',
                '--rendering-method', 'gl_compatibility', '--log-file', str(folder / 'engine.txt'),
                '--script', 'tools/qa/camera/visual_baseline.gd', '--', f'--output={folder}', f'--profile={profile}', f'--repeat={repeat}']
        if args.fault:
            call.append('--fault=' + args.fault)
        before = environment()
        print(f'VBASE: repeat {repeat + 1}/{args.repeats}', flush=True)
        with (folder / 'stdout.txt').open('w') as log:
            try:
                result = subprocess.run(call, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
        after = environment()
        record = dict(repeat=repeat, folder=folder.name, profile=profile, exit_code=code, before=before, after=after)
        manifest['runs'].append(record)
        (output / 'session.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        print(f'VBASE: repeat {repeat + 1} exit={code}', flush=True)
        if code:
            return code
    from tools.qa.camera.analyze_visual_baseline import analyze_run, analyze_session
    summary = analyze_session(output) if args.repeats == 3 else analyze_run(json.loads((output / 'run-1/native.json').read_text()))
    if args.repeats == 1:
        summary['admission'] = 'VALID_SINGLE_RUN_ONLY'
    (output / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if summary['admission'] in ('VALID_BASELINE', 'VALID_SINGLE_RUN_ONLY') else 1


if __name__ == '__main__':
    raise SystemExit(main())
