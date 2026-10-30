#!/usr/bin/env python3
"""Отрицательные сценарии статического эталона на настоящей нативной серии."""
import copy
import unittest
from PIL import Image
from tools.qa.camera.visual_static import REPORT, NAMES, capture_errors, pixel_errors, read, verify
from tools.qa.camera.analyze_visual_baseline import analyze_run


class StaticReferenceTests(unittest.TestCase):
    """Защищает идентичность мира и не позволяет объявить остановленную сцену быстрым живым кадром."""

    def setUp(self):
        """Читает неизменяемые свидетельства и независимую копию паспорта."""
        self.folder = REPORT / 'native'
        self.data = read(self.folder / 'run-1/capture.json')

    def test_native_pair(self):
        """Сценарий: два запуска; исходно: настоящие PNG; ожидается: полная приёмка без ошибок."""
        self.assertEqual(verify(self.folder), [])

    def test_scene_drift(self):
        """Сценарий: сдвиг сцены; исходно: изменённый паспорт; ожидается: отказ каждого параметра."""
        for key, value in [('camera', [0, 350]), ('player', [433, 672]), ('weather', 'rain'), ('seed', 1), ('minutes', 721), ('physics_processing', True)]:
            data = copy.deepcopy(self.data); data['frames'][3][key] = value
            self.assertTrue(capture_errors(data), key)

    def test_window_and_focus(self):
        """Сценарий: потеря native-условий; исходно: ложный valid=true; ожидается: отказ по реальным полям."""
        for key, value in [('window', [800, 600]), ('framebuffer', [2304, 1296]), ('root', [800, 600]), ('focused', False), ('mode', 3)]:
            data = copy.deepcopy(self.data); data['frames'][1]['conditions'][key] = value
            self.assertTrue(capture_errors(data), key)
        self.data['errors'] = ['intermediate focus loss']
        self.assertTrue(capture_errors(self.data))

    def test_elapsed_redraws(self):
        """Сценарий: повторили старый framebuffer; исходно: нет реального интервала или кадров; ожидается: отказ."""
        for key in ['ticks_ms', 'draw_frame']:
            data = copy.deepcopy(self.data); data['frames'][3][key] = data['frames'][2][key]
            self.assertTrue(capture_errors(data))

    def test_missing_frames_and_modes(self):
        """Сценарий: неполная серия или включённый HUD чистого кадра; исходно: копия; ожидается: отказ."""
        data = copy.deepcopy(self.data); data['frames'].pop(); self.assertTrue(capture_errors(data))
        self.data['frames'][4]['hud'] = True; self.assertTrue(capture_errors(self.data))

    def test_no_performance_claim(self):
        """Сценарий: статике назначили FPS; исходно: настоящий паспорт; ожидается: отказ обоих анализаторов."""
        with self.assertRaises(ValueError): analyze_run(self.data)
        self.data['performance_eligible'] = True; self.assertTrue(capture_errors(self.data))

    def test_headless_or_effects(self):
        """Сценарий: headless или неверный набор отключений; исходно: копия паспорта; ожидается: отказ."""
        for key, value in [('display_server', 'headless'), ('disabled_effects', []), ('simulation_frozen', False)]:
            data = copy.deepcopy(self.data); data[key] = value; self.assertTrue(capture_errors(data))

    def images(self):
        """Читает пиксели без изменения исходных PNG."""
        result = {}
        for name in NAMES:
            with Image.open(self.folder / 'run-1' / (name+'.png')) as image: result[name] = image.convert('RGB')
        return result

    def test_moving_static_pixel(self):
        """Сценарий: один пиксель движется; исходно: пара статичных кадров; ожидается: отказ сравнения."""
        images = self.images(); pixel = images['clean-1'].getpixel((300, 300))
        images['clean-1'].putpixel((300, 300), tuple(255-v for v in pixel))
        self.assertTrue(pixel_errors(images, self.data['hud_masks']))

    def test_hidden_world_change(self):
        """Сценарий: скрытие HUD изменило мир; исходно: обе чистые копии одинаковы; ожидается: отказ вне масок."""
        images = self.images(); pixel = images['clean-0'].getpixel((300, 300))
        for name in ['clean-0', 'clean-1']: images[name].putpixel((300, 300), tuple(255-v for v in pixel))
        self.assertTrue(any('world pixels' in e for e in pixel_errors(images, self.data['hud_masks'])))

    def test_mask_and_control_cheating(self):
        """Сценарий: маска закрыла весь мир либо обычный рендер тоже заморожен; исходно: PNG; ожидается: отказ."""
        images = self.images()
        self.assertTrue(pixel_errors(images, [[0, 0, 1152, 648]]))
        images['restored-1'] = images['restored-0'].copy()
        self.assertTrue(any('control difference' in e for e in pixel_errors(images, self.data['hud_masks'])))


if __name__ == '__main__':
    unittest.main()
