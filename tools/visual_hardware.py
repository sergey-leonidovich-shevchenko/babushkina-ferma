#!/usr/bin/env python3
"""VBASE-002: паспорт доступной машины и допуск сопоставимых нативных повторов, отдельно от FPS."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image

from analyze_visual_baseline import analyze_session, require
from run_visual_baseline import ROOT, command, environment, source_signature

REPORT = ROOT / 'docs/reports/visual-overhaul/vbase-002'
POLICY = REPORT / 'profile.json'
TOOLS = ('tools/visual_hardware.py', 'tools/visual_baseline.gd', 'tools/run_visual_baseline.py',
         'tools/analyze_visual_baseline.py', 'scripts/systems/camera_system.gd')


def digest(path: Path) -> str:
    """Подписывает конкретный исходный файл; не подменяет подпись путём или размером."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summaries_match(stored, computed) -> bool:
    """Допускает только округление float между версиями Python; состав/счётчики/решения остаются точными."""
    if isinstance(computed, dict):
        return isinstance(stored, dict) and stored.keys() == computed.keys() and all(
            summaries_match(stored[key], value) for key, value in computed.items())
    if isinstance(computed, list):
        return isinstance(stored, list) and len(stored) == len(computed) and all(
            summaries_match(a, b) for a, b in zip(stored, computed))
    if isinstance(computed, float):
        return type(stored) in (int, float) and math.isfinite(stored) and math.isclose(
            stored, computed, rel_tol=1e-12, abs_tol=1e-9)
    return type(stored) is type(computed) and stored == computed


def display_inventory(raw: dict) -> list[dict]:
    """Оставляет только модели/объём видеопамяти; EDID, серийные номера и пути не сохраняет."""
    return sorted((dict(model=gpu.get('sppci_model'), dedicated_vram=gpu.get('spdisplays_vram'),
                        shared_vram=gpu.get('spdisplays_vram_shared'))
                   for gpu in raw.get('SPDisplaysDataType', [])), key=lambda gpu: str(gpu['model']))


def inventory() -> dict:
    """Читает доступную локальную машину без изменения питания или выбора GPU."""
    result = dict(system=platform.system(), os_version=platform.mac_ver()[0] or platform.release(),
                  architecture=platform.machine(), gpus=[])
    if result['system'] == 'Darwin':
        raw = command(['system_profiler', 'SPDisplaysDataType', '-json'])
        try:
            result['gpus'] = display_inventory(json.loads(raw))
        except (ValueError, TypeError, AttributeError):
            result['unavailable'] = 'GPU inventory unavailable'
    else:
        result['unavailable'] = 'No verified native adapter for this platform'
    return result


def active_power(settings: str, mode: str) -> dict[str, str]:
    """Разбирает только активную секцию; другая схема питания не подтверждает её настройки."""
    require(mode + ':' in settings, 'active power settings missing')
    section = settings.split(mode + ':', 1)[1].split('Power:', 1)[0]
    return dict(re.findall(r'^\s*(lowpowermode|gpuswitch)\s+(\d+)\s*$', section, re.M))


def validate_policy(policy: dict) -> dict:
    """Не даёт превратить один Mac в подтверждение неизвестных ОС или релизного минимума."""
    require(policy.get('schema') == 1 and policy.get('id') == 'development-mac-5300m-battery-v1', 'unknown hardware policy')
    require(policy.get('scope') == 'overworld-through-VMAP-003', 'first-location scope changed')
    require(policy.get('release_minimum_approved') is False, 'release minimum has not been tested')
    devices = policy['devices']
    require(len({d['id'] for d in devices}) == len(devices), 'duplicate device')
    selected = [d for d in devices if d.get('status') == 'reference']
    require(len(selected) == 1 and selected[0]['id'] == policy['selected_device'], 'one reference machine required')
    require(all(d.get('status') in ('reference', 'unverified') for d in devices), 'unknown device status')
    require(all(d['status'] == 'unverified' for d in devices if d['id'] != policy['selected_device']), 'unmeasured device accepted')
    require({'windows', 'linux', 'mac-apple-silicon', 'mac-integrated'} <= {d['id'] for d in devices}, 'platform limitations missing')
    measurement = policy['measurement']
    require(measurement['preset'] == 'village-cardinal-1152-v1' and measurement['repeats'] == 3, 'unknown measurement preset')
    require(measurement['window'] == measurement['framebuffer'] == [1152, 648], 'reference resolution changed')
    require(measurement['start_camera'] == [0, 348] and measurement['world_scale'] == 1, 'reference projection changed')
    require(measurement['target_world_scale'] == 1.2 and measurement['target_scale_owner'] == 'VCAMERA-006', 'target camera ownership changed')
    require(measurement['budget_owner'] == 'VPERF-002' and measurement['runtime_quality_preset'] is None,
            'unimplemented quality or performance gate claimed')
    require(measurement['power_mode'] == 'Battery Power' and measurement['minimum_battery_percent'] == 50,
            'battery reference conditions changed')
    return selected[0]


