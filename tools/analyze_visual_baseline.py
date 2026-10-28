#!/usr/bin/env python3
"""Проверяет пригодность VBASE, отдельно от соблюдения бюджета плавности. Выбросы не удаляются."""
from __future__ import annotations

if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse
import collections
import json
import math
from pathlib import Path

from tools.qa.performance.analyze_optimization_audit import statistics

SIZE = [1152, 648]
START = [432, 672]
OUTWARD = [[648, 672], [864, 672], [864, 552], [864, 360], [1128, 360], [1128, 528], [1128, 744], [1320, 744]]
TARGETS = OUTWARD + OUTWARD[-2::-1] + [START]
COLUMNS = ['interval_usec', 'elapsed_usec', 'draw_index', 'physics_tick', 'world_minutes', 'x', 'y',
           'condition_id', 'simulation_live', 'process_ms', 'physics_ms', 'draw_calls', 'texture_bytes', 'static_bytes']


def require(condition: bool, message: str) -> None:
    """Отклоняет повреждённую или несопоставимую трассу с точной причиной."""
    if not condition:
        raise ValueError(message)


def check_conditions(value: dict) -> None:
    """Проверяет факты окна независимо от самооценки valid, записанной стендом."""
    require(all(value.get(key) == SIZE for key in ('window', 'framebuffer', 'root_size')), 'wrong window/framebuffer')
    require(value.get('focused') is True, 'focus lost')
    require(value.get('mode') == 0 and value.get('vsync') == 1, 'window mode/vsync changed')


def analyze_run(data: dict) -> dict:
    """Доказательство живого полного маршрута, непрерывности draw-счётчика и всех длинных кадров."""
    require(data.get('schema') == 1 and data.get('preset') == 'village-cardinal-1152-v1', 'unknown preset/schema')
    require(data.get('display_server') not in (None, 'headless') and data.get('driver') == 'opengl3', 'native renderer required')
    require(data.get('seed') == 20261015 and data.get('route_start') == START and data.get('route_targets') == TARGETS, 'route/seed changed')
    require(data.get('columns') == COLUMNS, 'unknown frame columns')
    require(data.get('route_finished') is True and data.get('location') == 'overworld', 'incomplete route')
    require(not data.get('fault_injection'), 'fault-injected trace')
    require(data.get('pause_on_focus_loss') is False, 'focus pause enabled')
    require(data.get('physics_hz') == 60 and data.get('max_fps') == 0 and data.get('low_processor_usage') is True
            and data.get('idle_sleep_usec') == 500, 'pacing changed')
    require(data.get('content_scale_mode') == 0 and data.get('content_scale_factor') == 1, 'content scaling changed')
    require(data.get('warmup_rendered_frames') == 120 and data.get('warmup_world_frozen') is True
            and data.get('settle_after_readback') == 8, 'warmup changed')
    for key in ('requested_window', 'requested_framebuffer', 'readback_start', 'readback_end'):
        require(data.get(key) == SIZE, 'readback/request mismatch: ' + key)
    check_conditions(data['initial_conditions'])
    groups = data['condition_groups']
    require(bool(groups), 'missing per-frame conditions')
    for group in groups:
        check_conditions(group['conditions'])
    rows = data['frames']
    require(len(rows) == data['sample_count'] and len(rows) >= 120, 'short/truncated trace')
    require(all(len(row) == len(COLUMNS) for row in rows), 'truncated frame')
    counts = collections.Counter()
    elapsed = 0
    last_draw = rows[0][2] - 1
    last_tick = 0
    last_world = data['world_start_minutes']
    last_position = START
    for row in rows:
        dt, cumulative, draw, tick, world, x, y, condition_id, live, *monitors = row
        require(all(type(n) in (int, float) and math.isfinite(n) for n in row[:8] + monitors), 'non-finite frame')
        require(dt > 0 and all(n >= 0 for n in monitors), 'invalid interval/monitor')
        elapsed += dt
        require(abs(cumulative - elapsed) <= 1, 'gap in elapsed timeline')
        require(draw == last_draw + 1, 'missing/duplicate draw sample')
        require(tick >= last_tick and world >= last_world and live is True, 'simulation stopped')
        require(abs((world - last_world) - (tick - last_tick) / 60) < 0.04, 'world clock not following simulation')
        require(math.dist([x, y], last_position) <= (tick - last_tick) * 210 / 60 + 1, 'non-physical movement')
        require(type(condition_id) is int and 0 <= condition_id < len(groups), 'missing condition group')
        counts[condition_id] += 1
        last_draw, last_tick, last_world, last_position = draw, tick, world, [x, y]
    require(all(counts[i] == g['frames'] for i, g in enumerate(groups)), 'condition coverage mismatch')
    require(elapsed == data['interval_span_usec'], 'missing long interval')
    require(abs(last_world - data['world_end_minutes']) < 1e-5 and last_world - data['world_start_minutes'] > 10, 'world did not advance')
    require(math.dist(last_position, START) <= 4, 'route did not return home')
    checks = data['route_checkpoints']
    require(len(checks) == len(TARGETS), 'missing checkpoints')
    previous_tick = 0
    for i, point in enumerate(checks):
        require(point['index'] == i and point['target'] == TARGETS[i] and math.dist(point['position'], TARGETS[i]) <= 4, 'wrong checkpoint')
        require(previous_tick < point['tick'] <= last_tick, 'wrong checkpoint order')
        previous_tick = point['tick']
    stats = statistics([r[0] / 1000 for r in rows])
    # Порог OPT — диагностический индикатор; валидный плохой результат остаётся полезной исходной базой.
    budget = 'PASS' if stats['p95_ms'] <= 18.5 and stats['p99_ms'] <= 33.333 and stats['max_ms'] <= 100 else 'FAIL'
    return dict(admission='VALID_BASELINE', budget_60fps_candidate=budget, draw=stats,
                wall_seconds=elapsed / 1e6, simulation_seconds=last_world - data['world_start_minutes'],
                max_draw_calls=max(r[11] for r in rows), max_texture_bytes=max(r[12] for r in rows),
                max_static_bytes=max(r[13] for r in rows), terrain_rebuilds=data['terrain_rebuilds'])


