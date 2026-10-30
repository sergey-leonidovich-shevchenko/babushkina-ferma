"""Поведенческие проверки протокола VBASE: валидность измерения не равна хорошей производительности."""
from copy import deepcopy
import json
import math
from pathlib import Path
import tempfile
import unittest

from tools.qa.camera.analyze_visual_baseline import COLUMNS, SIZE, START, TARGETS, analyze_run, analyze_session


def fixture():
    """Создаёт полный физически допустимый путь с известными 60 Гц и непрерывными draw-индексами."""
    conditions = dict(window=SIZE, framebuffer=SIZE, root_size=SIZE, focused=True, mode=0, vsync=1)
    rows, checkpoints = [], []
    position = START[:]
    for index, target in enumerate(TARGETS):
        origin = position[:]
        steps = math.ceil(math.dist(origin, target) / 3.5)
        for step in range(1, steps + 1):
            tick = len(rows) + 1
            position = [origin[i] + (target[i] - origin[i]) * step / steps for i in range(2)]
            rows.append([16667, tick * 16667, tick + 200, tick, 360 + tick / 60, *position, 0, True, 5, 3, 160, 1024, 2048])
        checkpoints.append(dict(index=index, tick=tick, target=target, position=position[:], minutes=360 + tick / 60))
    return dict(schema=1, preset='village-cardinal-1152-v1', seed=20261015, repeat=0, profile='Codex-VBASE-001-test', pid=100,
                engine='4.7.1', adapter='Test', screen=[3584, 2240], screen_scale=2, screen_refresh_hz=60,
                map_revision='test', start_camera=[0, 0], driver='opengl3', display_server='macOS',
                route_start=START, route_targets=TARGETS, route_finished=True, route_checkpoints=checkpoints,
                location='overworld', fault_injection=[], pause_on_focus_loss=False, physics_hz=60, max_fps=0,
                low_processor_usage=True, idle_sleep_usec=500, content_scale_mode=0, content_scale_factor=1,
                warmup_rendered_frames=120, warmup_world_frozen=True, settle_after_readback=8,
                requested_window=SIZE, requested_framebuffer=SIZE, readback_start=SIZE, readback_end=SIZE,
                initial_conditions=conditions, condition_groups=[dict(conditions=conditions, frames=len(rows))],
                world_start_minutes=360, world_end_minutes=rows[-1][4], sample_count=len(rows),
                interval_span_usec=rows[-1][1], terrain_rebuilds=0, columns=COLUMNS, frames=rows)