def check_power(stamp: dict, measurement: dict) -> None:
    """Отделяет батарейную серию от AC; пограничный заряд и явное ограничение CPU дают отказ."""
    mode = measurement['power_mode']
    require(stamp['power'].splitlines()[0] == f"Now drawing from '{mode}'", 'power source mismatch')
    power = active_power(stamp['power_settings'], mode)
    require(power.get('lowpowermode') == '0' and power.get('gpuswitch') == '2', 'active power mode changed')
    charge = re.search(r'\b(\d+)%;', stamp['power'])
    require(charge is not None and measurement['minimum_battery_percent'] <= int(charge[1]) <= 100,
            'battery below reference charge or unavailable')
    require(stamp.get('thermal') and 'UNAVAILABLE' not in stamp['thermal'], 'thermal boundary snapshot missing')
    limits = re.findall(r'CPU_(?:Scheduler|Speed)_Limit\s*=\s*(\d+)', stamp['thermal'])
    require(all(int(limit) == 100 for limit in limits), 'thermal boundary reports throttling')


def check_inventory(value: dict, device: dict) -> None:
    """Сверяет модель и выделенную память; наличие встроенного GPU не означает его проверку."""
    require(not value.get('unavailable'), 'inventory unavailable')
    for key in ('system', 'os_version', 'architecture'):
        require(value.get(key) == device[key], 'inventory mismatch: ' + key)
    require(any(gpu.get('model') == device['gpu_model'] and gpu.get('dedicated_vram') == device['dedicated_vram']
                for gpu in value.get('gpus', [])), 'reference GPU/VRAM missing')


