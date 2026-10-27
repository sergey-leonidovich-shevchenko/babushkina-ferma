#!/usr/bin/env python3
"""Отрицательные сценарии происхождения, масштаба и прозрачного края VART-005."""
import copy
import unittest
from PIL import Image
from tools.qa.art import visual_edges as edges


class EdgeEvidenceTest(unittest.TestCase):
    """Портит только копии данных, не затрагивает исходники и игровые слоты."""

    def setUp(self):
        """Читает закреплённый контракт и существующий прозрачный мастер."""
        self.data=edges.read(edges.REPORT/'edge-profile.json')
        self.image=Image.open(edges.REPORT/'edge-master.png')
        self.proof=edges.read(edges.REPORT/'browser-check.json')

    def tearDown(self):
        """Освобождает дескриптор мастера после каждого сценария."""
        self.image.close()

    def test_saved_evidence(self):
        """Текущие файлы и восемь браузерных состояний согласованы."""
        self.assertEqual(edges.verify(),[])

    def test_missing_choice(self):
        """Approved без явного ответа пользователя не принимается."""
        data=copy.deepcopy(self.data);data.pop('decision_quote',None)
        self.assertIn('unconfirmed choice',edges.contract_errors(data,self.image))

    def test_clipped_tip(self):
        """Область, срезающая верх дерева, не проходит по зелёному общему тесту."""
        data=copy.deepcopy(self.data);data['parts'][0]['source_rect']=[28,100,500,422]
        self.assertIn('clipped silhouette',edges.contract_errors(data,self.image))

    def test_flattened_alpha(self):
        """RGB-копия не может подменить прозрачный мастер."""
        self.assertIn('RGBA source',edges.contract_errors(self.data,self.image.convert('RGB')))

    def test_camera_changed(self):
        """Одинаковые кнопки не доказывают одинаковую камеру."""
        proof=copy.deepcopy(self.proof);proof['cases'][3]['size']=[960,540]
        self.assertIn('browser scale',edges.browser_errors(proof,self.data))

    def test_source_changed(self):
        """Соседний спрайт или другой файл отклоняется."""
        proof=copy.deepcopy(self.proof);proof['cases'][0]['parts'][1]['clip']='0 0 451 292'
        self.assertIn('browser source',edges.browser_errors(proof,self.data))

    def test_filter_hides_problem(self):
        """В A нельзя незаметно добавить фильтр, скрывающий исходную альфу."""
        proof=copy.deepcopy(self.proof);proof['cases'][0]['parts'][0]['filter']='url(#blur)'
        self.assertIn('A has added filter',edges.browser_errors(proof,self.data))


if __name__=='__main__': unittest.main()
