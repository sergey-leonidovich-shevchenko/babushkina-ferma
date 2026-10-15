#!/usr/bin/env python3
"""Проверяет отказы стенда на повреждённых копиях настоящего нативного паспорта."""
import copy
import unittest

from visual_camera import REPORT, REGISTRY, capture_errors, read, registry_errors, verify
from analyze_visual_baseline import analyze_run


class CameraContractTests(unittest.TestCase):
    """Защищает покрытие карт, воспроизводимость камеры и границу между статикой и производительностью."""

    def setUp(self):
        """Берёт новые независимые копии проверенного нативного запуска."""
        self.registry = read(REGISTRY)
        self.capture = read(REPORT / 'native/run-1/capture.json')

    def test_saved_native_pair(self):
        """Сценарий: два реальных запуска; состояние: сохранённые PNG; результат: полный паспорт принят."""
        self.assertEqual(verify(REPORT / 'native', self.registry), [])

    def test_registry_missing_and_duplicate(self):
        """Сценарий: карта пропала либо повторилась; состояние: копия реестра; результат: отказ."""
        self.registry['points'][1] = copy.deepcopy(self.registry['points'][0])
        self.assertTrue(registry_errors(self.registry))
        self.registry['points'].pop()
        self.assertTrue(registry_errors(self.registry))

    def test_nonfinite_coordinates(self):
        """Сценарий: нечисловая точка; состояние: координата NaN; результат: отказ до запуска игры."""
        self.registry['points'][0]['player'][0] = float('nan')
        self.assertTrue(registry_errors(self.registry))

    def test_pose_drift(self):
        """Сценарий: сдвиг камеры или героя; состояние: одна изменённая координата; результат: отказ."""
        for key in ['camera', 'player', 'facing']:
            changed = copy.deepcopy(self.capture)
            changed['points'][0][key][0] += 1
            self.assertTrue(capture_errors(changed, self.registry))

    def test_calendar_and_seed(self):
        """Сценарий: другая исходная сцена; состояние: изменены seed, календарь или погода; результат: отказ."""
        for key, value in [('seed', 5), ('day', 2), ('minutes', 360), ('phase', 'night'), ('weather', 'rain')]:
            changed = copy.deepcopy(self.capture)
            changed['points'][0][key] = value
            self.assertTrue(capture_errors(changed, self.registry))

    def test_each_rendered_frame(self):
        """Сценарий: ошибка размера между началом и концом; состояние: изменён шестой кадр; результат: отказ."""
        for key in ['window', 'framebuffer', 'root']:
            changed = copy.deepcopy(self.capture)
            changed['points'][0]['conditions'][5][key] = [1000, 600]
            self.assertTrue(capture_errors(changed, self.registry))

    def test_focus_loss(self):
        """Сценарий: потерян фокус; состояние: один нефокусный кадр; результат: отказ даже при valid=true."""
        self.capture['points'][0]['conditions'][5]['focused'] = False
        self.assertTrue(capture_errors(self.capture, self.registry))

    def test_incomplete_capture(self):
        """Сценарий: отсутствует кадр карты; состояние: двадцать девять записей; результат: отказ."""
        self.capture['points'].pop()
        self.assertTrue(capture_errors(self.capture, self.registry))

    def test_readback_and_headless(self):
        """Сценарий: другой framebuffer либо headless; состояние: подменён паспорт; результат: отказ."""
        self.capture['points'][0]['readback'] = [1, 1]
        self.assertTrue(capture_errors(self.capture, self.registry))
        self.capture = read(REPORT / 'native/run-1/capture.json')
        self.capture['display_server'] = 'headless'
        self.assertTrue(capture_errors(self.capture, self.registry))

    def test_static_is_not_performance(self):
        """Сценарий: статике присвоили допуск FPS; состояние: остановленный мир; результат: отказ."""
        with self.assertRaises(ValueError):
            analyze_run(self.capture)
        self.capture['performance_eligible'] = True
        self.assertTrue(capture_errors(self.capture, self.registry))

    def test_live_or_blocked_pose(self):
        """Сценарий: персонаж двигается либо стоит в препятствии; состояние: неверный снимок; результат: отказ."""
        for key, value in [('physics_processing', True), ('walkable', 'water')]:
            changed = copy.deepcopy(self.capture)
            changed['points'][0][key] = value
            self.assertTrue(capture_errors(changed, self.registry))


if __name__ == '__main__':
    unittest.main()