class VisualBaselineTest(unittest.TestCase):
    """Подмена окна, остановка мира и потерянные длинные кадры не получают приёмку."""

    def test_live_route_is_valid(self):
        """Сценарий: полный маршрут. Исходное состояние: 60 Гц. Ожидаемый результат: валидный замер и бюджет."""
        result = analyze_run(fixture())
        self.assertEqual(result['admission'], 'VALID_BASELINE')
        self.assertEqual(result['budget_60fps_candidate'], 'PASS')

    def test_wrong_size_and_focus_in_middle_are_rejected(self):
        """Сценарий: один плохой кадр. Исходное состояние: остальные верны. Ожидаемый результат: отказ."""
        for key, value in [('window', [3584, 2240]), ('framebuffer', [1000, 600]), ('root_size', [1000, 600]),
                           ('focused', False), ('mode', 3), ('vsync', 0)]:
            with self.subTest(key=key):
                data = deepcopy(fixture())
                bad = deepcopy(data['initial_conditions']); bad[key] = value; bad['valid'] = True
                data['condition_groups'][0]['frames'] -= 1
                data['condition_groups'].append(dict(conditions=bad, frames=1))
                data['frames'][40][7] = 1
                with self.assertRaises(ValueError): analyze_run(data)

    def test_setup_and_final_readback_are_required(self):
        """Сценарий: поздний resize. Исходное состояние: ложный финальный размер. Ожидаемый результат: отказ."""
        for key in ('requested_window', 'requested_framebuffer', 'readback_start', 'readback_end'):
            data = deepcopy(fixture()); data[key] = [3584, 2240]
            with self.assertRaises(ValueError): analyze_run(data)

    def test_native_pacing_and_pause_contracts(self):
        """Сценарий: иная нагрузка. Исходное состояние: изменён preset. Ожидаемый результат: отказ."""
        for key, value in [('display_server', 'headless'), ('driver', 'dummy'), ('pause_on_focus_loss', True),
                           ('max_fps', 60), ('physics_hz', 30), ('low_processor_usage', False), ('idle_sleep_usec', 10000),
                           ('content_scale_mode', 1), ('warmup_rendered_frames', 0), ('warmup_world_frozen', False),
                           ('settle_after_readback', 0), ('route_finished', False), ('fault_injection', ['pause'])]:
            data = deepcopy(fixture()); data[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): analyze_run(data)

    def test_stopped_simulation_cannot_fake_good_fps(self):
        """Сценарий: быстрые кадры замершего мира. Исходное состояние: часы стоят. Ожидаемый результат: отказ."""
        for edit in (lambda d: d['frames'][50].__setitem__(8, False),
                     lambda d: d['frames'][50].__setitem__(4, 360),
                     lambda d: d.update(world_end_minutes=360)):
            data = deepcopy(fixture()); edit(data)
            with self.assertRaises(ValueError): analyze_run(data)

    def test_removed_or_duplicate_draws_are_rejected(self):
        """Сценарий: вырезан рывок. Исходное состояние: нарушены draw и время. Ожидаемый результат: отказ."""
        for edit in (lambda d: d['frames'].pop(50), lambda d: d['frames'][50].__setitem__(2, d['frames'][49][2]),
                     lambda d: d['frames'][50].__setitem__(0, 1), lambda d: d.update(interval_span_usec=1),
                     lambda d: d['condition_groups'][0].update(frames=1)):
            data = deepcopy(fixture()); edit(data)
            with self.assertRaises(ValueError): analyze_run(data)

    def test_nan_zero_and_negative_frames_are_rejected(self):
        """Сценарий: повреждённый счётчик. Исходное состояние: NaN/Inf/ноль. Ожидаемый результат: отказ."""
        for value in (float('nan'), float('inf'), -1, 0):
            data = deepcopy(fixture()); data['frames'][50][0] = value
            with self.assertRaises(ValueError): analyze_run(data)

    def test_teleport_and_incomplete_checkpoints_are_rejected(self):
        """Сценарий: маршрут подменён. Исходное состояние: скачок или пропуск точки. Ожидаемый результат: отказ."""
        for edit in (lambda d: d['frames'][50].__setitem__(5, 2000), lambda d: d['route_checkpoints'].pop(),
                     lambda d: d['route_checkpoints'][2].update(target=[0, 0]), lambda d: d.update(route_start=[0, 0])):
            data = deepcopy(fixture()); edit(data)
            with self.assertRaises(ValueError): analyze_run(data)

    def test_single_second_stall_is_retained_and_fails_budget(self):
        """Сценарий: одиночное зависание. Исходное состояние: один кадр 1 с. Ожидаемый результат: видимый FAIL."""
        data = deepcopy(fixture()); extra = 1000000 - data['frames'][50][0]
        data['frames'][50][0] = 1000000
        for row in data['frames'][50:]: row[1] += extra
        data['interval_span_usec'] += extra
        result = analyze_run(data)
        self.assertEqual(result['admission'], 'VALID_BASELINE')
        self.assertEqual(result['budget_60fps_candidate'], 'FAIL')
        self.assertEqual(result['draw']['max_ms'], 1000)
        self.assertEqual(result['draw']['over100'], 1)

    def session(self, folder):
        """Создаёт три процесса и граничные паспорта без зависимости от графического устройства тестировщика."""
        session = dict(requested_repeats=3, fault='', source=dict(commit='a' * 40, sha256={'tool': 'hash'}), runs=[])
        stamp = dict(background_available=True, background=[{'executable': 'test'}], machine={'model': 'test'}, power='AC', power_settings='normal')
        for i in range(3):
            data = deepcopy(fixture()); data.update(repeat=i, pid=100+i, profile=f'Codex-VBASE-001-test-{i}')
            target = folder / f'run-{i + 1}'; target.mkdir()
            (target / 'native.json').write_text(json.dumps(data)); (target / 'stdout.txt').write_text('ok')
            session['runs'].append(dict(repeat=i, exit_code=0, folder=target.name, profile=data['profile'], before=deepcopy(stamp), after=deepcopy(stamp)))
        (folder / 'session.json').write_text(json.dumps(session))
        return session

    def test_three_separate_processes_are_required(self):
        """Сценарий: повторный ID процесса. Исходное состояние: три файла. Ожидаемый результат: дубль отклонён."""
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name); self.session(folder)
            self.assertEqual(analyze_session(folder)['admission'], 'VALID_BASELINE')
            path = folder / 'run-3/native.json'; data = json.loads(path.read_text()); data['pid'] = 100
            path.write_text(json.dumps(data))
            with self.assertRaises(ValueError): analyze_session(folder)

    def test_missing_power_background_and_repeat_are_rejected(self):
        """Сценарий: неполный паспорт. Исходное состояние: нет питания/фона/повтора. Ожидаемый результат: отказ."""
        for edit in (lambda s: s['runs'].pop(), lambda s: s['runs'][0]['before'].update(power='UNAVAILABLE'),
                     lambda s: s['runs'][0]['after'].update(background_available=False),
                     lambda s: s['runs'][0]['after'].update(power='Battery')):
            with tempfile.TemporaryDirectory() as name:
                folder = Path(name); session = self.session(folder); edit(session)
                (folder / 'session.json').write_text(json.dumps(session))
                with self.assertRaises(ValueError): analyze_session(folder)


if __name__ == '__main__':
    unittest.main()
