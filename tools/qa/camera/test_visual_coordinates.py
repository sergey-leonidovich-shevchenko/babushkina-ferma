#!/usr/bin/env python3
"""Проверяет реальные паспорта координат и отказы при подмене измерений."""
import copy
import math
from pathlib import Path
import shutil
import tempfile
import unittest
from tools.qa.camera import visual_coordinates as audit


class CoordinatesTests(unittest.TestCase):
    """Использует сохранённые нативные данные вместо автоматически созданного ожидаемого результата."""

    def changed(self, mutate, case='base'):
        """Проверяет независимое повреждение одной копии настоящего прогона."""
        data = copy.deepcopy(audit.read(audit.REPORT/case/'capture.json'))
        mutate(data)
        self.assertTrue(audit.capture_errors(data, audit.CASES[case], case == 'retina-2x'))

    def test_saved_native_evidence(self):
        """Сохранённые кадры, ролики, матрицы и хеши проходят полную проверку."""
        self.assertEqual(audit.verify(audit.REPORT), [])

    def test_headless_and_false_performance_claim(self):
        """Модельная графика и ошибочный допуск к FPS отклоняются."""
        for key, value in [('display_server','headless'),('performance_eligible',True),('content_scale_mode',0)]:
            with self.subTest(key=key): self.changed(lambda d: d.update({key:value}))

    def test_missing_motion_and_focus(self):
        """Потерянный кадр, пропущенная временная точка и краткая потеря фокуса отклоняются."""
        self.changed(lambda d: d['frames'].pop())
        self.changed(lambda d: d['frames'][40].update(time=8))
        self.changed(lambda d: d['frames'][40].update(focused=False))

    def test_wrong_window_and_readback(self):
        """Размер окна не подменяет размер framebuffer, особенно при оконных полях."""
        self.changed(lambda d: d['frames'][1].update(window=[1920,1080]))
        self.changed(lambda d: d['frames'][1].update(readback=[1024,768]), 'letterbox')

    def test_separate_rounded_feet(self):
        """Возврат прежнего округления стоп обнаруживается в дробной позиции."""
        self.changed(lambda d: d['frames'][0].update(foot_world=[556,672]))

    def test_input_and_grid_disagreement(self):
        """Неверное обратное преобразование либо другая клетка не скрываются верным рисунком."""
        self.changed(lambda d: d['frames'][30].update(pointer_received=[15,420]))
        self.changed(lambda d: d['frames'][30].update(pointer_cell=[100,100]))

    def test_double_retina_and_lost_letterbox(self):
        """Лишний множитель Retina и потеря оконных полей отклоняются независимо."""
        self.changed(lambda d: d['frames'][30].update(pointer_window=[v*2 for v in d['frames'][30]['pointer_window']]), 'retina-2x')
        self.changed(lambda d: d.update(screen_scale=1), 'retina-2x')
        self.changed(lambda d: d['frames'][30].update(final_transform=[[8/9,0],[0,8/9],[0,0]]), 'letterbox')

    def test_bad_geometry_and_missing_pixel_proof(self):
        """Неконечные числа, потеря геометрии и отсутствие настоящей пиксельной метки отклоняются."""
        self.changed(lambda d: d['frames'][30].update(foot_world=[math.nan,672]))
        self.changed(lambda d: d['frames'][30].pop('foot_canvas'))
        self.changed(lambda d: d['frames'][30].update(fiducial=False))

    def test_artifact_and_manifest_tampering(self):
        """Подмена сохранённого PNG и удаление его хеша не превращают результат в принятый."""
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)/'evidence'
            shutil.copytree(audit.REPORT, folder)
            with (folder/'base/frame-0000.png').open('ab') as file: file.write(b'tamper')
            self.assertTrue(any('artifact hash' in e for e in audit.verify(folder)))
            data = audit.read(folder/'source.json'); data['artifacts'] = {}
            (folder/'source.json').write_text(__import__('json').dumps(data))
            self.assertIn('incomplete provenance manifest', audit.verify(folder))


if __name__ == '__main__': unittest.main()