def analyze_session(folder: Path) -> dict:
    """Требует три независимых процесса одного preset и паспорт каждого запуска."""
    session = json.loads((folder / 'session.json').read_text())
    require(session.get('requested_repeats') == 3 and len(session['runs']) == 3, 'need three independent repeats')
    require(not session.get('fault'), 'fault session')
    require(len(session['source']['commit']) == 40 and bool(session['source']['sha256']), 'missing source revision')
    output, profiles, pids, comparisons, machines = [], set(), set(), [], []
    for i, run in enumerate(session['runs']):
        require(run['repeat'] == i and run['exit_code'] == 0, 'failed/missing process')
        for stamp in (run['before'], run['after']):
            require(stamp['background_available'] and bool(stamp['background']), 'background not recorded')
            require(stamp['machine'] and 'UNAVAILABLE' not in stamp['power'] and 'UNAVAILABLE' not in stamp['power_settings'], 'power/hardware not recorded')
            machines.append([stamp['machine'], stamp.get('os_version'), stamp['power'].splitlines()[0], stamp['power_settings']])
        data = json.loads((folder / run['folder'] / 'native.json').read_text())
        log = (folder / run['folder'] / 'stdout.txt').read_text()
        require(not any(token in log for token in ('ERROR:', 'SCRIPT ERROR', 'Parse Error')), 'engine error')
        require(data['repeat'] == i and data['profile'] == run['profile'], 'profile/repeat mismatch')
        profiles.add(data['profile']); pids.add(data['pid'])
        require(data['profile'].startswith('Codex-VBASE-001-'), 'not an isolated profile')
        comparisons.append([data[key] for key in ('engine', 'adapter', 'map_revision', 'start_camera', 'screen', 'screen_scale', 'screen_refresh_hz')]
                           + [[point['tick'] for point in data['route_checkpoints']]])
        output.append(analyze_run(data))
    require(len(profiles) == 3 and len(pids) == 3, 'reused process/profile')
    require(all(c == comparisons[0] for c in comparisons), 'non-comparable configuration')
    require(all(m == machines[0] for m in machines), 'machine/power changed')
    return dict(admission='VALID_BASELINE', source_commit=session['source']['commit'], repeats=output,
                note='Native draw intervals include CPU, GPU, display wait and monitoring overhead; not isolated GPU time, physical input or all-map acceptance.')


def main() -> None:
    """Печатает проверенную сводку без изменения исходных кадров."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze_session(args.folder), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
