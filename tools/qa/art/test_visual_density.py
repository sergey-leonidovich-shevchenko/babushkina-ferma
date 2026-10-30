#!/usr/bin/env python3
"""Негативные сценарии сопоставимости и честного масштаба VART-006."""
import copy
import unittest
from PIL import Image
from tools.qa.art import visual_density as density


class DensityEvidenceTest(unittest.TestCase):
    """Изменяет только копии данных; рисунки и игровые слоты не затрагивает."""

    def setUp(self):
        """Загружает принятый контракт и закреплённые доказательства."""
        self.data=density.read(density.REPORT/'density-profile.json')
        self.images={v:Image.open(density.REPORT/x['master']) for v,x in self.data['variants'].items()}
        self.browser=density.read(density.REPORT/'browser-check.json')
        self.native=density.read(density.REPORT/'native/capture.json')

    def tearDown(self):
        """Закрывает исходники после каждого сценария."""
        for image in self.images.values():image.close()

    def test_saved_evidence(self):
        """Источники, геометрия браузера и шесть настоящих PNG согласованы."""
        self.assertEqual(density.verify(),[])

    def test_unconfirmed_choice(self):
        """Переключение B само по себе не заменяет ответа пользователя."""
        data=copy.deepcopy(self.data);data.pop('decision_quote',None)
        self.assertIn('unconfirmed choice',density.contract_errors(data,self.images))

    def test_hero_changes_between_variants(self):
        """Подмена общего героя самостоятельным B нарушает сравнимость."""
        data=copy.deepcopy(self.data);data['parts'][0]['source_policy']='variant'
        self.assertIn('common hero',density.contract_errors(data,self.images))

    def test_clipped_tree(self):
        """Срезанная крона не скрывается за общим зелёным gate."""
        data=copy.deepcopy(self.data);data['parts'][2]['source_rect']=[991,100,545,485]
        self.assertIn('clipped subject',density.contract_errors(data,self.images))

    def test_changed_camera(self):
        """Иная проекция одного просмотра отклоняется."""
        proof=copy.deepcopy(self.browser);proof['cases'][0]['size']=[960,540]
        self.assertIn('browser camera',density.browser_errors(proof,self.data))

    def test_missing_gray_case(self):
        """Потеря контроля без цвета уменьшает покрытие."""
        proof=copy.deepcopy(self.browser);proof['cases'].pop()
        self.assertIn('browser coverage',density.browser_errors(proof,self.data))

    def test_reduced_frame_is_not_native_target(self):
        """Уменьшенный браузерный JPEG не подменяет readback 1152×648."""
        proof=copy.deepcopy(self.native);proof['frames'][0]['size']=[822,462]
        self.assertIn('native target/repeat',density.native_errors(proof,self.data))

    def test_headless_is_not_gpu_capture(self):
        """Dummy/headless-рендер нельзя выдать за выполненную графическую проверку."""
        proof=copy.deepcopy(self.native);proof['display_server']='headless'
        self.assertIn('native graphics',density.native_errors(proof,self.data))


if __name__=='__main__':unittest.main()
