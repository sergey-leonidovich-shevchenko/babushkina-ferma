"""Отрицательные проверки протокола WATER-01 без запуска графики."""

from copy import deepcopy
import unittest

from analyze_water_audit import analyze


class WaterAuditTest(unittest.TestCase):
    """Проверяет, что неподходящая трасса не получает вид допустимого сравнения."""

    def fixture(self):
        """Создаёт минимальную известную нативную диагностическую трассу."""
        return {'render_pixels': [1152, 648], 'driver': 'opengl3', 'canvas': [1152, 648],
                'seed': 20261015, 'protocol': 'native frame_post_draw', 'samples_per_repeat': 60,
                'measurements': [dict(location='overworld', repeat=n, frame_usec=[16000]*60,
                                      p95_usec=16000, focused_frames=60, terrain_rebuilds=0, texture_bytes=100)
                                 for n in range(3)]}

    def test_diagnostic_is_never_full_acceptance(self):
        """Сценарий: верная малая трасса. Состояние: фиксированный target. Результат: только диагностическая база."""
        result = analyze(self.fixture(), (1152, 648), {'overworld'})
        self.assertEqual('VALID_DIAGNOSTIC_BASELINE', result['admission'])

    def test_wrong_pixels_focus_and_renderer_are_rejected(self):
        """Сценарий: подмена условий. Состояние: размер/фокус/renderer неверны. Результат: все варианты отклонены."""
        for change in [lambda x: x.update(render_pixels=[3584, 2016]),
                       lambda x: x.update(driver='headless'),
                       lambda x: x['measurements'][0].update(focused_frames=59)]:
            value = self.fixture()
            change(value)
            with self.assertRaises(ValueError):
                analyze(value, (1152, 648), {'overworld'})

    def test_short_missing_and_duplicate_repeats_are_rejected(self):
        """Сценарий: усечение. Состояние: нет кадров/повтора или есть дубль. Результат: отказ до сравнения."""
        for change in [lambda x: x['measurements'][0]['frame_usec'].pop(),
                       lambda x: x['measurements'].pop(),
                       lambda x: x['measurements'].append(deepcopy(x['measurements'][0]))]:
            value = self.fixture()
            change(value)
            with self.assertRaises(ValueError):
                analyze(value, (1152, 648), {'overworld'})

    def test_bad_values_and_forged_quantile_are_rejected(self):
        """Сценарий: повреждённые измерения. Состояние: NaN/ноль/ложный p95. Результат: не принимаются."""
        for value in (0, float('nan'), -1):
            data = self.fixture()
            data['measurements'][0]['frame_usec'][0] = value
            with self.assertRaises(ValueError):
                analyze(data, (1152, 648), {'overworld'})
        data = self.fixture()
        data['measurements'][0]['p95_usec'] = 1
        with self.assertRaises(ValueError):
            analyze(data, (1152, 648), {'overworld'})

    def test_single_stall_remains_visible(self):
        """Сценарий: секундный рывок. Состояние: один длинный кадр среди ровных. Результат: max и данные не сглажены."""
        data = self.fixture()
        data['measurements'][0]['frame_usec'][-1] = 1200000
        result = analyze(data, (1152, 648), {'overworld'})
        self.assertEqual(1200, result['measurements'][0]['draw']['max_ms'])


if __name__ == '__main__':
    unittest.main()