def verify(folder: Path, policy: dict) -> dict:
    """Отбрасывает несопоставимую сессию; плохие, но честные интервалы не удаляет."""
    device = validate_policy(policy)
    capture = json.loads((folder / 'capture.json').read_text())
    require(capture.get('schema') == 1 and capture.get('policy') == policy, 'capture policy mismatch')
    require(capture.get('exit_code') == 0, 'native capture failed')
    for stamp in (capture['before'], capture['after']):
        check_inventory(stamp, device)
    require(capture['before'] == capture['after'], 'hardware changed during session')
    for name, signature in capture['files'].items():
        path = (folder / name).resolve()
        require(path.is_relative_to(folder.resolve()), 'evidence path escapes report')
        require(path.is_file() and digest(path) == signature, 'evidence changed: ' + name)
    expected = {'native/session.json', 'native/summary.json'}
    for i in range(1, 4):
        expected.update(f'native/run-{i}/{name}' for name in ('native.json', 'stdout.txt', 'start.png', 'end.png'))
    require(expected <= capture['files'].keys(), 'missing signed native evidence')
    for name in sorted(expected):
        if name.endswith('.png'):
            with Image.open(folder / name) as frame:
                require(frame.size == (1152, 648), 'wrong native PNG size: ' + name)
                frame.verify()
    require(set(TOOLS) <= capture['tool_sha256'].keys() and
            all(re.fullmatch('[0-9a-f]{64}', v) for v in capture['tool_sha256'].values()), 'missing tool signatures')
    for name in TOOLS:
        require(digest(folder / 'instrumentation' / name) == capture['tool_sha256'][name], 'archived tool changed: ' + name)
    native = folder / 'native'
    session = json.loads((native / 'session.json').read_text())
    require([run['folder'] for run in session['runs']] == ['run-1', 'run-2', 'run-3'], 'unexpected native folders')
    result = analyze_session(native)
    require(summaries_match(json.loads((native / 'summary.json').read_text()), result), 'stored summary is stale')
    require(session['source'] == capture['source'], 'source revision mismatch')
    for name in ('tools/visual_baseline.gd', 'tools/run_visual_baseline.py', 'tools/analyze_visual_baseline.py'):
        require(session['source']['sha256'].get(name) == capture['tool_sha256'][name], 'source tool signature mismatch')
    require(re.fullmatch('[0-9a-f]{40}', result['source_commit']) is not None, 'invalid source commit')
    for run in session['runs']:
        for stamp in (run['before'], run['after']):
            require(stamp['system'] == device['system'] and stamp['architecture'] == device['architecture']
                    and stamp['os_version'] == device['os_version'], 'run platform changed')
            require(stamp['machine'] == device['machine'], 'run machine changed')
            check_power(stamp, policy['measurement'])
        data = json.loads((native / run['folder'] / 'native.json').read_text())
        for key in ('adapter', 'engine', 'driver', 'display_server'):
            require(data.get(key) == device[key], 'native configuration mismatch: ' + key)
        require(data['start_camera'] == policy['measurement']['start_camera'], 'wrong reference camera')
        require(data['world_start_minutes'] == 360, 'wrong initial world time')
        for key in ('screen', 'screen_scale'):
            require(data[key] == device[key], 'display changed: ' + key)
        require(abs(data['screen_refresh_hz'] - 60) < 0.1, 'reference refresh rate changed')
    return dict(admission='VALID_REFERENCE_DEVICE', policy=policy['id'], source_commit=result['source_commit'],
                release_minimum_approved=False, target_scale_accepted=False, repeats=result['repeats'],
                note='Draw interval is not isolated GPU time. One available development machine; performance budget remains VPERF-002.')


def capture(folder: Path, policy: dict) -> int:
    """Снимает три живых прогона штатным VBASE-001, сохраняя и неудачный результат."""
    require(not folder.exists(), 'output must be new')
    device = validate_policy(policy)
    before = inventory()
    check_inventory(before, device)
    check_power(environment(), policy['measurement'])
    folder.mkdir(parents=True)
    signatures = {name: digest(ROOT / name) for name in TOOLS}
    for name in TOOLS:
        archived = folder / 'instrumentation' / name
        archived.parent.mkdir(parents=True, exist_ok=True)
        archived.write_bytes((ROOT / name).read_bytes())
    call = [sys.executable, str(ROOT / 'tools/run_visual_baseline.py'), '--output', str(folder / 'native')]
    code = subprocess.run(call, cwd=ROOT, check=False).returncode
    session_path = folder / 'native/session.json'
    source = json.loads(session_path.read_text())['source'] if session_path.exists() else source_signature()
    record = dict(schema=1, policy=policy, before=before, after=inventory(), exit_code=code, source=source,
                  tool_sha256=signatures,
                  files={str(path.relative_to(folder)): digest(path) for path in sorted((folder / 'native').rglob('*')) if path.is_file()})
    (folder / 'capture.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    return code


def main() -> int:
    """Нормальная проверка офлайн; нативный запуск только по явному capture и в новый каталог."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('capture', 'verify'), nargs='?', default='verify')
    parser.add_argument('--output', type=Path, default=REPORT / 'measurement')
    args = parser.parse_args()
    folder = args.output.resolve()
    policy = json.loads(POLICY.read_text())
    try:
        if args.action == 'capture' and capture(folder, policy):
            print('VBASE-002: native capture rejected; raw files retained', file=sys.stderr)
            return 2
        result = verify(folder, policy)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (ValueError, KeyError, OSError, TypeError) as error:
        print('VBASE-002: REJECTED: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
